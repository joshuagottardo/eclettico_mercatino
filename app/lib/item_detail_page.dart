// lib/item_detail_page.dart - FIX (ORA È UN WRAPPER)

import 'package:flutter/material.dart';
import 'package:app/item_detail_content.dart'; // Importa il nuovo contenuto

// 1. Trasformato in StatefulWidget per gestire il callback
class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // 2. Stato per tracciare se i dati sono cambiati
  bool _dataDidChange = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 3. Quando l'utente torna indietro (con gesture o tasto)
        //    passa il risultato alla pagina precedente
        Navigator.pop(context, _dataDidChange);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Dettagli'),
          // 4. L'AppBar qui è "vuota"
          // Le azioni (Modifica, Vendi, Copia) sono ora gestite
          // all'interno di ItemDetailContent.
          // Per riaverle *solo* su mobile, dovremmo usare un GlobalKey
          // per chiamare i metodi del Content, ma è complesso.
          // Per ora, l'utente può usare il RefreshIndicator 
          // e i bottoni nel corpo della pagina.
        ),
        // 5. Il body è il nuovo widget 'ItemDetailContent'
        body: ItemDetailContent(
          item: widget.item,
          onDataChanged: (didChange) {
            // 6. Aggiorna lo stato se il contenuto notifica un cambiamento
            _dataDidChange = didChange;
            
            // 7. FIX per il delete su mobile:
            // Se l'item è stato eliminato (didChange è true per delete),
            // chiudi questa pagina wrapper.
            if (didChange) {
                // Controlla se il widget è ancora montato prima di chiudere
                if (Navigator.canPop(context)) {
                    Navigator.pop(context, true);
                }
            }
          },
        ),
      ),
    );
  }
}