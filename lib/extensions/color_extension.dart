import 'package:flutter/material.dart';

extension ColorExtension on Color {
  Color withValues({
    int? red,
    int? green,
    int? blue,
    double? alpha,
  }) {
    return Color.fromRGBO(
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
      alpha ?? this.alpha / 255,
    );
  }
} 