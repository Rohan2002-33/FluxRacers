// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux_racers/app/app.dart';

void main() {
  testWidgets('main menu displays its title and menu options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FluxRacersApp());

    expect(find.text('FLUX RACERS'), findsOneWidget);
    expect(find.text('CAREER'), findsOneWidget);
    expect(find.text('QUICK RACE'), findsOneWidget);
    expect(find.text('GARAGE'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    await tester.tap(find.text('QUICK RACE'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0 KM/H'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PAUSED'), findsNothing);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('QUIT'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FLUX RACERS'), findsOneWidget);
  });

  testWidgets('main menu does not overflow at landscape height', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FluxRacersApp());

    expect(find.text('FLUX RACERS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
