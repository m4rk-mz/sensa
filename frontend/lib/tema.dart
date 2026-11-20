import 'package:flutter/material.dart';

/// Paleta de la maqueta: fondo crema, índigo como color principal y ámbar
/// para las alertas. El ámbar y el índigo se distinguen también por
/// luminosidad, no solo por tono, para que se lean bien.
class ColoresSensa {
  static const Color crema = Color(0xFFFAF7F0);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieTenue = Color(0xFFF7F4ED);
  static const Color borde = Color(0xFFE4DED1);
  static const Color tinta = Color(0xFF1B1A22);
  static const Color tintaTenue = Color(0xFF5B5768);
  static const Color indigo = Color(0xFF4338CA);
  static const Color indigoOscuro = Color(0xFF312E81);
  static const Color indigoTenue = Color(0xFFEEEDFA);
  static const Color ambar = Color(0xFFB45309);
  static const Color ambarTexto = Color(0xFF8A4B08);
  static const Color ambarTenue = Color(0xFFFDEBCE);
  static const Color verde = Color(0xFF0D5F56);
  static const Color verdeTenue = Color(0xFFDDEFEB);

  /// Pantalla LCD del nodo (1602 con retroiluminación azul).
  static const Color lcdFondo = Color(0xFF0B2E4F);
  static const Color lcdTexto = Color(0xFFDCF3FF);
}

ThemeData temaSensa() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresSensa.indigo,
    primary: ColoresSensa.indigo,
    surface: ColoresSensa.superficie,
    error: ColoresSensa.ambar,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresSensa.crema,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresSensa.crema,
      foregroundColor: ColoresSensa.tinta,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresSensa.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresSensa.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresSensa.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresSensa.indigo, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresSensa.ambar, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresSensa.ambar, width: 1.8),
      ),
      errorStyle: const TextStyle(color: ColoresSensa.ambarTexto),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresSensa.indigo,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresSensa.indigoOscuro,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0xFFC9C3E8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ColoresSensa.superficie,
      indicatorColor: ColoresSensa.indigoTenue,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: ColoresSensa.borde,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        color: ColoresSensa.tinta,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ColoresSensa.tinta,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: ColoresSensa.tinta),
      bodySmall: TextStyle(fontSize: 12.5, color: ColoresSensa.tintaTenue),
    ),
  );
}
