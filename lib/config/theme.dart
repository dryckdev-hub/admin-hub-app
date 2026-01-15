import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Colores "Bakery Premium"
  static const Color primary = Color(0xFF5D4037); // Café oscuro elegante
  static const Color secondary = Color(0xFFD7CCC8); // Crema suave
  static const Color accent = Color(0xFFFF7043); // Naranja quemado para acciones (botones)
  static const Color background = Color(0xFFF5F5F5); // Gris muy claro (limpio)
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primary, // Usamos primary como secondary para sobriedad
        surface: surface,
        background: background,
        error: error,
        tertiary: accent,
      ),
      scaffoldBackgroundColor: background,
      
      // Tipografía Moderna
      textTheme: GoogleFonts.latoTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay( // Para títulos grandes/números
          fontSize: 32, fontWeight: FontWeight.bold, color: primary
        ),
        titleLarge: GoogleFonts.lato(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87
        ),
        bodyLarge: GoogleFonts.lato(fontSize: 16, color: Colors.black87),
        bodyMedium: GoogleFonts.lato(fontSize: 14, color: Colors.black54),
      ),

      // Estilo de Tarjetas (Limpio y con sombra suave)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Inputs modernos
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      
      // Appbar Limpio
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
      ),
    );
  }
}