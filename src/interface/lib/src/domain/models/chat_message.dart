enum ChatSender { user, assistant }

enum ChatMessageKind { text, image, audio }

enum ChatMessageStatus { sending, sent, failed }

/// State of a write action (create/update/delete) the assistant proposed but
/// hasn't applied yet — the user confirms or cancels it from a preview card.
enum PendingActionStatus { pending, confirming, confirmed, cancelled, failed }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.sender,
    required this.kind,
    required this.createdAt,
    this.text,
    this.mediaPath,
    this.audioDuration,
    this.captionAudioPath,
    this.captionAudioDuration,
    this.status = ChatMessageStatus.sent,
    this.pendingAction,
    this.pendingActionStatus,
    this.reasoning,
    this.quickReplies,
  });

  factory ChatMessage.userText(String text) => ChatMessage(
    id: _newId(),
    sender: ChatSender.user,
    kind: ChatMessageKind.text,
    text: text,
    createdAt: DateTime.now(),
    status: ChatMessageStatus.sending,
  );

  /// [captionAudioPath]/[captionAudioDuration] let a photo carry a voice
  /// note as its caption instead of (or in addition to) typed [text] — both
  /// travel to the model as separate content parts of the same message.
  factory ChatMessage.userImage(
    String path, {
    String? text,
    String? captionAudioPath,
    Duration? captionAudioDuration,
  }) => ChatMessage(
    id: _newId(),
    sender: ChatSender.user,
    kind: ChatMessageKind.image,
    mediaPath: path,
    text: text,
    captionAudioPath: captionAudioPath,
    captionAudioDuration: captionAudioDuration,
    createdAt: DateTime.now(),
    status: ChatMessageStatus.sending,
  );

  factory ChatMessage.userAudio(String path, Duration duration) =>
      ChatMessage(
        id: _newId(),
        sender: ChatSender.user,
        kind: ChatMessageKind.audio,
        mediaPath: path,
        audioDuration: duration,
        createdAt: DateTime.now(),
        status: ChatMessageStatus.sending,
      );

  factory ChatMessage.assistantText(String text) => ChatMessage(
    id: _newId(),
    sender: ChatSender.assistant,
    kind: ChatMessageKind.text,
    text: text,
    createdAt: DateTime.now(),
  );

  final String id;
  final ChatSender sender;
  final ChatMessageKind kind;
  final String? text;
  final String? mediaPath;
  final Duration? audioDuration;
  /// Set only on an image message that also carries a voice-note caption.
  final String? captionAudioPath;
  final Duration? captionAudioDuration;
  final DateTime createdAt;
  final ChatMessageStatus status;

  /// {tool, args} for a write call the assistant proposed, parsed from the
  /// backend's pending-action marker. Not persisted: a pending card left
  /// over from a killed app is a rare edge case, not worth carrying history
  /// storage for — it just won't reappear after a restart.
  final Map<String, dynamic>? pendingAction;
  final PendingActionStatus? pendingActionStatus;

  /// The model's reasoning for this reply, parsed from the backend's thought
  /// markers — shown behind a tap-to-expand tile. Not persisted, same as
  /// [pendingAction]: it's a transient look-behind-the-scenes, not content.
  final String? reasoning;

  /// Short quick-reply labels the assistant offered — tapping one sends its
  /// text as the next user message. Not persisted for the same reason.
  final List<String>? quickReplies;

  ChatMessage copyWith({
    ChatMessageStatus? status,
    String? text,
    Map<String, dynamic>? pendingAction,
    PendingActionStatus? pendingActionStatus,
    String? reasoning,
    List<String>? quickReplies,
  }) => ChatMessage(
    id: id,
    sender: sender,
    kind: kind,
    text: text ?? this.text,
    mediaPath: mediaPath,
    audioDuration: audioDuration,
    captionAudioPath: captionAudioPath,
    captionAudioDuration: captionAudioDuration,
    createdAt: createdAt,
    status: status ?? this.status,
    pendingAction: pendingAction ?? this.pendingAction,
    pendingActionStatus: pendingActionStatus ?? this.pendingActionStatus,
    reasoning: reasoning ?? this.reasoning,
    quickReplies: quickReplies ?? this.quickReplies,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sender: ChatSender.values.byName(json['sender'] as String),
      kind: ChatMessageKind.values.byName(json['kind'] as String),
      text: json['text'] as String?,
      mediaPath: json['mediaPath'] as String?,
      audioDuration: json['audioDurationMs'] == null
          ? null
          : Duration(milliseconds: json['audioDurationMs'] as int),
      captionAudioPath: json['captionAudioPath'] as String?,
      captionAudioDuration: json['captionAudioDurationMs'] == null
          ? null
          : Duration(milliseconds: json['captionAudioDurationMs'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: ChatMessageStatus.values.byName(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.name,
      'kind': kind.name,
      if (text != null) 'text': text,
      if (mediaPath != null) 'mediaPath': mediaPath,
      if (audioDuration != null)
        'audioDurationMs': audioDuration!.inMilliseconds,
      if (captionAudioPath != null) 'captionAudioPath': captionAudioPath,
      if (captionAudioDuration != null)
        'captionAudioDurationMs': captionAudioDuration!.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  static int _counter = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
}
