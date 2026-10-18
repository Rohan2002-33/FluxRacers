import 'package:flutter/services.dart';

class VehicleBuild {
  const VehicleBuild({
    required this.id,
    required this.name,
    required this.description,
    required this.topSpeedKmh,
    required this.acceleration,
    required this.handling,
    this.requiredLevel = 1,
  });

  final String id;
  final String name;
  final String description;
  final int topSpeedKmh;
  final double acceleration;
  final double handling;
  final int requiredLevel;

  static const available = [
    VehicleBuild(
      id: 'street',
      name: 'RIFT STREET',
      description: 'Balanced acceleration, top speed and handling.',
      topSpeedKmh: 220,
      acceleration: 8,
      handling: 1,
    ),
    VehicleBuild(
      id: 'sprint',
      name: 'RIFT SPRINT',
      description: 'Harder acceleration with a higher top speed.',
      topSpeedKmh: 250,
      acceleration: 10,
      handling: 0.9,
      requiredLevel: 3,
    ),
    VehicleBuild(
      id: 'grip',
      name: 'RIFT GRIP',
      description: 'Sharper steering and braking for close traffic.',
      topSpeedKmh: 205,
      acceleration: 7.5,
      handling: 1.2,
      requiredLevel: 5,
    ),
  ];
}

class VehiclePaint {
  const VehiclePaint(this.id, this.name, this.color);

  final String id;
  final String name;
  final int color;

  static const available = [
    VehiclePaint('carmine', 'CARMINE', 0xFFB71923),
    VehiclePaint('cyan', 'FLUX CYAN', 0xFF00BCD4),
    VehiclePaint('pearl', 'PEARL', 0xFFE4E4E4),
    VehiclePaint('graphite', 'GRAPHITE', 0xFF3B424A),
  ];
}

class PlayerOptions {
  const PlayerOptions({
    this.vehicleBuild = 'street',
    this.paint = 'carmine',
    this.steeringSensitivity = 1,
    this.trafficDensity = 1,
    this.graphicsQuality = 'balanced',
    this.musicVolume = 0.35,
    this.effectsVolume = 0.8,
  });

  final String vehicleBuild;
  final String paint;
  final double steeringSensitivity;
  final int trafficDensity;
  final String graphicsQuality;
  final double musicVolume;
  final double effectsVolume;

  VehicleBuild get selectedBuild =>
      VehicleBuild.available.firstWhere((build) => build.id == vehicleBuild);

  VehiclePaint get selectedPaint =>
      VehiclePaint.available.firstWhere((paint) => paint.id == this.paint);

  PlayerOptions copyWith({
    String? vehicleBuild,
    String? paint,
    double? steeringSensitivity,
    int? trafficDensity,
    String? graphicsQuality,
    double? musicVolume,
    double? effectsVolume,
  }) => PlayerOptions(
    vehicleBuild: vehicleBuild ?? this.vehicleBuild,
    paint: paint ?? this.paint,
    steeringSensitivity: steeringSensitivity ?? this.steeringSensitivity,
    trafficDensity: trafficDensity ?? this.trafficDensity,
    graphicsQuality: graphicsQuality ?? this.graphicsQuality,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
  );

  Map<String, Object> toMap() => {
    'vehicleBuild': vehicleBuild,
    'paint': paint,
    'steeringSensitivity': steeringSensitivity,
    'trafficDensity': trafficDensity,
    'graphicsQuality': graphicsQuality,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
  };

  factory PlayerOptions.fromMap(Map<Object?, Object?> map) {
    final build = map['vehicleBuild'];
    final paint = map['paint'];
    final sensitivity = map['steeringSensitivity'];
    final density = map['trafficDensity'];
    final quality = map['graphicsQuality'];
    final musicVolume = map['musicVolume'] ?? 0.35;
    final effectsVolume = map['effectsVolume'] ?? 0.8;
    if (build is! String ||
        !VehicleBuild.available.any((item) => item.id == build) ||
        paint is! String ||
        !VehiclePaint.available.any((item) => item.id == paint) ||
        sensitivity is! num ||
        density is! int ||
        quality is! String ||
        !const {'balanced', 'performance'}.contains(quality)) {
      throw const FormatException('The saved game options are invalid.');
    }
    if (musicVolume is! num ||
        !musicVolume.isFinite ||
        musicVolume < 0 ||
        musicVolume > 1 ||
        effectsVolume is! num ||
        !effectsVolume.isFinite ||
        effectsVolume < 0 ||
        effectsVolume > 1) {
      throw const FormatException('The saved audio settings are invalid.');
    }
    return PlayerOptions(
      vehicleBuild: build,
      paint: paint,
      steeringSensitivity: sensitivity.toDouble().clamp(0.5, 1.5),
      trafficDensity: density.clamp(1, 3),
      graphicsQuality: quality,
      musicVolume: musicVolume.toDouble(),
      effectsVolume: effectsVolume.toDouble(),
    );
  }
}

class PlayerProfile {
  const PlayerProfile({this.level = 1, this.totalPoints = 0, this.credits = 0});

  final int level;
  final int totalPoints;
  final int credits;

  factory PlayerProfile.fromMap(Map<Object?, Object?> map) {
    final level = map['level'];
    final points = map['totalPoints'];
    final credits = map['credits'];
    if (level is! int || points is! int || credits is! int) {
      throw const FormatException('The saved player profile is invalid.');
    }
    return PlayerProfile(level: level, totalPoints: points, credits: credits);
  }
}

class PlayerOptionsStore {
  PlayerOptionsStore._();

  static const MethodChannel channel = MethodChannel('com.fluxracers/godot');

  static Future<PlayerOptions> loadOptions() async {
    final result = await channel.invokeMapMethod<Object?, Object?>(
      'loadPlayerOptions',
    );
    if (result == null) {
      throw const FormatException('The game options could not be loaded.');
    }
    return PlayerOptions.fromMap(result);
  }

  static Future<void> saveOptions(PlayerOptions options) async {
    await channel.invokeMethod<void>('savePlayerOptions', options.toMap());
  }

  static Future<PlayerProfile> loadProfile() async {
    final result = await channel.invokeMapMethod<Object?, Object?>(
      'loadPlayerProfile',
    );
    if (result == null) {
      throw const FormatException('The player profile could not be loaded.');
    }
    return PlayerProfile.fromMap(result);
  }
}
