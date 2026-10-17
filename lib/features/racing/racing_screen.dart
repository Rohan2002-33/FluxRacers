import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:go_router/go_router.dart';

import '../../game/flux_racers_game.dart';
import '../../app/theme/app_colors.dart';

class RacingScreen extends StatefulWidget {
  const RacingScreen({super.key});

  @override
  State<RacingScreen> createState() => _RacingScreenState();
}

class _RacingScreenState extends State<RacingScreen> {
  late final FluxRacersGame _game;

  @override
  void initState() {
    super.initState();
    // Lock to landscape for the actual racing experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _game = FluxRacersGame();
  }

  @override
  void dispose() {
    // Revert to portrait when leaving the race
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // The Flame Game Engine Canvas
          GameWidget(game: _game),

          // HUD Overlay (Speed, Time, etc.)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _game.speedNotifier,
                    builder: (context, speed, child) {
                      return Text(
                        '${speed.toInt()} KM/H',
                        style: const TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _game.timeNotifier,
                    builder: (context, time, child) {
                      return Text(
                        'TIME: ${time.toStringAsFixed(1)}s',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Pause Button
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.pause,
                color: AppColors.textPrimary,
                size: 32,
              ),
              onPressed: () {
                _game.pauseEngine();
                _showPauseDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPauseDialog(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'PAUSED',
          style: TextStyle(color: AppColors.primaryCyan),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _game.resumeEngine();
            },
            child: const Text(
              'RESUME',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              screenContext.go('/');
            },
            child: const Text(
              'QUIT',
              style: TextStyle(color: AppColors.warningRed),
            ),
          ),
        ],
      ),
    );
  }
}
