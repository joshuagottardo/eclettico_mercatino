// lib/item_detail_page.dart - FIX COMPLETO (Senza Scaffold)

import 'package:flutter/material.dart';
import 'package:app/item_detail_content.dart'; // Importa il contenuto

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  bool _dataDidChange = false;

  @override
  Widget build(BuildContext context) {
    // (FIX 1) Rimuoviamo Scaffold e AppBar da questo wrapper.
    // (FIX 3) Sostituiamo WillPopScope con PopScope.
    return PopScope(
      canPop: false, // Gestiamo noi il "pop"
      onPopInvoked: (bool didPop) {
        // didPop è true se il sistema *ha tentato* di chiudere la pagina
        if (didPop) return;

        // Passa il risultato (se i dati sono cambiati) alla pagina precedente
        Navigator.pop(context, _dataDidChange);
      },
      // Il figlio è DIRETTAMENTE il contenuto.
      // ItemDetailContent creerà il proprio Scaffold e AppBar (con i bottoni)
      // perché 'showAppBar' è true di default.
      child: GestureDetector(
        // Rileva lo swipe orizzontale
        onHorizontalDragEnd: (DragEndDetails details) {
          // Se lo swipe va da sinistra a destra (velocità positiva)
          // e supera una certa soglia di velocità, chiudi la pagina.
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 100) {
            // Esegui la stessa logica del PopScope
            Navigator.pop(context, _dataDidChange);
          }
        },
        child: ItemDetailContent(
          item: widget.item,
          onDataChanged: (didChange) {
            _dataDidChange = didChange;
          },
        ),
      ),
    );
  }
}
