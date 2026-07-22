import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vibely/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Vibely smoke tests', () {
    testWidgets('App launches without crashing', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}