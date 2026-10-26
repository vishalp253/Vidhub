import 'package:flutter/material.dart';

/// VidHub palette: warm ink-dark surfaces, one coral accent, green for "done".
class TP {
  static const Color bg = Color(0xFF0E1014);
  static const Color surface = Color(0xFF161920);
  static const Color raised = Color(0xFF1D212B);
  static const Color line = Color(0xFF2A2F3B);
  static const Color text = Color(0xFFF2F3F5);
  static const Color muted = Color(0xFF8E95A5);
  static const Color accent = Color(0xFFFF7A59);
  static const Color onAccent = Color(0xFF2B0F07);
  static const Color good = Color(0xFF3DDC97);
  static const Color onGood = Color(0xFF05241A);
  static const Color warn = Color(0xFFFFC857);
  static const Color bad = Color(0xFFFF6B6B);

  static const String font = 'Segoe UI';

  static TextStyle label({Color color = muted, double size = 11.5}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: color,
      );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: TP.font,
    scaffoldBackgroundColor: TP.bg,
    canvasColor: TP.surface,
    dividerColor: TP.line,
    colorScheme: const ColorScheme.dark(
      primary: TP.accent,
      onPrimary: TP.onAccent,
      secondary: TP.good,
      onSecondary: TP.onGood,
      surface: TP.surface,
      onSurface: TP.text,
      error: TP.bad,
    ),
  );
}

/// Text field look used across dialogs and the quick-add box.
InputDecoration tpInput({String? hint, Widget? prefix}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: TP.muted),
    prefixIcon: prefix,
    filled: true,
    fillColor: TP.raised,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(TP.line),
    focusedBorder: border(TP.accent),
    border: border(TP.line),
  );
}
