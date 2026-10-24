import 'package:flutter_test/flutter_test.dart';
import 'package:call_detection_flutter/main.dart';

void main() {
  testWidgets('CallAssistantApp renders HomeScreen with title and actions', (WidgetTester tester) async {
    await tester.pumpWidget(const CallAssistantApp());

    // Verify app title
    expect(find.text('AI Call Assistant'), findsOneWidget);

    // Verify main action button
    expect(find.text('Demo Call शुरू करें'), findsOneWidget);
  });
}
