import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/domain/models/chat_message.dart';
import 'package:my_cash/src/ui/chat/widgets/chat_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );
}

void main() {
  testWidgets('renders assistant text as Markdown (bold + list)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ChatBubble(
          message: ChatMessage.assistantText('**Resumo:**\n- Item um\n- Item dois'),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Resumo:'), findsOneWidget);
    expect(find.textContaining('Item um'), findsOneWidget);
  });

  testWidgets('renders user text as plain text, not Markdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ChatBubble(message: ChatMessage.userText('**não é negrito**'))),
    );

    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('**não é negrito**'), findsOneWidget);
  });

  testWidgets('gives a short assistant reply a minimum width to breathe', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ChatBubble(message: ChatMessage.assistantText('Oi'))),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(MarkdownBody),
            matching: find.byType(Container),
          )
          .first,
    );
    final constraints = container.constraints!;

    expect(constraints.minWidth, greaterThan(0));
  });
}
