// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// [FIX]: Corrected the package name to match 'pubspec.yaml'.
import 'package:pomopal_app/main.dart';

void main() {
  testWidgets('Smoke test: App loads and shows the timer screen',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PomodoroApp());

    // Verify that the timer screen is displayed by default.
    // We expect to find the text for the initial timer mode.
    expect(find.text('زمان تمرکز'), findsOneWidget);

    // Verify that the initial timer value is displayed (assuming 25 minutes default).
    expect(find.text('25:00'), findsOneWidget);

    // Verify the play button is present.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
  });

  testWidgets('Bottom navigation bar navigates to different screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PomodoroApp());

    // Tap the 'Planner' icon and verify navigation.
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle(); // Wait for navigation animation
    expect(find.text('برنامه‌ریز هفتگی'), findsOneWidget);

    // Tap the 'Goals' icon and verify navigation.
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    expect(find.text('اهداف تحصیلی'), findsOneWidget);

    // Tap the 'Stats' icon and verify navigation.
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('گزارش عملکرد'), findsOneWidget);

    // Tap the 'Settings' icon and verify navigation.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('تنظیمات و پروفایل'), findsOneWidget);
  });

  testWidgets('Timer controls work correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const PomodoroApp());

    // Initial state: Play button is visible.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);

    // Tap the play button to start the timer.
    await tester.tap(find.byIcon(Icons.play_circle_filled));
    await tester.pump(); // Trigger a frame to update the UI.

    // After starting: Pause button is visible.
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_filled), findsNothing);

    // Let the timer run for a second.
    await tester.pump(const Duration(seconds: 1));

    // Verify the timer has counted down.
    expect(find.text('24:59'), findsOneWidget);

    // Tap the pause button.
    await tester.tap(find.byIcon(Icons.pause_circle_filled));
    await tester.pump();

    // After pausing: Play button is visible again.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
  });
}
