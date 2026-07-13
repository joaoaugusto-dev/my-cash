import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_cash/src/domain/models/chat_message.dart';

/// Persists the chat conversation locally, capped at [maxMessages] — once
/// the limit is hit, the oldest messages are dropped to make room.
class ChatHistoryStore {
  static const _storageKey = 'chat_history';
  static const maxMessages = 50;

  Future<List<ChatMessage>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .map(_settleSendingStatus)
          .toList();
    } catch (_) {
      // Corrupted or outdated-shape data shouldn't crash the chat — start fresh.
      return const [];
    }
  }

  Future<void> save(List<ChatMessage> messages) async {
    final preferences = await SharedPreferences.getInstance();
    final capped = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;

    await preferences.setString(
      _storageKey,
      jsonEncode(capped.map((m) => m.toJson()).toList()),
    );
  }

  /// A message still "sending" after a fresh load never got a real answer
  /// (the app was killed mid-request) — show it as failed instead of a
  /// clock icon that can never resolve.
  ChatMessage _settleSendingStatus(ChatMessage message) {
    return message.status == ChatMessageStatus.sending
        ? message.copyWith(status: ChatMessageStatus.failed)
        : message;
  }
}
