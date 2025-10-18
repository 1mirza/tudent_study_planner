// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the main app file from your project.
// The project name 'pomopal_app' is based on your pubspec.yaml.
import 'package:pomopal_app/main.dart';

void main() {
  testWidgets('Smoke test: App loads and shows the timer screen',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PomodoroApp());

    // Verify that the initial screen is the Timer screen.
    expect(find.text('تایمر پومودورو'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
  });

  testWidgets('Bottom navigation bar navigates to different screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PomodoroApp());

    // Tap the 'Planner' icon and verify.
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle(); // Wait for animations to finish
    expect(find.text('برنامه‌ریز هفتگی'), findsOneWidget);

    // Tap the 'Goals' icon and verify.
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    expect(find.text('اهداف تحصیلی'), findsOneWidget);

    // Tap the 'Stats' icon and verify.
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('گزارش عملکرد'), findsOneWidget);

    // Tap the 'Settings' icon and verify.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('تنظیمات و پروفایل'), findsOneWidget);

    // Go back to the Timer screen to complete the test.
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    expect(find.text('تایمر پومودورو'), findsOneWidget);
  });

  testWidgets('Timer controls play and pause the timer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PomodoroApp());

    // Verify the initial state is paused.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);

    // Tap the play button.
    await tester.tap(find.byIcon(Icons.play_circle_filled));
    await tester.pump(); // Trigger a frame to update the UI

    // Verify the state is now playing.
    expect(find.byIcon(Icons.play_circle_filled), findsNothing);
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

    // Tap the pause button.
    await tester.tap(find.byIcon(Icons.pause_circle_filled));
    await tester.pump(); // Trigger a frame to update the UI

    // Verify the state is back to paused.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
  });
}
