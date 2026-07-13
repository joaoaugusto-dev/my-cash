import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:my_cash/src/domain/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

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
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.76;

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
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.7),
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
          return MarkdownBody(
            data: text,
            selectable: true,
            styleSheet: _markdownStyleSheet(context, textColor),
          );
        }
        return Text(
          text,
          style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3),
        );
      case ChatMessageKind.image:
        return GestureDetector(
          onTap: () => _openImagePreview(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _image(message.mediaPath!, width: 220, height: 220),
          ),
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
  MarkdownStyleSheet _markdownStyleSheet(BuildContext context, Color textColor) {
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
                  borderRadius: BorderRadius.circular(4),
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
