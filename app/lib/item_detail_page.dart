// lib/item_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // (1) Importiamo i servizi per gli appunti

class ItemDetailPage extends StatefulWidget {
  // (2) Dichiariamo la variabile che riceverà i dati dell'articolo
  //    È una mappa (Map) che contiene tutti i campi (name, brand, ecc.)
  final Map<String, dynamic> item;

  // (3) Il costruttore richiede che l'articolo venga passato
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  
  // (4) Una funzione helper per copiare il codice negli appunti
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    
    // Mostriamo un feedback visivo (un messaggio "pop-up" in basso)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codice copiato negli appunti!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // (5) Accediamo all'articolo passato usando "widget.item"
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        // (6) Mostriamo il nome dell'articolo nella barra superiore
        title: Text(item['name'] ?? 'Dettaglio Articolo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Sezione Codice Univoco (come da tue specifiche) ---
          Text(
            'CODICE UNIVOCo',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['unique_code'] ?? 'N/D',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  _copyToClipboard(item['unique_code'] ?? '');
                },
                tooltip: 'Copia codice',
              ),
            ],
          ),
          const Divider(height: 32),

          // --- Sezione Info Principali ---
          _buildInfoRow('Categoria', item['category']),
          _buildInfoRow('Brand', item['brand']),
          _buildInfoRow('Descrizione', item['description']),
          
          const Divider(height: 32),
          
          // --- Sezione Prezzi ---
          _buildInfoRow('Valore Stimato', '€ ${item['value'] ?? 'N/D'}'),
          _buildInfoRow('Prezzo di Vendita', '€ ${item['sale_price'] ?? 'N/D'}'),
          
          // --- Sezione Varianti (Logica Condizionale) ---
          if (item['has_variants'] == true) ...[
            const Divider(height: 32),
            _buildInfoRow('Pezzi / Prezzi', 'Gestiti nelle varianti'),
            // TODO: Aggiungere qui la lista delle varianti
          ] else ...[
            // Mostra i dati dell'articolo singolo
            const Divider(height: 32),
            _buildInfoRow('Pezzi Disponibili', '${item['quantity'] ?? '0'}'),
            _buildInfoRow('Prezzo di Acquisto', '€ ${item['purchase_price'] ?? 'N/D'}'),
          ],

          const Divider(height: 32),

          // --- Segnaposto per Gallerie e Log ---
          // TODO: Aggiungere qui la galleria foto
          // TODO: Aggiungere qui il log vendite
          // TODO: Aggiungere qui il bottone "Vendi"
        ],
      ),
    );
  }

  // (7) Una funzione "helper" per creare le righe di info
  //     in modo pulito ed evitare codice ripetuto
  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'Non specificato', // Mostra 'Non specificato' se il valore è nullo
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}