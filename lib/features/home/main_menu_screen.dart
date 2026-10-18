import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../player/player_options.dart';
import '../racing/race_mode.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  PlayerProfile _profile = const PlayerProfile();
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await PlayerOptionsStore.loadProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _profileError = null;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _profileError = 'PROFILE UNAVAILABLE: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), AppColors.backgroundDark],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'FLUX RACERS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          color: AppColors.primaryCyan,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 20.0,
                                              color: AppColors.primaryCyan
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ],
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'OWN THE ROAD. CONTROL THE RUSH.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(letterSpacing: 3.0),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMenuButton(
                                  context,
                                  'CAREER',
                                  Icons.flag,
                                  () {
                                    context.go(
                                      '/race?mode=${RaceMode.career.argument}',
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildMenuButton(
                                  context,
                                  'QUICK RACE',
                                  Icons.speed,
                                  () => context.go(
                                    '/race?mode=${RaceMode.quickRace.argument}',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildMenuButton(
                                  context,
                                  'GRID SPRINT',
                                  Icons.emoji_events,
                                  () => context.go(
                                    '/race?mode=${RaceMode.competitiveSprint.argument}',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildMenuButton(
                                  context,
                                  'TIME TRIAL',
                                  Icons.timer,
                                  () => context.go(
                                    '/race?mode=${RaceMode.timeTrial.argument}',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildMenuButton(
                                  context,
                                  'GARAGE',
                                  Icons.directions_car,
                                  () => context
                                      .push('/garage')
                                      .then((_) => _loadProfile()),
                                ),
                                const SizedBox(height: 16),
                                _buildMenuButton(
                                  context,
                                  'SETTINGS',
                                  Icons.settings,
                                  () => context.push('/settings'),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark.withValues(
                                      alpha: 0.8,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.surfaceLight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildProfileStat(
                                        Icons.star,
                                        AppColors.secondaryOrange,
                                        'LVL ${_profile.level}',
                                      ),
                                      _buildProfileStat(
                                        Icons.bolt,
                                        AppColors.secondaryOrange,
                                        '${_profile.totalPoints}',
                                      ),
                                      _buildProfileStat(
                                        Icons.monetization_on,
                                        AppColors.primaryCyan,
                                        '${_profile.credits}',
                                      ),
                                    ],
                                  ),
                                ),
                                if (_profileError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _profileError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.warningRed,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.primaryCyan, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryCyan, size: 24),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(IconData icon, Color color, String value) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
