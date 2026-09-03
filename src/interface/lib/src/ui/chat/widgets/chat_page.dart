import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:my_cash/src/data/services/chat_api_service.dart';
import 'package:my_cash/src/data/services/chat_history_store.dart';
import 'package:my_cash/src/domain/models/chat_message.dart';
import 'chat_bubble.dart';
import 'chat_composer.dart';

/// Written by the backend at the end of a reply whose tools changed data.
/// Stripped from the text before rendering; its arrival triggers a reload.
const String _refreshMarker = '[[mycash:refresh]]';

/// Raw bytes accepted per attachment. Base64 inflates by ~4/3, and the backend
/// rejects anything past ~4MB encoded — stop before the round trip.
const int _maxMediaBytes = 2900000;

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.apiService,
    required this.onDataChanged,
  });

  final ChatApiService apiService;

  /// Called after the assistant created, edited or deleted a transaction, so
  /// the dashboard behind the chat stops showing stale numbers.
  final VoidCallback onDataChanged;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final _scrollController = ScrollController();
  final _historyStore = ChatHistoryStore();
  bool _isAssistantTyping = false;
  String? _retryNotice;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyStore.load();
    if (!mounted || history.isEmpty) return;
    setState(() => _messages.addAll(history));
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(ChatMessage userMessage) async {
    setState(() {
      _messages.add(userMessage);
      _capMessages();
      _isAssistantTyping = true;
    });
    _scrollToBottom();
    unawaited(_historyStore.save(_messages));

    final history = <Map<String, dynamic>>[
      for (final message in _messages)
        {
          'role': message.sender == ChatSender.user ? 'user' : 'assistant',
          // Only the message being sent carries its media; older ones fall
          // back to a caption, so re-sending the whole conversation doesn't
          // re-upload every photo and voice note in it.
          'content': message.id == userMessage.id
              ? await _contentFor(message)
              : _promptFor(message),
        },
    ];

    ChatMessage? assistantMessage;
    final buffer = StringBuffer();
    var dataChanged = false;

    try {
      final stream = widget.apiService.streamMessage(
        history,
        onRetry: (attempt, maxAttempts) {
          if (!mounted) return;
          setState(() {
            _retryNotice =
                'A IA está com alta demanda agora. Tentando de novo em 1 '
                'minuto ($attempt/$maxAttempts)...';
          });
        },
      );
      await for (final delta in stream) {
        if (_retryNotice != null) setState(() => _retryNotice = null);
        buffer.write(delta);
        // Strip on the full accumulated text, not the delta — the marker can
        // arrive split across chunks.
        var text = buffer.toString();
        if (text.contains(_refreshMarker)) {
          dataChanged = true;
          text = text.replaceAll(_refreshMarker, '').trimRight();
        }
        setState(() {
          if (assistantMessage == null) {
            _isAssistantTyping = false;
            assistantMessage = ChatMessage.assistantText(text);
            _messages.add(assistantMessage!);
            _capMessages();
          } else {
            final index = _messages.indexWhere(
              (m) => m.id == assistantMessage!.id,
            );
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(text: text);
            }
          }
        });
        _scrollToBottom();
      }

      if (dataChanged) widget.onDataChanged();

      if (assistantMessage == null) {
        // Stream produced no deltas — shouldn't normally happen, the backend
        // always writes a fallback line, but stay defensive.
        setState(() {
          _messages.add(ChatMessage.assistantText('...'));
          _capMessages();
        });
      }
      _updateStatus(userMessage.id, ChatMessageStatus.sent);
    } catch (error) {
      _updateStatus(userMessage.id, ChatMessageStatus.failed);
      // Show why it failed instead of only a red icon — a missing key, an
      // expired session or an upstream refusal are all fixable, but only if
      // the message reaches the screen.
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage.assistantText('⚠️ $error'));
          _capMessages();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssistantTyping = false;
          _retryNotice = null;
        });
      }
      _scrollToBottom();
      unawaited(_historyStore.save(_messages));
    }
  }

  /// Keeps at most [ChatHistoryStore.maxMessages] messages, dropping the
  /// oldest first — mirrors the cap [ChatHistoryStore.save] applies, so the
  /// on-screen conversation and what's persisted never disagree.
  void _capMessages() {
    if (_messages.length > ChatHistoryStore.maxMessages) {
      _messages.removeRange(0, _messages.length - ChatHistoryStore.maxMessages);
    }
  }

  void _updateStatus(String id, ChatMessageStatus status) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1 || !mounted) return;
    setState(() {
      _messages[index] = _messages[index].copyWith(status: status);
    });
  }

  /// Content sent for the message the user just posted: plain text, or the
  /// multimodal parts the backend forwards to the model. The photo/voice note
  /// goes inline as base64 — the model reads the receipt and understands the
  /// audio directly, with no upload bucket or transcription step in between.
  ///
  /// If the file can't be read, it degrades to the caption rather than
  /// failing the whole message.
  Future<Object> _contentFor(ChatMessage message) async {
    final path = message.mediaPath;
    if (message.kind == ChatMessageKind.text || path == null) {
      return _promptFor(message);
    }

    try {
      final bytes = await XFile(path).readAsBytes();
      final captionAudioPath = message.captionAudioPath;
      final captionAudioBytes = captionAudioPath == null
          ? null
          : await XFile(captionAudioPath).readAsBytes();
      if (bytes.length + (captionAudioBytes?.length ?? 0) > _maxMediaBytes) {
        return message.kind == ChatMessageKind.image
            ? 'Tentei enviar uma foto, mas ficou grande demais.'
            : 'Tentei enviar um áudio, mas ficou longo demais.';
      }
      final data = base64Encode(bytes);

      return [
        {'type': 'text', 'text': message.text ?? _defaultPromptFor(message)},
        if (message.kind == ChatMessageKind.image)
          {
            'type': 'image_url',
            'image_url': {'url': 'data:${_mimeOf(path)};base64,$data'},
          }
        else
          {
            'type': 'input_audio',
            'input_audio': {'data': data, 'format': 'wav'},
          },
        // A photo can carry a spoken caption alongside the typed one — both
        // are just more content parts of the same message to the model.
        if (captionAudioBytes != null)
          {
            'type': 'input_audio',
            'input_audio': {
              'data': base64Encode(captionAudioBytes),
              'format': 'wav',
            },
          },
      ];
    } catch (_) {
      return _promptFor(message);
    }
  }

  String _defaultPromptFor(ChatMessage message) =>
      message.kind == ChatMessageKind.image
      ? 'Segue a foto. Se for uma nota ou comprovante, registre a despesa.'
      : 'Segue um áudio meu.';

  String _mimeOf(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Text representation of a message for the AI prompt — image/audio
  /// messages have no [ChatMessage.text], so they get a short caption instead.
  String _promptFor(ChatMessage message) {
    switch (message.kind) {
      case ChatMessageKind.text:
        return message.text ?? '';
      case ChatMessageKind.image:
        final caption = message.text;
        return caption == null || caption.isEmpty
            ? 'Enviei uma imagem.'
            : 'Enviei uma imagem com a legenda: $caption';
      case ChatMessageKind.audio:
        final seconds = message.audioDuration?.inSeconds ?? 0;
        return 'Enviei um áudio de ${seconds}s.';
    }
  }

  void _sendText(String text) => _send(ChatMessage.userText(text));

  void _sendImage(String path, {String? text}) =>
      _send(ChatMessage.userImage(path, text: text));

  void _sendImageWithAudio(String path, String audioPath, Duration duration) =>
      _send(
        ChatMessage.userImage(
          path,
          captionAudioPath: audioPath,
          captionAudioDuration: duration,
        ),
      );

  void _sendAudio(String path, Duration duration) =>
      _send(ChatMessage.userAudio(path, duration));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // ChatPage is a bare PageView child (no Scaffold/AppBar of its own), same
    // as the other tabs in home_screen.dart, so it must add the status bar
    // inset itself instead of relying on a SafeArea higher up.
    final topPadding = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _EmptyState(colorScheme: colorScheme, topPadding: topPadding)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(0, topPadding + 12, 0, 12),
                      itemCount:
                          _messages.length + (_isAssistantTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _TypingBubble();
                        }
                        return ChatBubble(message: _messages[index]);
                      },
                    ),
                  ),
                ),
        ),
        if (_retryNotice != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _RetryBanner(message: _retryNotice!),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ChatComposer(
              onSendText: _sendText,
              onSendImage: _sendImage,
              onSendImageWithAudio: _sendImageWithAudio,
              onSendAudio: _sendAudio,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorScheme, required this.topPadding});

  final ColorScheme colorScheme;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32 + topPadding, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 56,
              color: colorScheme.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Converse com seu secretário financeiro',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Envie texto, foto ou áudio contando seus gastos e ganhos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phrases cycled through while the assistant is thinking — purely
/// decorative, so a stray phrase not matching what actually happened (e.g.
/// "Consultando seus dados..." on a request with no tool calls) is fine.
const _thinkingPhrases = [
  'Pensando...',
  'Consultando seus dados...',
  'Organizando a resposta...',
  'Quase lá...',
];

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> {
  int _phraseIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _thinkingPhrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.secondary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _thinkingPhrases[_phraseIndex],
                key: ValueKey(_phraseIndex),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown above the composer while [ChatApiService.streamMessage] is
/// backing off and retrying a request the AI provider rejected as overloaded.
class _RetryBanner extends StatelessWidget {
  const _RetryBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
