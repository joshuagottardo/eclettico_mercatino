// main.dart - AGGIORNATO CON ACCENTO BIANCO
import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app/home_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Logga gli errori Flutter con stacktrace leggibile
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (kDebugMode) log(details.exceptionAsString(), stackTrace: details.stack);
  };

  // Cattura errori asincroni fuori dal tree Flutter
  runZonedGuarded(
    () {
      // Opzionale: più verbosità sulle ricostruzioni (solo per debug di lag UI)
      // debugPrintRebuildDirtyWidgets = true;

      runApp(const MagazzinoApp());
    },
    (error, stack) {
      if (kDebugMode) log('Uncaught (zone): $error', stackTrace: stack);
    },
  );
}

class MagazzinoApp extends StatelessWidget {
  const MagazzinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestione Magazzino',
      theme: ThemeData(
        fontFamily: GoogleFonts.inconsolata().fontFamily,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),

        // (1 - MODIFICA) Cambiamo il colore primario
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey, // Un seme neutro
          brightness: Brightness.dark,
          primary: Colors.white, // (Era Colors.cyan[300])
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),

        // (2 - MODIFICA) Bottoni
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, // (Era Colors.cyan[400])
            foregroundColor: Colors.black, // (Già corretto)
          ),
        ),

        // (3 - MODIFICA) Campi di testo
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(
              color: Colors.white,
            ), // (Era Colors.cyan[300])
          ),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),

      home: const HomePage(),
    );
  }
}
