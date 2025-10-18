// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomopal/main.dart';

void main() {
  // A basic smoke test to ensure the app loads without crashing.
  testWidgets('App loads and shows Timer screen initially',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PomodoroApp());

    // Verify that the app title for the timer screen is present.
    expect(find.text('تایمر پومودورو'), findsOneWidget);

    // Verify that the initial time is '25:00'.
    expect(find.text('25:00'), findsOneWidget);

    // Verify that the initial mode is "Focus Time".
    expect(find.text('زمان تمرکز'), findsOneWidget);
  });

  // Test to ensure all bottom navigation bar items navigate to the correct screen.
  testWidgets('Bottom navigation bar switches pages correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PomodoroApp());

    // Tap on the 'Planner' icon and verify.
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle(); // Wait for page transition
    expect(find.text('برنامه‌ریز هفتگی'), findsOneWidget);

    // Tap on the 'Goals' icon and verify.
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    expect(find.text('اهداف تحصیلی'), findsOneWidget);

    // Tap on the 'Stats' icon and verify.
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('گزارش عملکرد'), findsOneWidget);

    // Tap on the 'Settings' icon and verify.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('تنظیمات و پروفایل'), findsOneWidget);

    // Go back to the 'Timer' screen to complete the cycle.
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    expect(find.text('تایمر پومودورو'), findsOneWidget);
  });

  // Test to check the functionality of timer controls (play, pause).
  testWidgets('Timer controls are present and functional',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PomodoroApp());

    // Ensure play, reset, and skip buttons are present.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.replay), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);

    // Tap the play button.
    await tester.tap(find.byIcon(Icons.play_circle_filled));
    await tester.pump(); // Trigger a frame to update the UI.

    // Verify the icon changes to pause.
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_filled), findsNothing);

    // Tap the pause button.
    await tester.tap(find.byIcon(Icons.pause_circle_filled));
    await tester.pump();

    // Verify the icon changes back to play.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
  });
}
