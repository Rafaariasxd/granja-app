import 'package:flutter/material.dart';

abstract final class Colores {
  static const monte = Color(0xFF1E5B43);
  static const monteOscuro = Color(0xFF164532);
  static const yema = Color(0xFFF4B23E);
  static const tinta = Color(0xFF1C2520);
  static const tintaMedia = Color(0xFF3F4843);
  static const tintaSuave = Color(0xFF5B655F);
  static const cal = Color(0xFFF5F4EF);
  static const borde = Color(0xFFE2E1DA);
  static const bienFondo = Color(0xFFE3F1E8);
  static const revisarFondo = Color(0xFFFDF0D5);
  static const revisarTexto = Color(0xFF8A5300);
  static const faltaFondo = Color(0xFFE4E3DC);
}

ThemeData temaGranja() {
  const esquema = ColorScheme.light(
    primary: Colores.monte,
    onPrimary: Colors.white,
    secondary: Colores.yema,
    onSecondary: Colores.tinta,
    surface: Colors.white,
    onSurface: Colores.tinta,
    onSurfaceVariant: Colores.tintaSuave,
    outline: Colores.borde,
  );
  const textos = TextTheme(
    displaySmall: TextStyle(fontSize: 44, height: 1, fontWeight: FontWeight.w800),
    headlineMedium: TextStyle(fontSize: 31, height: 1.1, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 18),
    bodyMedium: TextStyle(fontSize: 16),
    bodySmall: TextStyle(fontSize: 15, color: Colores.tintaSuave),
    labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Colores.cal,
    textTheme: textos.apply(bodyColor: Colores.tinta, displayColor: Colores.tinta),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        shape: forma,
        textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: forma,
        side: const BorderSide(color: Colores.monte, width: 2),
        textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colores.borde),
      ),
    ),
  );
}
