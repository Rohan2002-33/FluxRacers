import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../player/player_options.dart';
import 'race_mode.dart';

class RacingScreen extends StatefulWidget {
  const RacingScreen({required this.mode, super.key});

  final RaceMode mode;

  @override
  State<RacingScreen> createState() => _RacingScreenState();
}

class _RacingScreenState extends State<RacingScreen> {
  static const MethodChannel _raceChannel = MethodChannel(
    'com.fluxracers/godot',
  );

  String? _launchError;
  bool _launching = true;

  @override
  void initState() {
    super.initState();
    unawaited(_launchGodotRace());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: _launching
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryCyan),
                  SizedBox(height: 20),
                  Text(
                    'STARTING 3D RACE',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              )
            : _buildLaunchError(context),
      ),
    );
  }

  Future<void> _launchGodotRace() async {
    if (kIsWeb) {
      _showLaunchError(
        'The Godot 3D race host is not integrated for Web yet.',
      );
      return;
    }

    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      final options = await PlayerOptionsStore.loadOptions();
      await _raceChannel.invokeMethod<Map<Object?, Object?>>('launchRace', {
        'mode': widget.mode.argument,
        'options': options.toMap(),
      });
      if (mounted) context.go('/');
    } on MissingPluginException {
      _showLaunchError(
        'The Godot 3D race host is not available on this platform.',
      );
    } on PlatformException catch (error) {
      _showLaunchError(
        error.message ?? 'The Godot 3D race could not be started.',
      );
    }
  }

  void _showLaunchError(String message) {
    if (!mounted) return;
    setState(() {
      _launching = false;
      _launchError = message;
    });
  }

  Widget _buildLaunchError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videogame_asset_off_outlined,
            size: 48,
            color: AppColors.warningRed,
          ),
          const SizedBox(height: 16),
          Text(
            _launchError ?? 'The Godot 3D race could not be started.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(onPressed: _retry, child: const Text('RETRY')),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('MAIN MENU'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _launching = true;
      _launchError = null;
    });
    unawaited(_launchGodotRace());
  }
}
