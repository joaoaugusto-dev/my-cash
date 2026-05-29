import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/widgets/finance_stat_card.dart';

void main() {
  testWidgets('FinanceStatCard renders title and value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FinanceStatCard(
            title: 'Saldo',
            value: 'R\$ 5.100,00',
            subtitle: 'Resultado do mês',
            icon: Icons.account_balance_wallet_rounded,
            color: Color(0xFF1F6FEB),
          ),
        ),
      ),
    );

    expect(find.text('Saldo'), findsOneWidget);
    expect(find.text('R\$ 5.100,00'), findsOneWidget);
    expect(find.text('Resultado do mês'), findsOneWidget);
  });
}
