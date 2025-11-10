import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

// Questa funzione mappa il nome di una categoria a un'icona
IconData getIconForCategory(String? categoryName) {
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
    default: // Per "altro" o categorie non specificate
      return Iconsax.box_1;
  }
}
