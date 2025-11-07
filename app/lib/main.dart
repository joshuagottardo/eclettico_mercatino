
import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:eclettico/home_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (kDebugMode) log(details.exceptionAsString(), stackTrace: details.stack);
  };

  runZonedGuarded(
    () {

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

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey, 
          brightness: Brightness.dark,
          primary: Colors.white, 
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          surfaceTintColor: Color.fromARGB(255, 46, 46, 46),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, 
            foregroundColor: Colors.black, 
          ),
        ),

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
            ),
          ),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),

      home: const HomePage(),
    );
  }
}
