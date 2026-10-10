import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/screens/main_screen.dart';

void main() {
  testWidgets('College Event App MainScreen loads successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(),
      ),
    );

    expect(find.text('Discover Events'), findsOneWidget);
    expect(find.text('Featured Event'), findsOneWidget);
    expect(find.text('Upcoming Events'), findsOneWidget);
  });
}