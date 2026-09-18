// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cartracker/main.dart';

void main() {
  testWidgets('Shows the title and the maintenance items', (
      WidgetTester tester,
      ) async {
    // Give shared_preferences an empty in-memory store so the app's load
    // finishes without a real device.
    SharedPreferences.setMockInitialValues({});

    // Build our app and let the initial load finish.
    await tester.pumpWidget(const CarMaintenanceApp());
    await tester.pumpAndSettle();

    // Verify the app bar title and that the first items are listed as tiles.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Car Maintenance'), findsOneWidget);
    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('Tire rotation'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);

    // Nothing is saved yet, so every tile shows the unset subtitle.
    expect(find.text('No services logged yet'), findsWidgets);
  });

  testWidgets('Tapping an item opens the service log', (
      WidgetTester tester,
      ) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and let the initial load finish.
    await tester.pumpWidget(const CarMaintenanceApp());
    await tester.pumpAndSettle();

    // Tap the first item and trigger a frame.
    await tester.tap(find.text('Oil change'));
    await tester.pumpAndSettle();

    // Verify the service log opened.
    expect(find.text('Log service'), findsOneWidget);

    // Dismiss it and verify it is gone.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log service'), findsNothing);
  });
}
