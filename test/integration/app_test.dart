import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putrace/main.dart';

void main() {
  group('Putrace App Integration Tests', () {
    testWidgets('App should start without crashing', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const PutraceApp());

      // Verify that the app starts
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation should work', (WidgetTester tester) async {
      await tester.pumpWidget(const PutraceApp());
      
      // Wait for the app to load
      await tester.pumpAndSettle();
      
      // Verify basic navigation elements exist
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
