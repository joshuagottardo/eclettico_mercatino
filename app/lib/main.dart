// main.dart - Aggiornato

import 'package:flutter/material.dart';
// (1) IMPORTIAMO IL NOSTRO NUOVO FILE
import 'package:app/home_page.dart'; 

void main() {
  runApp(const MagazzinoApp());
}

class MagazzinoApp extends StatelessWidget {
  const MagazzinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestione Magazzino',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
          primary: Colors.cyan[300],
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan[400],
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
            borderSide: BorderSide(color: Colors.cyan[300]!),
          ),
          // Stile per il testo "suggerimento" (hintText)
          hintStyle: TextStyle(color: Colors.grey[600]), 
        ),
      ),
      
      // (2) ORA USIAMO LA HomePage IMPORTATA
      home: const HomePage(),
    );
  }
}

// (3) ABBIAMO RIMOSSO la classe HomePage da qui