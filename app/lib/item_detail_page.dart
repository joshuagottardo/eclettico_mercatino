// lib/item_detail_page.dart - AGGIORNATO CON LOG VENDITE

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:app/add_variant_page.dart'; // Ci serve ancora
import 'package:app/sell_item_dialog.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // Variabili per le varianti
  List _variants = [];
  bool _isVariantsLoading = false;

  // (1 - NUOVO) Variabili di stato per il log vendite
  List _salesLog = [];
  bool _isLogLoading = false;

  @override
  void initState() {
    super.initState();

    // Carichiamo le varianti (se necessario)
    if (widget.item['has_variants'] == 1) {
      _fetchVariants();
    }

    // (2 - NUOVO) Carichiamo sempre lo storico vendite
    _fetchSalesLog();
  }

  // Funzione per caricare le varianti (invariata)
  Future<void> _fetchVariants() async {
    setState(() {
      _isVariantsLoading = true;
    });
    try {
      final itemId = widget.item['item_id'];
      final url =
          'http://trentin-nas.synology.me:4000/api/items/$itemId/variants';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _variants = jsonDecode(response.body);
            _isVariantsLoading = false;
          });
        }
      } else {
        throw Exception('Errore server nel caricare varianti');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _isVariantsLoading = false;
        });
      }
    }
  }

  // (3 - NUOVO) Funzione per caricare lo storico vendite
  Future<void> _fetchSalesLog() async {
    setState(() {
      _isLogLoading = true;
    });

    try {
      final itemId = widget.item['item_id'];
      final url = 'http://trentin-nas.synology.me:4000/api/items/$itemId/sales';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _salesLog = jsonDecode(response.body);
            _isLogLoading = false;
          });
        }
      } else {
        throw Exception('Errore server nel caricare log vendite');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _isLogLoading = false;
        });
      }
    }
  }

  // Funzione per copiare (invariata)
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codice copiato negli appunti!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item['name'] ?? 'Dettaglio Articolo'),

        // (4 - NUOVO) Bottone "Vendi"
        actions: [
          // Cerca questo blocco
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            icon: const Icon(Icons.sell_outlined),
            label: const Text('VENDI'),

            // (1) MODIFICHIAMO QUESTA FUNZIONE
            onPressed: () async {
              // (2) Mostriamo il nostro nuovo pop-up e ASPETTIAMO una risposta
              final bool? saleRegistered = await showDialog(
                context: context,
                builder: (context) {
                  return SellItemDialog(
                    itemId: widget.item['item_id'],
                    hasVariants: widget.item['has_variants'] == 1,
                    variants:
                        _variants, // Passiamo la lista di varianti che abbiamo già caricato
                  );
                },
              );

              // (3) Se il pop-up è stato chiuso con 'true' (vendita registrata!)...
              if (saleRegistered == true) {
                // ... ricarichiamo SIA il log vendite CHE la lista varianti!
                _fetchSalesLog();
                if (widget.item['has_variants'] == 1) {
                  _fetchVariants();
                }
                // TODO: In futuro, dovremo anche ricaricare l'articolo
                //       principale per aggiornare il suo stato "is_sold".
              }
            },
          ),
          const SizedBox(width: 8), // Un po' di spazio
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Sezioni Info e Varianti (invariate) ---
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
          _buildInfoRow('Categoria', item['category']),
          _buildInfoRow('Brand', item['brand']),
          _buildInfoRow('Descrizione', item['description']),
          const Divider(height: 32),
          _buildInfoRow('Valore Stimato', '€ ${item['value'] ?? 'N/D'}'),
          _buildInfoRow(
            'Prezzo di Vendita',
            '€ ${item['sale_price'] ?? 'N/D'}',
          ),

          if (item['has_variants'] == 1) ...[
            const Divider(height: 32),
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
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Aggiungi'),
                  onPressed: () async {
                    final bool? newVariantAdded = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AddVariantPage(itemId: widget.item['item_id']),
                      ),
                    );
                    if (newVariantAdded == true) {
                      _fetchVariants();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildVariantsSection(),
          ] else ...[
            const Divider(height: 32),
            _buildInfoRow('Pezzi Disponibili', '${item['quantity'] ?? '0'}'),
            _buildInfoRow(
              'Prezzo di Acquisto',
              '€ ${item['purchase_price'] ?? 'N/D'}',
            ),
          ],

          // (5 - NUOVO) Sezione Log Vendite
          const Divider(height: 32),
          Text(
            'LOG VENDITE',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildSalesLogSection(), // Chiamiamo il nuovo widget
        ],
      ),
    );
  }

  // --- Widget Helper per le Varianti (invariato) ---
  Widget _buildVariantsSection() {
    if (_isVariantsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_variants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna variante trovata.'),
        ),
      );
    }
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
                  /* TODO: Aprire dettaglio variante */
                },
              ),
            );
          }).toList(),
    );
  }

  // (6 - NUOVO) Widget Helper per il Log Vendite
  Widget _buildSalesLogSection() {
    // Caso 1: Sta caricando
    if (_isLogLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Caso 2: Ha finito di caricare e la lista è vuota
    if (_salesLog.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna vendita registrata.'),
        ),
      );
    }

    // Caso 3: Ha finito di caricare e ci sono vendite
    return Column(
      children:
          _salesLog.map((sale) {
            // Costruiamo il titolo (es. "Venduto su Vinted (Rosso, XL)")
            String title = 'Venduto su ${sale['platform_name'] ?? 'N/D'}';
            if (sale['variant_name'] != null) {
              title += ' (${sale['variant_name']})';
            }

            // Formattiamo la data (rimuoviamo l'ora)
            String date =
                sale['sale_date']?.split('T')[0] ?? 'Data sconosciuta';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: Text(title),
                subtitle: Text(
                  '$date | ${sale['quantity_sold']} pz | Tot: € ${sale['total_price']}',
                ),
              ),
            );
          }).toList(),
    );
  }

  // --- Widget Helper per le righe (invariato) ---
  Widget _buildInfoRow(String label, String? value) {
    // ... (codice invariato)
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
