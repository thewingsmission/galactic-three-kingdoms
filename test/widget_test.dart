import 'package:flutter_test/flutter_test.dart';

import 'package:galactic_three_kingdoms_gameplay/main.dart';

void main() {
  testWidgets('Inventory landing screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const GalacticGameplayApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Soldier inventory'), findsOneWidget);
    expect(find.text('Go to War'), findsOneWidget);
  });
}
