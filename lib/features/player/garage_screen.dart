import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import 'player_options.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  PlayerOptions? _options;
  PlayerProfile? _profile;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        PlayerOptionsStore.loadOptions(),
        PlayerOptionsStore.loadProfile(),
      ]);
      if (mounted) {
        setState(() {
          _options = results[0] as PlayerOptions;
          _profile = results[1] as PlayerProfile;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not load garage: $error');
    }
  }

  Future<void> _save() async {
    final options = _options;
    if (options == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PlayerOptionsStore.saveOptions(options);
      if (mounted) context.pop();
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save garage setup: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GARAGE'),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _options == null
          ? _loadingBody()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionTitle('YOUR LICENSED CONCEPT CAR'),
                const SizedBox(height: 8),
                const Text(
                  'Choose a handling build and body paint. These are setups '
                  'for the same verified 3D vehicle model.',
                ),
                const SizedBox(height: 20),
                RadioGroup<String>(
                  groupValue: _options!.vehicleBuild,
                  onChanged: (value) {
                    if (value != null) {
                      setState(
                        () => _options = _options!.copyWith(vehicleBuild: value),
                      );
                    }
                  },
                  child: Column(
                    children: [
                      for (final build in VehicleBuild.available)
                        Card(
                          color: AppColors.surfaceDark,
                          child: RadioListTile<String>(
                            value: build.id,
                            enabled: build.requiredLevel <= _profile!.level,
                            title: Text(build.name),
                            subtitle: Text(
                              build.requiredLevel > _profile!.level
                                  ? 'UNLOCK AT LEVEL ${build.requiredLevel}'
                                  : '${build.description}\n'
                                        '${build.topSpeedKmh} km/h · '
                                        '${build.acceleration.toStringAsFixed(1)} m/s² · '
                                        'Handling ${build.handling.toStringAsFixed(1)}×',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('BODY PAINT'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final paint in VehiclePaint.available)
                      ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(paint.color),
                          radius: 9,
                        ),
                        label: Text(paint.name),
                        selected: _options!.paint == paint.id,
                        onSelected: (_) => setState(
                          () => _options = _options!.copyWith(paint: paint.id),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.warningRed),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'SAVING' : 'SAVE GARAGE SETUP'),
                ),
              ],
            ),
    );
  }

  Widget _loadingBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('RETRY')),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.primaryCyan,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
  );
}
