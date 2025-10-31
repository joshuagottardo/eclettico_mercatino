// lib/item_detail_page.dart - AGGIORNATO CON GESTIONE VARIANTI

import 'dart:convert'; // (1) Import per JSON
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; // (2) Import per HTTP
import 'package:app/add_variant_page.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // (3) Nuove variabili di stato per le varianti
  List _variants = []; // Conterrà la lista delle varianti
  bool _isVariantsLoading = false; // true = stiamo caricando

  // (4) initState: viene chiamato all'avvio della pagina
  @override
  void initState() {
    super.initState();

    // Controlliamo se l'articolo ha varianti
    if (widget.item['has_variants'] == true) {
      // Se sì, avviamo il caricamento
      _fetchVariants();
    }
  }

  // (5) Nuova funzione per caricare le varianti dall'API
  Future<void> _fetchVariants() async {
    // Impostiamo lo stato di caricamento
    setState(() {
      _isVariantsLoading = true;
    });

    try {
      // Prendiamo l'ID dell'articolo
      final itemId = widget.item['item_id'];
      final url =
          'http://trentin-nas.synology.me:4000/api/items/$itemId/variants';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Successo! Aggiorniamo la nostra lista
        setState(() {
          _variants = jsonDecode(response.body);
          _isVariantsLoading = false;
        });
      } else {
        // Errore server
        print('Errore server nel caricare varianti: ${response.statusCode}');
        setState(() {
          _isVariantsLoading = false;
        });
      }
    } catch (e) {
      // Errore di rete
      print('Errore di rete nel caricare varianti: $e');
      setState(() {
        _isVariantsLoading = false;
      });
    }
  }

  // Funzione per copiare
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codice copiato negli appunti!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // (6) Metodo Build (aggiornato)
  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(title: Text(item['name'] ?? 'Dettaglio Articolo')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Sezione Codice Univoco (invariata) ---
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
                icon: Icon(
                  Icons.copy,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => _copyToClipboard(item['unique_code'] ?? ''),
                tooltip: 'Copia codice',
              ),
            ],
          ),
          const Divider(height: 32),

          // --- Sezione Info Principali (invariata) ---
          _buildInfoRow('Categoria', item['category']),
          _buildInfoRow('Brand', item['brand']),
          _buildInfoRow('Descrizione', item['description']),
          const Divider(height: 32),
          _buildInfoRow('Valore Stimato', '€ ${item['value'] ?? 'N/D'}'),
          _buildInfoRow(
            'Prezzo di Vendita',
            '€ ${item['sale_price'] ?? 'N/D'}',
          ),

          // --- (7) SEZIONE VARIANTI (MODIFICATA) ---
          if (item['has_variants'] == 1) ...[
            const Divider(height: 32),
            // Titolo della sezione Varianti
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VARIANTI',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                // Bottone per aggiungere nuove varianti
                // Cerca questo blocco (riga 120 circa)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Aggiungi'),

                  // (1) MODIFICHIAMO QUESTA FUNZIONE
                  onPressed: () async {
                    // (2) Apriamo la pagina AddVariantPage e ASPETTIAMO
                    final bool? newVariantAdded = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AddVariantPage(
                              // (3) Passiamo l'ID dell'articolo corrente!
                              itemId: widget.item['item_id'],
                            ),
                      ),
                    );

                    // (4) Se la pagina è stata chiusa con "true" (ovvero abbiamo salvato)...
                    if (newVariantAdded == true) {
                      // ... ricarichiamo la lista delle varianti!
                      _fetchVariants();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contenuto della sezione Varianti
            _buildVariantsSection(),
          ] else ...[
            // Mostra i dati dell'articolo singolo (invariato)
            const Divider(height: 32),
            _buildInfoRow('Pezzi Disponibili', '${item['quantity'] ?? '0'}'),
            _buildInfoRow(
              'Prezzo di Acquisto',
              '€ ${item['purchase_price'] ?? 'N/D'}',
            ),
          ],

          const Divider(height: 32),
          // TODO: Gallerie e Log vendite...
        ],
      ),
    );
  }

  // (8) Nuovo Widget Helper per mostrare la sezione varianti
  Widget _buildVariantsSection() {
    // Caso 1: Sta caricando
    if (_isVariantsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Caso 2: Ha finito di caricare e la lista è vuota
    if (_variants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna variante trovata.'),
        ),
      );
    }

    // Caso 3: Ha finito di caricare e ci sono varianti
    // Usiamo un Column perché la lista sarà dentro un'altra ListView
    // e questo evita errori di scrolling.
    return Column(
      children:
          _variants.map((variant) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(variant['variant_name'] ?? 'Senza nome'),
                subtitle: Text(
                  'Pezzi: ${variant['quantity']} | Prezzo Acq: € ${variant['purchase_price']}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Aprire la pagina di dettaglio della variante
                },
              ),
            );
          }).toList(), // Convertiamo la mappa in una Lista di Widget
    );
  }

  // Funzione helper per le righe (invariata)
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
            value ?? 'Non specificato',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
