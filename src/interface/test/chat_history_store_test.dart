import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_cash/src/data/services/chat_history_store.dart';
import 'package:my_cash/src/domain/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trips a saved conversation, including image/audio messages', () async {
    final store = ChatHistoryStore();
    final messages = [
      ChatMessage.userText('Gastei 30 reais no mercado'),
      ChatMessage.assistantText('Anotado!'),
      ChatMessage.userAudio('/tmp/audio.m4a', const Duration(seconds: 12)),
    ];

    await store.save(messages);
    final loaded = await store.load();

    expect(loaded.length, 3);
    expect(loaded[0].text, 'Gastei 30 reais no mercado');
    expect(loaded[2].mediaPath, '/tmp/audio.m4a');
    expect(loaded[2].audioDuration, const Duration(seconds: 12));
  });

  test('keeps only the last 50 messages, dropping the oldest', () async {
    final store = ChatHistoryStore();
    final messages = [
      for (var i = 0; i < 60; i++) ChatMessage.userText('msg $i'),
    ];

    await store.save(messages);
    final loaded = await store.load();

    expect(loaded.length, 50);
    expect(loaded.first.text, 'msg 10');
    expect(loaded.last.text, 'msg 59');
  });

  test('settles a still-"sending" message to "failed" on load', () async {
    final store = ChatHistoryStore();
    await store.save([ChatMessage.userText('nunca confirmou')]);

    final loaded = await store.load();

    expect(loaded.single.status, ChatMessageStatus.failed);
  });

  test('returns an empty list when nothing was ever saved', () async {
    final store = ChatHistoryStore();
    expect(await store.load(), isEmpty);
  });
}
