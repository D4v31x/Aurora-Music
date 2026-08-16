/// Lightweight particle simulation state for [ParticlesElement]s — kept
/// separate from [VisualizerEngine] purely for readability. One
/// [ParticleSystemRuntime] per element id, persisted across frames (spec:
/// particles need continuity, unlike ordinary resolved properties which are
/// stateless per-frame computations).
library;

import 'dart:math' as math;

class ParticleSnapshot {
  final double x;
  final double y;
  final double size;
  final double alpha;
  const ParticleSnapshot({
    required this.x,
    required this.y,
    required this.size,
    required this.alpha,
  });
}

class _Particle {
  double x, y, vx, vy, age;
  final double life;
  final double size;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
  }) : age = 0;
}

class ParticleSystemRuntime {
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  List<ParticleSnapshot> tick({
    required double dtSeconds,
    required double originX,
    required double originY,
    required int targetCount,
    required double particleSize,
    required double spawnBoost,
  }) {
    for (final p in _particles) {
      p.age += dtSeconds;
    }
    _particles.removeWhere((p) => p.age >= p.life);

    final deficit = targetCount - _particles.length;
    final steadyStateSpawn = deficit > 0 ? deficit * 0.35 : 0.0;
    final burstSpawn = spawnBoost.clamp(0.0, 1.0) * 6;
    final spawnCount = (steadyStateSpawn + burstSpawn).round();
    final cap = (targetCount * 1.5).clamp(0, 400).round();

    for (var i = 0; i < spawnCount && _particles.length < cap; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 20 + _rng.nextDouble() * 70;
      _particles.add(_Particle(
        x: originX,
        y: originY,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        life: 1.0 + _rng.nextDouble() * 1.2,
        size: particleSize * (0.5 + _rng.nextDouble()),
      ));
    }

    for (final p in _particles) {
      p.x += p.vx * dtSeconds;
      p.y += p.vy * dtSeconds;
    }

    return _particles
        .map((p) => ParticleSnapshot(
              x: p.x,
              y: p.y,
              size: p.size,
              alpha: (1 - p.age / p.life).clamp(0.0, 1.0),
            ))
        .toList();
  }
}
