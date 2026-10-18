import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import '../features/home/main_menu_screen.dart';
import '../features/racing/race_mode.dart';
import '../features/racing/racing_screen.dart';

class FluxRacersApp extends StatelessWidget {
  const FluxRacersApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainMenuScreen()),
      GoRoute(
        path: '/race',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'career'
              ? RaceMode.career
              : RaceMode.quickRace;
          return RacingScreen(mode: mode);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FLUX RACERS',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
