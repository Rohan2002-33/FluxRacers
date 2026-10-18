import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import 'player_options.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PlayerOptions? _options;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final options = await PlayerOptionsStore.loadOptions();
      if (mounted) setState(() => _options = options);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not load settings: $error');
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
        setState(() => _error = 'Could not save settings: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _options == null
          ? _loadingBody()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'STEERING SENSITIVITY  '
                  '${_options!.steeringSensitivity.toStringAsFixed(1)}×',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _options!.steeringSensitivity,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  label: '${_options!.steeringSensitivity.toStringAsFixed(1)}×',
                  onChanged: (value) => setState(
                    () => _options = _options!.copyWith(
                      steeringSensitivity: value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TRAFFIC DENSITY',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('LOW')),
                    ButtonSegment(value: 2, label: Text('MID')),
                    ButtonSegment(value: 3, label: Text('HIGH')),
                  ],
                  selected: {_options!.trafficDensity},
                  onSelectionChanged: (selection) => setState(
                    () => _options = _options!.copyWith(
                      trafficDensity: selection.first,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('PERFORMANCE GRAPHICS'),
                  subtitle: const Text(
                    'Use reduced 3D rendering scale to improve frame rate.',
                  ),
                  value: _options!.graphicsQuality == 'performance',
                  onChanged: (enabled) => setState(
                    () => _options = _options!.copyWith(
                      graphicsQuality: enabled ? 'performance' : 'balanced',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'AUDIO MIX',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'MUSIC  ${(_options!.musicVolume * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Slider(
                  value: _options!.musicVolume,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  label: '${(_options!.musicVolume * 100).round()}%',
                  onChanged: (value) => setState(
                    () => _options = _options!.copyWith(musicVolume: value),
                  ),
                ),
                Text(
                  'VEHICLE & EFFECTS  '
                  '${(_options!.effectsVolume * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Slider(
                  value: _options!.effectsVolume,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  label: '${(_options!.effectsVolume * 100).round()}%',
                  onChanged: (value) => setState(
                    () => _options = _options!.copyWith(effectsVolume: value),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Audio and gameplay options are saved on this device and used '
                  'for the next race.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.warningRed),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'SAVING' : 'SAVE SETTINGS'),
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
}
