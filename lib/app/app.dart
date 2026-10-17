import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import '../features/home/main_menu_screen.dart';
import '../features/racing/racing_screen.dart'; // নতুন ইমপোর্ট

class FluxRacersApp extends StatelessWidget {
  const FluxRacersApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainMenuScreen()),
      GoRoute(path: '/race', builder: (context, state) => const RacingScreen()),
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
