import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:galactic_three_kingdoms_epic_saga/main.dart';
import 'package:galactic_three_kingdoms_epic_saga/widgets/pseudo3d_scene.dart';

void main() {
  testWidgets('Splash transitions to main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GalacticGameplayApp());
    expect(find.byType(Pseudo3DScene), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byType(Pseudo3DScene), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets);
    expect(find.text('Pseudo3D'), findsNothing);
  });
}
