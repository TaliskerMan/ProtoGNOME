// Auto-incremented to version 1.0.12+5 for build release on 2026-08-14 (Rule_028 / CP-AutoIncrement: Parallel HTTP multi-stream range downloader for 3x-6x faster tool downloads)
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'screens/home_screen.dart';

/// Top-level FFI initialization function for Linux sqlite3 dynamic library resolution.
/// (CP-ChangeComments: Overrides Linux sqlite3 lookup to load libsqlite3.so.0 cleanly if libsqlite3.so is missing)
void protognomeFfiInit() {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so.0');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so');
      }
    });
  }
}

/// Main entry point for the ProtoGNOME application.
/// Initializes Flutter bindings, sqflite FFI database handlers with Linux dynamic library fallback,
/// and runs the root [ProtoGNOMEApp] widget.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    protognomeFfiInit();
    sqfliteFfiInit();
    databaseFactory = createDatabaseFactoryFfi(ffiInit: protognomeFfiInit);
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ProtoGNOMEApp());
}

/// The root application widget of ProtoGNOME.
/// Configures MaterialApp with a dark violet custom color palette,
/// custom Google Fonts Inter styling, button presets, and checks home navigation routes.
class ProtoGNOMEApp extends StatelessWidget {
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
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardColor: const Color(0xFF1E1E3A),
        dividerColor: const Color(0xFF2A2A4A),
        textTheme:
            GoogleFonts.interTextTheme(Theme.of(context).textTheme).copyWith(
          displayLarge: const TextStyle(color: Colors.white),
          bodyLarge: const TextStyle(color: Colors.white),
          bodyMedium: const TextStyle(color: Color(0xFFB0B0D0)),
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
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xFF7C3AED)
                  : null),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
