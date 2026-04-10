import 'package:flutter_test/flutter_test.dart';

import 'package:galactic_three_kingdoms_epic_saga/main.dart';

void main() {
  testWidgets('Splash transitions to main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GalacticGameplayApp());
    expect(find.text('Inventory'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('War'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Pseudo3D'), findsNothing);
  });
}
