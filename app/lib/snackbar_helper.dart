import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

void showFloatingSnackBar(BuildContext context, String message, {bool isError = false}) {
  // Rimuove eventuali snackbar precedenti per evitare code
  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Iconsax.close_circle : Iconsax.tick_circle,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      // --- STILE FLOTTANTE ---
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      elevation: 4,
      margin: const EdgeInsets.all(16), // Margine dai bordi (lo fa "galleggiare")
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Bordi arrotondati
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}