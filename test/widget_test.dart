// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_study_planner/main.dart';

void main() {
  testWidgets('Student Pomodoro App Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PomodoroApp());

    // Verify that all nav bar icons are present, including the new Contact icon.
    expect(find.byIcon(Icons.calendar_today), findsOneWidget,
        reason: 'Planner icon should be present');
    expect(find.byIcon(Icons.bar_chart), findsOneWidget,
        reason: 'Stats icon should be present');
    expect(find.byIcon(Icons.timer), findsOneWidget,
        reason: 'Timer icon should be present');
    expect(find.byIcon(Icons.note), findsOneWidget,
        reason: 'Notes icon should be present');
    expect(find.byIcon(Icons.contact_mail), findsOneWidget,
        reason: 'Contact icon should be present');

    // Verify the initial state of the timer screen.
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('زمان تمرکز'), findsOneWidget);

    // Let's try tapping on the new "Contact Us" tab.
    await tester.tap(find.byIcon(Icons.contact_mail));
    await tester.pumpAndSettle(); // Wait for animations to finish.

    // Verify that the contact screen is now visible by checking its title and content.
    expect(find.text('تماس با ما'), findsOneWidget);
    expect(find.textContaining('حمیدرضا علی میرزایی'), findsOneWidget);
    expect(find.textContaining('alimirzaei.hr@gmail.com'), findsOneWidget);
  });
}
