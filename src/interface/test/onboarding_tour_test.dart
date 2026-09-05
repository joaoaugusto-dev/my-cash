import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/ui/onboarding/widgets/onboarding_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home-screen stand-in: one spotlightable element plus the tour on top.
Widget _harness(
  OnboardingTargets targets,
  VoidCallback onTargetTap, {
  VoidCallback? onFinish,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 200,
            left: 40,
            child: ElevatedButton(
              key: targets.identity,
              onPressed: onTargetTap,
              child: const Text('alvo'),
            ),
          ),
          Positioned(
            top: 500,
            left: 40,
            child: ElevatedButton(
              key: targets.period,
              onPressed: onTargetTap,
              child: const Text('alvo2'),
            ),
          ),
          Positioned.fill(
            child: OnboardingTour(
              userId: 'user-a',
              firstName: 'João',
              targets: targets,
              onGoToPage: (_) {},
              onFinish: onFinish ?? () {},
            ),
          ),
        ],
      ),
    ),
  );
}

/// Step change waits on a page transition, an ensureVisible and the
/// cutout's glide before it has settled.
Future<void> _settleStep(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('tour shows on first run and never again for that account', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await shouldShowOnboardingTour('user-a'), isTrue);
    await markOnboardingTourSeen('user-a');

    expect(await shouldShowOnboardingTour('user-a'), isFalse);
    // A different account on the same device still gets its own first run.
    expect(await shouldShowOnboardingTour('user-b'), isTrue);
  });

  testWidgets('the spotlighted element stays tappable, the rest does not', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var taps = 0;
    final targets = OnboardingTargets();

    await tester.pumpWidget(_harness(targets, () => taps++));
    await _settleStep(tester);

    // Opening step has no spotlight: the scrim covers the whole app.
    await tester.tap(find.text('alvo'), warnIfMissed: false);
    expect(taps, 0);

    // Step 2 spotlights the button — the cutout passes touches through.
    await tester.tap(find.text('Continuar'));
    await _settleStep(tester);

    await tester.tap(find.text('alvo'));
    expect(taps, 1);

    // Just outside the cutout the scrim still blocks, and a stray tap must
    // not advance the tour either.
    await tester.tapAt(
      tester.getTopLeft(find.text('alvo')) - const Offset(40, 40),
    );
    await _settleStep(tester);
    expect(taps, 1);
    expect(find.text('Sua conta'), findsOneWidget);
  });

  testWidgets(
    'spotlight glides between targets instead of snapping instantly',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final targets = OnboardingTargets();

      await tester.pumpWidget(_harness(targets, () {}));
      await _settleStep(tester); // opening step, no target

      await tester.tap(find.text('Continuar')); // -> step 1: identity
      await _settleStep(tester);
      final ringAtIdentity = tester.getRect(
        find.byKey(const Key('onboarding_ring')),
      );

      await tester.tap(find.text('Continuar')); // -> step 2: period
      // Small steps so the fake clock doesn't leap straight over the whole
      // 300ms glide in one pump — this samples partway through it.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 6));
      }
      final ringMidGlide = tester.getRect(
        find.byKey(const Key('onboarding_ring')),
      );

      await _settleStep(tester);
      final ringAtPeriod = tester.getRect(
        find.byKey(const Key('onboarding_ring')),
      );

      // The two targets are stacked vertically 300px apart — a real glide
      // sits strictly between them; a snap would already equal one or the
      // other on this very first frame.
      expect(ringMidGlide.top, greaterThan(ringAtIdentity.top));
      expect(ringMidGlide.top, lessThan(ringAtPeriod.top));
    },
  );

  testWidgets('back button returns to the previous step', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final targets = OnboardingTargets();

    await tester.pumpWidget(_harness(targets, () {}));
    await _settleStep(tester);

    // First step has no back button.
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

    await tester.tap(find.text('Continuar'));
    await _settleStep(tester);
    expect(find.text('Sua conta'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _settleStep(tester);

    expect(find.textContaining('Oi, João!'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('skipping closes the tour and marks it seen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var finished = false;
    final targets = OnboardingTargets();

    await tester.pumpWidget(
      _harness(targets, () {}, onFinish: () => finished = true),
    );
    await _settleStep(tester);

    expect(find.textContaining('Oi, João!'), findsOneWidget);

    await tester.tap(find.text('Pular'));
    await _settleStep(tester);

    expect(finished, isTrue);
    expect(await shouldShowOnboardingTour('user-a'), isFalse);
  });
}
