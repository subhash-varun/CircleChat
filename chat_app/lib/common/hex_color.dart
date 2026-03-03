import 'package:flutter/material.dart';

class HexColor extends Color {
  HexColor(super.value);

  static Color fromHex(String hexColor) {
    final sanitized = hexColor.replaceAll('#', '');
    final normalized = sanitized.length == 6 ? 'FF$sanitized' : sanitized;
    final value = int.tryParse(normalized, radix: 16) ?? 0xFF137D73;
    return Color(value);
  }
}
