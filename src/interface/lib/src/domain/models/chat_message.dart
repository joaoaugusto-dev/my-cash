enum ChatSender { user, assistant }

enum ChatMessageKind { text, image, audio }

enum ChatMessageStatus { sending, sent, failed }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.sender,
    required this.kind,
    required this.createdAt,
    this.text,
    this.mediaPath,
    this.audioDuration,
    this.status = ChatMessageStatus.sent,
  });

  factory ChatMessage.userText(String text) => ChatMessage(
    id: _newId(),
    sender: ChatSender.user,
    kind: ChatMessageKind.text,
    text: text,
    createdAt: DateTime.now(),
    status: ChatMessageStatus.sending,
  );

  factory ChatMessage.userImage(String path) => ChatMessage(
    id: _newId(),
    sender: ChatSender.user,
    kind: ChatMessageKind.image,
    mediaPath: path,
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
  final DateTime createdAt;
  final ChatMessageStatus status;

  ChatMessage copyWith({ChatMessageStatus? status, String? text}) =>
      ChatMessage(
        id: id,
        sender: sender,
        kind: kind,
        text: text ?? this.text,
        mediaPath: mediaPath,
        audioDuration: audioDuration,
        createdAt: createdAt,
        status: status ?? this.status,
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
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  static int _counter = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
}
