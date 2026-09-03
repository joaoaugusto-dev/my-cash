import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Drag-up distance (px) after which a held recording locks hands-free,
/// matching WhatsApp's gesture.
const double _lockDragThreshold = 80;

/// Leftward drag distance (px) that cancels a held recording.
const double _cancelDragThreshold = 90;

/// 16kHz mono PCM ≈ 32KB/s, so this keeps a note under the ~2.9MB the chat
/// accepts per attachment. Reaching it sends what was recorded so far.
const Duration _maxRecording = Duration(seconds: 90);

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendImageWithAudio,
    required this.onSendAudio,
  });

  final ValueChanged<String> onSendText;

  /// [text] is the typed caption, if any — null/empty sends the photo alone.
  final void Function(String path, {String? text}) onSendImage;

  /// A photo sent with a recorded voice note as its caption instead of text.
  final void Function(String imagePath, String audioPath, Duration duration)
  onSendImageWithAudio;

  final void Function(String path, Duration duration) onSendAudio;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _textController = TextEditingController();
  final _recorder = AudioRecorder();
  final _imagePicker = ImagePicker();

  bool _hasText = false;
  bool _isRecording = false;
  bool _isLocked = false;
  double _dragDy = 0;
  double _dragDx = 0;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  /// A photo picked but not sent yet — staged so the user can type a caption
  /// or record a voice note before it goes out, instead of sending on pick.
  String? _stagedImagePath;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _textController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // Physical keyboards only (web/desktop): Enter sends, Shift+Enter breaks
  // the line. Mobile virtual keyboards don't route through here.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!kIsWeb) return KeyEventResult.ignored;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _sendText();
    return KeyEventResult.handled;
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final stagedImage = _stagedImagePath;
    if (stagedImage != null) {
      widget.onSendImage(stagedImage, text: text);
      setState(() => _stagedImagePath = null);
    } else {
      widget.onSendText(text);
    }
    _textController.clear();
  }

  /// Sends the staged photo alone — the caption row has no room for a
  /// dedicated "send with no caption" button, so it lives on the preview.
  void _sendStagedImage() {
    final stagedImage = _stagedImagePath;
    if (stagedImage == null) return;
    widget.onSendImage(stagedImage);
    setState(() => _stagedImagePath = null);
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file != null) setState(() => _stagedImagePath = file.path);
  }

  void _openAttachSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Câmera'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeria'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _preparePath() async {
    if (kIsWeb) return 'voice_message.wav';
    final dir = await getTemporaryDirectory();
    return '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final path = await _preparePath();
    await _recorder.start(
      // WAV, mono, 16kHz: the models read wav/mp3 inline, not m4a, and speech
      // needs nothing better than 16kHz — it keeps the upload small.
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _isLocked = false;
      _dragDy = 0;
      _dragDx = 0;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() => _elapsed += const Duration(milliseconds: 200));
      if (_elapsed >= _maxRecording) _finishRecording(send: true);
    });
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
    });
    _ticker?.cancel();
    _ticker = null;
    final duration = _elapsed;
    final path = await _recorder.stop();
    if (send && path != null && duration.inMilliseconds > 400) {
      final stagedImage = _stagedImagePath;
      if (stagedImage != null) {
        widget.onSendImageWithAudio(stagedImage, path, duration);
        setState(() => _stagedImagePath = null);
      } else {
        widget.onSendAudio(path, duration);
      }
    } else if (!kIsWeb && path != null) {
      unawaited(File(path).delete().catchError((_) => File(path)));
    }
  }

  void _onLongPressEnd() {
    // Locked recording is hands-free: lifting the finger must not send it.
    if (_isLocked) return;
    _finishRecording(send: true);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _isLocked) return;
    setState(() {
      _dragDy = (-details.offsetFromOrigin.dy).clamp(0, _lockDragThreshold);
      _dragDx = (-details.offsetFromOrigin.dx).clamp(0, _cancelDragThreshold);
    });
    if (-details.offsetFromOrigin.dy > _lockDragThreshold) {
      setState(() => _isLocked = true);
    } else if (-details.offsetFromOrigin.dx > _cancelDragThreshold) {
      _finishRecording(send: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // The bottom nav is a floating overlay (FloatingBottomBar), not part of
    // the layout flow, so this composer needs its own clearance above it.
    final isVeryNarrow = MediaQuery.sizeOf(context).width < 370;
    final navBarClearance = (isVeryNarrow ? 72.0 : 78.0) + 12 + 8;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + navBarClearance),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
          ),
        ),
        // Both rows stay mounted (Offstage, not a ternary swap) so the mic
        // button's GestureDetector survives the _isRecording flip — swapping
        // the whole subtree mid-press disposes the recognizer and silently
        // kills drag-to-lock/cancel.
        child: Stack(
          children: [
            Offstage(
              offstage: _isRecording,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_stagedImagePath != null)
                    _ImagePreviewChip(
                      path: _stagedImagePath!,
                      onRemove: () => setState(() => _stagedImagePath = null),
                      onSend: _sendStagedImage,
                    ),
                  _textRow(colorScheme),
                ],
              ),
            ),
            if (_isRecording) _recordingRow(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _textRow(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file_rounded),
          onPressed: _openAttachSheet,
        ),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _stagedImagePath != null
                      ? 'Legenda (opcional)'
                      : 'Mensagem',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _hasText
            ? _RoundIconButton(
                icon: Icons.send_rounded,
                onTap: _sendText,
                color: colorScheme.primary,
              )
            : GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressMoveUpdate: _onLongPressMoveUpdate,
                onLongPressEnd: (_) => _onLongPressEnd(),
                onLongPressCancel: () => _finishRecording(send: false),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _recordingRow(ColorScheme colorScheme) {
    final lockProgress = (_dragDy / _lockDragThreshold).clamp(0.0, 1.0);

    return Row(
      children: [
        if (!_isLocked) ...[
          Icon(
            Icons.keyboard_arrow_up_rounded,
            color: colorScheme.primary.withValues(
              alpha: 0.4 + lockProgress * 0.6,
            ),
          ),
          const SizedBox(width: 2),
        ],
        Icon(Icons.mic_rounded, color: colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Text(
          _formatElapsed(_elapsed),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Opacity(
            opacity: (1 - _dragDx / _cancelDragThreshold).clamp(0.3, 1.0),
            child: Text(
              _isLocked
                  ? 'Toque em enviar'
                  : 'Arraste ← p/ cancelar · ↑ p/ travar',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_isLocked) ...[
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            onPressed: () => _finishRecording(send: false),
          ),
          _RoundIconButton(
            icon: Icons.send_rounded,
            onTap: () => _finishRecording(send: true),
            color: colorScheme.primary,
          ),
        ],
      ],
    );
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Shown above the text field once a photo is picked but not sent yet, so
/// the user can type a caption, record a voice one, or send it as-is.
class _ImagePreviewChip extends StatelessWidget {
  const _ImagePreviewChip({
    required this.path,
    required this.onRemove,
    required this.onSend,
  });

  final String path;
  final VoidCallback onRemove;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb
                    ? Image.network(path, width: 56, height: 56, fit: BoxFit.cover)
                    : Image.file(
                        File(path),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: colorScheme.error,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adicione uma legenda ou envie assim mesmo.',
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send_rounded, color: colorScheme.primary),
            tooltip: 'Enviar foto sem legenda',
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
