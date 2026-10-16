// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter/material.dart';
import 'package:protognome/screens/home_screen.dart';

/// Main entry point for the ProtoGNOME application.
///
/// The SQLite setup lives in DatabaseService (see protognomeSqliteInit).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProtoGNOMEApp());
}

/// The root application widget of ProtoGNOME.
/// Configures MaterialApp with a dark violet custom color palette, the
/// desktop's own font (no fonts are downloaded at run time), button presets,
/// and the home screen.
class ProtoGNOMEApp extends StatelessWidget {
  /// Creates the root application widget.
  const ProtoGNOMEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProtoGNOME',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF4F46E5),
          surface: Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardColor: const Color(0xFF1E1E3A),
        dividerColor: const Color(0xFF2A2A4A),
        // The desktop's own font. google_fonts was removed: with no bundled
        // font files it downloaded Inter from fonts.gstatic.com at every
        // start, contradicting "contacts only GitHub", and the late font swap
        // clipped chip labels.
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFB0B0D0)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2A2A4A),
          border: OutlineInputBorder(borderSide: BorderSide.none),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF7C3AED),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF7C3AED)
                : null,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
