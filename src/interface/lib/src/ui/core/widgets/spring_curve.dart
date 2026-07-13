import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpringCurve extends Curve {
  const SpringCurve();
  @override
  double transformInternal(double t) {
    const damping = 12.0;
    const stiffness = 150.0;
    const mass = 1.0;
    final omega = stiffness / mass;
    final zeta = damping / (2 * mass * math.sqrt(omega));
    final omegaD = omega * math.sqrt(1 - zeta * zeta);
    const A = 1.0;
    const phi = 0.0;
    return 1.0 - A * math.exp(-zeta * omega * t) * math.cos(omegaD * t + phi);
  }
}
