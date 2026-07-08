// Basic smoke test for the NeoTask app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neotask_pro/main.dart';

void main() {
  testWidgets('NeoTaskApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const NeoTaskApp());
    // Allow the SplashRouter's post-frame callback (restoreSession) to run.
    await tester.pump(const Duration(milliseconds: 100));
    // App should render some widget tree (splash / login / setup screen).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
