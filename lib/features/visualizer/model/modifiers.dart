/// Runtime (non-serialized) state a stateful [Modifier] needs to persist
/// between frames — e.g. a smoothing filter's previous output, or an
/// oscillator's phase. Templates themselves stay pure data; the engine owns
/// one [ModifierState] per pipeline stage per bound property.
library;

import 'dart:math' as math;

class ModifierState {
  double previousValue = 0.0;
  double phase = 0.0;
  double randomValue = 0.0;
  double randomTimer = 0.0;
  bool initialized = false;
}

/// A single reusable transform in a [SignalBinding]'s pipeline. Pure
/// description — all mutable state lives in the [ModifierState] passed to
/// [apply], never inside the modifier instance itself, so a `Modifier` is
/// safe to share/serialize as static template data.
sealed class Modifier {
  const Modifier();

  double apply(double input, ModifierState state, double dtSeconds);

  Map<String, dynamic> toJson();

  static Modifier fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'normalize':
        return NormalizeModifier(
          min: (json['min'] as num).toDouble(),
          max: (json['max'] as num).toDouble(),
        );
      case 'clamp':
        return ClampModifier(
            (json['min'] as num).toDouble(), (json['max'] as num).toDouble());
      case 'multiply':
        return MultiplyModifier((json['factor'] as num).toDouble());
      case 'add':
        return AddModifier((json['amount'] as num).toDouble());
      case 'subtract':
        return SubtractModifier((json['amount'] as num).toDouble());
      case 'sensitivity':
        return SensitivityModifier((json['sensitivity'] as num).toDouble());
      case 'remap':
        return RemapModifier(
          inMin: (json['inMin'] as num).toDouble(),
          inMax: (json['inMax'] as num).toDouble(),
          outMin: (json['outMin'] as num).toDouble(),
          outMax: (json['outMax'] as num).toDouble(),
        );
      case 'smooth':
        return SmoothModifier((json['smoothing'] as num).toDouble());
      case 'attackDecay':
        return AttackDecayModifier(
          attackSeconds: (json['attackSeconds'] as num).toDouble(),
          decaySeconds: (json['decaySeconds'] as num).toDouble(),
        );
      case 'power':
        return PowerModifier((json['exponent'] as num).toDouble());
      case 'ease':
        return EaseModifier(EaseCurve.values.firstWhere(
            (c) => c.name == json['curve'],
            orElse: () => EaseCurve.linear));
      case 'abs':
        return const AbsModifier();
      case 'invert':
        return const InvertModifier();
      case 'oscillate':
        return OscillateModifier(
          frequencyHz: (json['frequencyHz'] as num).toDouble(),
          amplitude: (json['amplitude'] as num).toDouble(),
        );
      case 'noise':
        return NoiseModifier(
          amplitude: (json['amplitude'] as num).toDouble(),
          speed: (json['speed'] as num).toDouble(),
        );
      case 'random':
        return RandomModifier(
          changeIntervalSeconds: (json['changeIntervalSeconds'] as num).toDouble(),
        );
      case 'pulse':
        return PulseModifier((json['decaySeconds'] as num).toDouble());
      case 'rotation':
        return RotationModifier((json['speedMultiplier'] as num?)?.toDouble() ?? 1.0);
      default:
        return const NoOpModifier();
    }
  }
}

class NoOpModifier extends Modifier {
  const NoOpModifier();
  @override
  double apply(double input, ModifierState state, double dtSeconds) => input;
  @override
  Map<String, dynamic> toJson() => {'type': 'noop'};
}

/// Normalizes a raw signal from an arbitrary [min]-[max] range to 0.0-1.0.
class NormalizeModifier extends Modifier {
  final double min;
  final double max;
  const NormalizeModifier({this.min = 0.0, this.max = 1.0});
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    if (max <= min) return 0.0;
    return ((input - min) / (max - min)).clamp(0.0, 1.0);
  }
  @override
  Map<String, dynamic> toJson() => {'type': 'normalize', 'min': min, 'max': max};
}

class ClampModifier extends Modifier {
  final double min;
  final double max;
  const ClampModifier(this.min, this.max);
  @override
  double apply(double input, ModifierState state, double dtSeconds) =>
      input.clamp(min, max);
  @override
  Map<String, dynamic> toJson() => {'type': 'clamp', 'min': min, 'max': max};
}

class MultiplyModifier extends Modifier {
  final double factor;
  const MultiplyModifier(this.factor);
  @override
  double apply(double input, ModifierState state, double dtSeconds) => input * factor;
  @override
  Map<String, dynamic> toJson() => {'type': 'multiply', 'factor': factor};
}

class AddModifier extends Modifier {
  final double amount;
  const AddModifier(this.amount);
  @override
  double apply(double input, ModifierState state, double dtSeconds) => input + amount;
  @override
  Map<String, dynamic> toJson() => {'type': 'add', 'amount': amount};
}

class SubtractModifier extends Modifier {
  final double amount;
  const SubtractModifier(this.amount);
  @override
  double apply(double input, ModifierState state, double dtSeconds) => input - amount;
  @override
  Map<String, dynamic> toJson() => {'type': 'subtract', 'amount': amount};
}

/// Semantically the same as [MultiplyModifier] but named to match the
/// audio-reactive-pipeline vocabulary ("sensitivity") used throughout the
/// spec/UI.
class SensitivityModifier extends Modifier {
  final double sensitivity;
  const SensitivityModifier(this.sensitivity);
  @override
  double apply(double input, ModifierState state, double dtSeconds) =>
      input * sensitivity;
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'sensitivity', 'sensitivity': sensitivity};
}

class RemapModifier extends Modifier {
  final double inMin;
  final double inMax;
  final double outMin;
  final double outMax;
  const RemapModifier({
    required this.inMin,
    required this.inMax,
    required this.outMin,
    required this.outMax,
  });
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    if (inMax <= inMin) return outMin;
    final t = ((input - inMin) / (inMax - inMin)).clamp(0.0, 1.0);
    return outMin + t * (outMax - outMin);
  }
  @override
  Map<String, dynamic> toJson() => {
        'type': 'remap',
        'inMin': inMin,
        'inMax': inMax,
        'outMin': outMin,
        'outMax': outMax,
      };
}

/// Exponential moving-average smoothing. [smoothing] is 0.0 (no smoothing,
/// instant response) to just-under-1.0 (very smooth/slow).
class SmoothModifier extends Modifier {
  final double smoothing;
  const SmoothModifier(this.smoothing);
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    final alpha = (1.0 - smoothing).clamp(0.001, 1.0);
    if (!state.initialized) {
      state.previousValue = input;
      state.initialized = true;
      return input;
    }
    state.previousValue += (input - state.previousValue) * alpha;
    return state.previousValue;
  }
  @override
  Map<String, dynamic> toJson() => {'type': 'smooth', 'smoothing': smoothing};
}

/// Rises quickly toward increasing input (over [attackSeconds]) and falls
/// slowly back down (over [decaySeconds]) — the classic envelope-follower
/// shape used for punchy but non-jittery visual response.
class AttackDecayModifier extends Modifier {
  final double attackSeconds;
  final double decaySeconds;
  const AttackDecayModifier({
    required this.attackSeconds,
    required this.decaySeconds,
  });
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    if (!state.initialized) {
      state.previousValue = input;
      state.initialized = true;
      return input;
    }
    final rising = input > state.previousValue;
    final timeConstant = (rising ? attackSeconds : decaySeconds).clamp(0.001, 60.0);
    final alpha = (dtSeconds / timeConstant).clamp(0.0, 1.0);
    state.previousValue += (input - state.previousValue) * alpha;
    return state.previousValue;
  }
  @override
  Map<String, dynamic> toJson() => {
        'type': 'attackDecay',
        'attackSeconds': attackSeconds,
        'decaySeconds': decaySeconds,
      };
}

class PowerModifier extends Modifier {
  final double exponent;
  const PowerModifier(this.exponent);
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    final base = input.abs();
    final result = math.pow(base, exponent).toDouble();
    return input < 0 ? -result : result;
  }
  @override
  Map<String, dynamic> toJson() => {'type': 'power', 'exponent': exponent};
}

enum EaseCurve { linear, easeIn, easeOut, easeInOut }

class EaseModifier extends Modifier {
  final EaseCurve curve;
  const EaseModifier(this.curve);
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    final t = input.clamp(0.0, 1.0);
    switch (curve) {
      case EaseCurve.linear:
        return t;
      case EaseCurve.easeIn:
        return t * t;
      case EaseCurve.easeOut:
        return 1 - (1 - t) * (1 - t);
      case EaseCurve.easeInOut:
        return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
    }
  }
  @override
  Map<String, dynamic> toJson() => {'type': 'ease', 'curve': curve.name};
}

class AbsModifier extends Modifier {
  const AbsModifier();
  @override
  double apply(double input, ModifierState state, double dtSeconds) => input.abs();
  @override
  Map<String, dynamic> toJson() => {'type': 'abs'};
}

/// Inverts a normalized (0.0-1.0) signal: `1.0 - input`.
class InvertModifier extends Modifier {
  const InvertModifier();
  @override
  double apply(double input, ModifierState state, double dtSeconds) => 1.0 - input;
  @override
  Map<String, dynamic> toJson() => {'type': 'invert'};
}

/// Adds a continuous sine wobble on top of the input — useful for idle
/// motion that continues even during silence.
class OscillateModifier extends Modifier {
  final double frequencyHz;
  final double amplitude;
  const OscillateModifier({required this.frequencyHz, required this.amplitude});
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    state.phase += dtSeconds * frequencyHz * 2 * math.pi;
    return input + amplitude * math.sin(state.phase);
  }
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'oscillate', 'frequencyHz': frequencyHz, 'amplitude': amplitude};
}

/// Adds smoothly-interpolated pseudo-random wobble (a cheap approximation
/// of Perlin/simplex noise) on top of the input.
class NoiseModifier extends Modifier {
  final double amplitude;
  final double speed;
  const NoiseModifier({required this.amplitude, required this.speed});
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    state.randomTimer += dtSeconds * speed;
    if (state.randomTimer >= 1.0) {
      state.randomTimer = 0.0;
      state.previousValue = state.randomValue;
      state.randomValue = (_pseudoRandom(state.phase) * 2 - 1);
      state.phase += 1;
    }
    final t = state.randomTimer.clamp(0.0, 1.0);
    final interpolated = state.previousValue + (state.randomValue - state.previousValue) * t;
    return input + interpolated * amplitude;
  }
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'noise', 'amplitude': amplitude, 'speed': speed};
}

/// Ignores [input] and instead picks a new random target value every
/// [changeIntervalSeconds], smoothly interpolating toward it — useful for
/// e.g. randomized particle color/position drift.
class RandomModifier extends Modifier {
  final double changeIntervalSeconds;
  const RandomModifier({required this.changeIntervalSeconds});
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    state.randomTimer += dtSeconds;
    if (state.randomTimer >= changeIntervalSeconds) {
      state.randomTimer = 0.0;
      state.previousValue = state.randomValue;
      state.randomValue = _pseudoRandom(state.phase);
      state.phase += 1;
    }
    final t = (state.randomTimer / changeIntervalSeconds).clamp(0.0, 1.0);
    return state.previousValue + (state.randomValue - state.previousValue) * t;
  }
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'random', 'changeIntervalSeconds': changeIntervalSeconds};
}

/// Treats [input] as a trigger (rising edge) and holds/decays a 0.0-1.0
/// envelope over [decaySeconds] — ideal for beat-pulse-driven scale/opacity.
class PulseModifier extends Modifier {
  final double decaySeconds;
  const PulseModifier(this.decaySeconds);
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    if (input > state.previousValue) {
      state.previousValue = input;
    } else {
      final decayPerSecond = decaySeconds <= 0 ? double.infinity : 1.0 / decaySeconds;
      state.previousValue =
          (state.previousValue - decayPerSecond * dtSeconds).clamp(0.0, 1.0);
    }
    return state.previousValue;
  }
  @override
  Map<String, dynamic> toJson() => {'type': 'pulse', 'decaySeconds': decaySeconds};
}

/// Continuously accumulates rotation (in turns, 0.0-1.0 repeating) at a
/// rate proportional to [input] — bind e.g. `rotation ← beat` for spin speed
/// that reacts to intensity rather than snapping to an absolute angle.
class RotationModifier extends Modifier {
  final double speedMultiplier;
  const RotationModifier(this.speedMultiplier);
  @override
  double apply(double input, ModifierState state, double dtSeconds) {
    state.phase += input * speedMultiplier * dtSeconds;
    return state.phase;
  }
  @override
  Map<String, dynamic> toJson() =>
      {'type': 'rotation', 'speedMultiplier': speedMultiplier};
}

/// Cheap deterministic pseudo-random value in 0.0-1.0 for a given seed —
/// used by [NoiseModifier]/[RandomModifier] instead of `dart:math`'s
/// stateful `Random` so results stay reproducible for the same phase.
double _pseudoRandom(double seed) {
  final x = math.sin(seed * 12.9898) * 43758.5453;
  return x - x.floorToDouble();
}
