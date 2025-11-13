import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class IconHelper {
  // --- 1. LOGICA ESISTENTE (Categorie) ---
  static IconData getIconForCategory(String? categoryName) {
    switch (categoryName?.toLowerCase()) {
      case 'motori':
        return Iconsax.car;
      case 'elettronica':
        return Iconsax.devices;
      case 'casa':
        return Iconsax.lamp_on;
      case 'abbigliamento':
        return Iconsax.bag_2;
      case 'intrattenimento':
        return Iconsax.gameboy;
      case 'accessori':
        return Iconsax.watch;
      case 'altro':
        return Iconsax.box_1;
      default: 
        return Iconsax.box_1;
    }
  }

  // --- 2. NUOVA LOGICA (Piattaforme -> Immagini PNG) ---
  static String getPlatformIconPath(dynamic platformId) {
    // Convertiamo l'ID in intero per sicurezza
    int id = int.tryParse(platformId.toString()) ?? 0;

    // ATTENZIONE: Verifica che questi numeri corrispondano agli ID
    // nella tua tabella 'platforms' del database!
    switch (id) {
      case 1: 
        return 'assets/icons/subito.png';
      case 2: 
        return 'assets/icons/vinted.png';
      case 3: 
        return 'assets/icons/wallapop.png'; // o ebay, a seconda del tuo DB
      case 4: 
        return 'assets/icons/vestiaire_collective.png';
      default: 
        // Ritorna un percorso vuoto o un'icona generica se l'ID non c'è
        return ''; 
    }
  }
}