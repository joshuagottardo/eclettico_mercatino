// lib/utils/logger.dart

import 'package:flutter/foundation.dart'; // Per kReleaseMode
import 'package:logger/logger.dart';

// Crea un'istanza globale del logger
final logger = Logger(
  // Imposta il livello di log
  // In modalità sviluppo (debug), mostra tutto (verbose).
  // In modalità produzione (release), mostra solo gli Errori.
  level: kReleaseMode ? Level.error : Level.debug,
  
  // Usa il PrettyPrinter per una stampa colorata e ben formattata
  printer: PrettyPrinter(
    methodCount: 1, // Mostra 1 metodo nello stack trace
    errorMethodCount: 8, // Mostra 8 metodi per gli errori
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);