import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:my_cash/src/domain/models/chat_message.dart';
import 'package:my_cash/src/ui/core/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onConfirmAction,
    this.onCancelAction,
  });

  final ChatMessage message;

  /// Wired only when [message] carries a pending action — tapping the
  /// preview card's buttons calls these instead of the card managing its
  /// own state, so ChatPage stays the single owner of message state.
  final VoidCallback? onConfirmAction;
  final VoidCallback? onCancelAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.sender == ChatSender.user;

    final bubbleColor = isUser
        ? colorScheme.primary
        : colorScheme.surface.withValues(alpha: 0.92);
    final textColor = isUser ? Colors.white : colorScheme.onSurface;
    // Markdown replies (lists, tables, code blocks) look cramped when the
    // bubble shrinks to fit a short first line — give them a floor so
    // structured content always has room, without widening plain short replies.
    final isMarkdown = !isUser && message.kind == ChatMessageKind.text;
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.76,
      560.0,
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: maxBubbleWidth,
          minWidth: isMarkdown ? maxBubbleWidth * 0.55 : 0,
        ),
        padding: message.kind == ChatMessageKind.image
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadii.md),
            topRight: const Radius.circular(AppRadii.md),
            bottomLeft: Radius.circular(isUser ? AppRadii.md : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppRadii.md),
          ),
          border: isUser
              ? null
              : Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _content(context, textColor),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == ChatMessageStatus.failed
                        ? Icons.error_outline_rounded
                        : message.status == ChatMessageStatus.sending
                        ? Icons.access_time_rounded
                        : Icons.done_all_rounded,
                    size: 14,
                    color: message.status == ChatMessageStatus.failed
                        ? colorScheme.error
                        : textColor.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color textColor) {
    switch (message.kind) {
      case ChatMessageKind.text:
        final text = message.text ?? '';
        if (message.sender == ChatSender.assistant) {
          final pendingAction = message.pendingAction;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text.isNotEmpty)
                MarkdownBody(
                  data: text,
                  selectable: true,
                  styleSheet: _markdownStyleSheet(context, textColor),
                ),
              if (pendingAction != null) ...[
                if (text.isNotEmpty) const SizedBox(height: 8),
                _PendingActionCard(
                  action: pendingAction,
                  status:
                      message.pendingActionStatus ??
                      PendingActionStatus.pending,
                  onConfirm: onConfirmAction,
                  onCancel: onCancelAction,
                ),
              ],
            ],
          );
        }
        return Text(
          text,
          style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3),
        );
      case ChatMessageKind.image:
        final caption = message.text;
        final captionAudioPath = message.captionAudioPath;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _openImagePreview(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: _image(message.mediaPath!, width: 220, height: 220),
              ),
            ),
            if (caption != null && caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  caption,
                  style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3),
                ),
              ),
            ],
            if (captionAudioPath != null) ...[
              const SizedBox(height: 6),
              _AudioBubbleContent(
                path: captionAudioPath,
                duration: message.captionAudioDuration ?? Duration.zero,
                textColor: textColor,
              ),
            ],
          ],
        );
      case ChatMessageKind.audio:
        return _AudioBubbleContent(
          path: message.mediaPath!,
          duration: message.audioDuration ?? Duration.zero,
          textColor: textColor,
        );
    }
  }

  /// Matches Markdown text to the same look as a plain-text bubble, just
  /// with structure (bold, lists, code, tables...) rendered instead of raw
  /// symbols — colored to fit the assistant bubble in light and dark theme.
  MarkdownStyleSheet _markdownStyleSheet(
    BuildContext context,
    Color textColor,
  ) {
    final base = TextStyle(color: textColor, fontSize: 15.5, height: 1.3);

    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      listBullet: base,
      strong: base.copyWith(fontWeight: FontWeight.w800),
      em: base.copyWith(fontStyle: FontStyle.italic),
      blockquote: base.copyWith(color: textColor.withValues(alpha: 0.75)),
      h1: base.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      h2: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
      h3: base.copyWith(fontSize: 16.5, fontWeight: FontWeight.w800),
      a: base.copyWith(decoration: TextDecoration.underline),
      code: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: textColor.withValues(alpha: 0.12),
      ),
      codeblockDecoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      tableHead: base.copyWith(fontWeight: FontWeight.w800),
      tableBody: base,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: textColor.withValues(alpha: 0.25)),
        ),
      ),
    );
  }

  void _openImagePreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: _image(message.mediaPath!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

Widget _image(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (kIsWeb) {
    return Image.network(path, width: width, height: height, fit: fit);
  }
  return Image.file(File(path), width: width, height: height, fit: fit);
}

class _AudioBubbleContent extends StatefulWidget {
  const _AudioBubbleContent({
    required this.path,
    required this.duration,
    required this.textColor,
  });

  final String path;
  final Duration duration;
  final Color textColor;

  @override
  State<_AudioBubbleContent> createState() => _AudioBubbleContentState();
}

class _AudioBubbleContentState extends State<_AudioBubbleContent> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position >= widget.duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play(
        kIsWeb ? UrlSource(widget.path) : DeviceFileSource(widget.path),
      );
    }
    if (mounted) setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds == 0
        ? 1
        : widget.duration.inMilliseconds;
    final progress = (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final remaining = _isPlaying || _position > Duration.zero
        ? widget.duration - _position
        : widget.duration;

    return SizedBox(
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.textColor,
              size: 32,
            ),
            onPressed: _toggle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: widget.textColor.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(widget.textColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(remaining),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// A write action (create/update/delete transaction) the assistant proposed,
/// shown as a card the user taps to confirm or cancel before anything is
/// actually saved — the literal "preview" of what will be registered.
class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard({
    required this.action,
    required this.status,
    required this.onConfirm,
    required this.onCancel,
  });

  final Map<String, dynamic> action;
  final PendingActionStatus status;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  String get _tool => action['tool'] as String? ?? '';
  Map<String, dynamic> get _args =>
      (action['args'] as Map?)?.cast<String, dynamic>() ?? const {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: colorScheme.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._fields(context),
          const SizedBox(height: 10),
          _footer(context, colorScheme),
        ],
      ),
    );
  }

  IconData get _icon => switch (_tool) {
    'create_transaction' => Icons.add_circle_outline_rounded,
    'update_transaction' => Icons.edit_outlined,
    'delete_transaction' => Icons.delete_outline_rounded,
    _ => Icons.receipt_long_outlined,
  };

  String get _title => switch (_tool) {
    'create_transaction' => 'Registrar transação',
    'update_transaction' => 'Alterar transação',
    'delete_transaction' => 'Apagar transação',
    _ => 'Confirmar ação',
  };

  List<Widget> _fields(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final rows = <Widget>[];

    void addRow(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Text(label, style: style?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Text(value, style: style)),
            ],
          ),
        ),
      );
    }

    final title = _args['title'] as String?;
    final amount = _args['amount'];
    final category = _args['category'] as String?;
    final occurredAt = _args['occurredAt'] as String?;
    final source = _args['source'] as String?;
    final installments = _args['installmentsTotal'];
    final recurrence = _args['recurrenceFrequency'] as String?;

    addRow('Id', _tool != 'create_transaction' ? _args['id'] as String? : null);
    addRow('Descrição', title);
    addRow(
      'Valor',
      amount is num ? 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}' : null,
    );
    addRow('Categoria', category);
    addRow('Data', occurredAt);
    addRow('Forma', source);
    addRow('Parcelas', installments is num ? '${installments.toInt()}x' : null);
    addRow('Recorrência', _recurrenceLabel(recurrence));

    if (rows.isEmpty) {
      rows.add(Text('Sem alterações informadas.', style: style));
    }
    return rows;
  }

  String? _recurrenceLabel(String? value) => switch (value) {
    'weekly' => 'Semanal',
    'monthly' => 'Mensal',
    'yearly' => 'Anual',
    _ => null,
  };

  Widget _footer(BuildContext context, ColorScheme colorScheme) {
    switch (status) {
      case PendingActionStatus.pending:
        return Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onCancel,
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onConfirm,
              child: const Text('Confirmar'),
            ),
          ],
        );
      case PendingActionStatus.confirming:
        return const Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case PendingActionStatus.confirmed:
        return _statusLine(Icons.check_circle_rounded, 'Salvo', colorScheme.secondary);
      case PendingActionStatus.cancelled:
        return _statusLine(
          Icons.cancel_outlined,
          'Cancelado',
          colorScheme.onSurface.withValues(alpha: 0.6),
        );
      case PendingActionStatus.failed:
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              'Falhou ao salvar.',
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
            TextButton(onPressed: onConfirm, child: const Text('Tentar de novo')),
          ],
        );
    }
  }

  Widget _statusLine(IconData icon, String text, Color color) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Icon(icon, size: 16, color: color),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}
