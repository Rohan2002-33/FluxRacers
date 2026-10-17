import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Logo / Title
                Text(
                  'FLUX RACERS',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.primaryCyan,
                    shadows: [
                      Shadow(
                        blurRadius: 20.0,
                        color: AppColors.primaryCyan.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'OWN THE ROAD. CONTROL THE RUSH.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(letterSpacing: 3.0),
                ),

                const Spacer(),

                // Menu Buttons
                _buildMenuButton(context, 'CAREER', Icons.flag, () {}),
                const SizedBox(height: 16),
                _buildMenuButton(context, 'QUICK RACE', Icons.speed, () {}),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  'GARAGE',
                  Icons.directions_car,
                  () {},
                ),
                const SizedBox(height: 16),
                _buildMenuButton(context, 'SETTINGS', Icons.settings, () {}),

                const Spacer(),

                // Player Stats (Placeholder for Phase 4)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.secondaryOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LVL 1',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(width: 24),
                      const Icon(
                        Icons.monetization_on,
                        color: AppColors.primaryCyan,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('0', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
      width: 280,
      height: 56,
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
}
