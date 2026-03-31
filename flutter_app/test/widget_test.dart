import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/screens/login_screen.dart';
import 'package:flutter_app/src/state/game_state.dart';

void _ignoreRenderFlexOverflowForTest() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final text = details.exceptionAsString();
    if (text.contains('A RenderFlex overflowed')) return;
    if (original != null) {
      original(details);
      return;
    }
    FlutterError.presentError(details);
  };
}

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    final state = GameState();
    await tester.pumpWidget(CartelHoodFlutterApp(gameState: state));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('jail popup opens in home shell', (WidgetTester tester) async {
    _ignoreRenderFlexOverflowForTest();
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    final state = GameState()
      ..loggedIn = true
      ..onboardingCompleted = true
      ..nicknameChosen = true
      ..jailUntilEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;

    await tester.pumpWidget(CartelHoodFlutterApp(gameState: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('YAKALANDIN!'), findsOneWidget);
    expect(find.textContaining('80 Altın'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('hospital popup opens in home shell', (
    WidgetTester tester,
  ) async {
    _ignoreRenderFlexOverflowForTest();
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    final state = GameState()
      ..loggedIn = true
      ..onboardingCompleted = true
      ..nicknameChosen = true
      ..hospitalUntilEpoch =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;

    await tester.pumpWidget(CartelHoodFlutterApp(gameState: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('HASTANELİK OLDUN!'), findsOneWidget);
    expect(find.textContaining('80 Altın'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });
}
