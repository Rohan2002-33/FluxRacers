// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux_racers/app/app.dart';
import 'package:flux_racers/features/player/player_options.dart';

void main() {
  testWidgets('main menu displays its title and menu options', (
    WidgetTester tester,
  ) async {
    const raceChannel = MethodChannel('com.fluxracers/godot');
    final platformChannel = SystemChannels.platform;
    final raceLaunch = Completer<void>();
    var raceLaunchCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(raceChannel, (call) async {
          switch (call.method) {
            case 'loadPlayerProfile':
              return {'level': 1, 'totalPoints': 0, 'credits': 0};
            case 'loadPlayerOptions':
              return const PlayerOptions().toMap();
            case 'launchRace':
              expect((call.arguments as Map)['mode'], 'quickRace');
              final options = (call.arguments as Map)['options'] as Map;
              expect(options['musicVolume'], 0.35);
              expect(options['effectsVolume'], 0.8);
              raceLaunchCount++;
              await raceLaunch.future;
              return null;
            default:
              fail('Unexpected method ${call.method}');
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async => null);
    addTearDown(
      () {
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(raceChannel, null);
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(platformChannel, null);
      },
    );

    await tester.pumpWidget(const FluxRacersApp());

    expect(find.text('FLUX RACERS'), findsOneWidget);
    expect(find.text('CAREER'), findsOneWidget);
    expect(find.text('QUICK RACE'), findsOneWidget);
    expect(find.text('GARAGE'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    await tester.tap(find.text('QUICK RACE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(raceLaunchCount, 1);
    expect(find.text('STARTING 3D RACE'), findsOneWidget);

    raceLaunch.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FLUX RACERS'), findsOneWidget);
  });

  testWidgets('career selection launches the career game mode', (
    WidgetTester tester,
  ) async {
    const raceChannel = MethodChannel('com.fluxracers/godot');
    final platformChannel = SystemChannels.platform;
    Object? launchArguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(raceChannel, (call) async {
          switch (call.method) {
            case 'loadPlayerProfile':
              return {'level': 1, 'totalPoints': 0, 'credits': 0};
            case 'loadPlayerOptions':
              return const PlayerOptions().toMap();
            case 'launchRace':
              launchArguments = call.arguments;
              return null;
            default:
              fail('Unexpected method ${call.method}');
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async => null);
    addTearDown(
      () {
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(raceChannel, null);
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(platformChannel, null);
      },
    );

    await tester.pumpWidget(const FluxRacersApp());
    await tester.tap(find.text('CAREER'));
    await tester.pumpAndSettle();

    expect((launchArguments as Map)['mode'], 'career');
    expect((launchArguments as Map)['options'], isA<Map>());
    expect(find.text('FLUX RACERS'), findsOneWidget);
  });

  testWidgets('garage saves the selected car build and paint', (
    WidgetTester tester,
  ) async {
    const raceChannel = MethodChannel('com.fluxracers/godot');
    var savedOptions = const PlayerOptions().toMap();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(raceChannel, (call) async {
          switch (call.method) {
            case 'loadPlayerProfile':
              return {'level': 5, 'totalPoints': 4750, 'credits': 1050};
            case 'loadPlayerOptions':
              return savedOptions;
            case 'savePlayerOptions':
              savedOptions = Map<String, Object>.from(call.arguments as Map);
              return null;
            default:
              fail('Unexpected method ${call.method}');
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(
      () {
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(raceChannel, null);
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      },
    );

    await tester.pumpWidget(const FluxRacersApp());
    await tester.tap(find.text('GARAGE'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR LICENSED CONCEPT CAR'), findsOneWidget);

    await tester.tap(find.text('RIFT SPRINT'));
    await tester.tap(find.text('FLUX CYAN'));
    await tester.tap(find.text('SAVE GARAGE SETUP'));
    await tester.pumpAndSettle();

    expect(savedOptions['vehicleBuild'], 'sprint');
    expect(savedOptions['paint'], 'cyan');
    expect(find.text('FLUX RACERS'), findsOneWidget);
  });

  testWidgets('settings persist control, traffic and graphics options', (
    WidgetTester tester,
  ) async {
    const raceChannel = MethodChannel('com.fluxracers/godot');
    var savedOptions = const PlayerOptions().toMap();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(raceChannel, (call) async {
          switch (call.method) {
            case 'loadPlayerProfile':
              return {'level': 1, 'totalPoints': 0, 'credits': 0};
            case 'loadPlayerOptions':
              return savedOptions;
            case 'savePlayerOptions':
              savedOptions = Map<String, Object>.from(call.arguments as Map);
              return null;
            default:
              fail('Unexpected method ${call.method}');
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(
      () {
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(raceChannel, null);
        TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      },
    );

    await tester.pumpWidget(const FluxRacersApp());
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HIGH'));
    await tester.tap(find.text('PERFORMANCE GRAPHICS'));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('MUSIC  35%'), findsOneWidget);
    expect(find.text('VEHICLE & EFFECTS  80%'), findsOneWidget);
    await tester.tap(find.text('SAVE SETTINGS'));
    await tester.pumpAndSettle();

    expect(savedOptions['trafficDensity'], 3);
    expect(savedOptions['graphicsQuality'], 'performance');
    expect(savedOptions['musicVolume'], 0.35);
    expect(savedOptions['effectsVolume'], 0.8);
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
