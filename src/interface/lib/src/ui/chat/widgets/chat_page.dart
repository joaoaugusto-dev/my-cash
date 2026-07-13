import 'dart:async';

import 'package:flutter/material.dart';

import 'package:my_cash/src/data/services/chat_api_service.dart';
import 'package:my_cash/src/data/services/chat_history_store.dart';
import 'package:my_cash/src/domain/models/chat_message.dart';
import 'chat_bubble.dart';
import 'chat_composer.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.apiService});

  final ChatApiService apiService;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final _scrollController = ScrollController();
  final _historyStore = ChatHistoryStore();
  bool _isAssistantTyping = false;

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

    final history = [
      for (final message in _messages)
        {
          'role': message.sender == ChatSender.user ? 'user' : 'assistant',
          'content': _promptFor(message),
        },
    ];

    ChatMessage? assistantMessage;
    final buffer = StringBuffer();

    try {
      await for (final delta in widget.apiService.streamMessage(history)) {
        buffer.write(delta);
        setState(() {
          if (assistantMessage == null) {
            _isAssistantTyping = false;
            assistantMessage = ChatMessage.assistantText(buffer.toString());
            _messages.add(assistantMessage!);
            _capMessages();
          } else {
            final index = _messages.indexWhere(
              (m) => m.id == assistantMessage!.id,
            );
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                text: buffer.toString(),
              );
            }
          }
        });
        _scrollToBottom();
      }

      if (assistantMessage == null) {
        // Stream produced no deltas — shouldn't normally happen, the backend
        // always writes a fallback line, but stay defensive.
        setState(() {
          _messages.add(ChatMessage.assistantText('...'));
          _capMessages();
        });
      }
      _updateStatus(userMessage.id, ChatMessageStatus.sent);
    } catch (_) {
      _updateStatus(userMessage.id, ChatMessageStatus.failed);
    } finally {
      if (mounted) setState(() => _isAssistantTyping = false);
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

  /// Text representation of a message for the AI prompt — image/audio
  /// messages have no [ChatMessage.text], so they get a short caption instead.
  String _promptFor(ChatMessage message) {
    switch (message.kind) {
      case ChatMessageKind.text:
        return message.text ?? '';
      case ChatMessageKind.image:
        return 'Enviei uma imagem.';
      case ChatMessageKind.audio:
        final seconds = message.audioDuration?.inSeconds ?? 0;
        return 'Enviei um áudio de ${seconds}s.';
    }
  }

  void _sendText(String text) => _send(ChatMessage.userText(text));

  void _sendImage(String path) => _send(ChatMessage.userImage(path));

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
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(0, topPadding + 12, 0, 12),
                  itemCount: _messages.length + (_isAssistantTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return const _TypingBubble();
                    }
                    return ChatBubble(message: _messages[index]);
                  },
                ),
        ),
        ChatComposer(
          onSendText: _sendText,
          onSendImage: _sendImage,
          onSendAudio: _sendAudio,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: SizedBox(
          width: 28,
          height: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (_) => CircleAvatar(
                radius: 3,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
