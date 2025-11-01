// lib/home_page.dart - FIX ERRORE toInt() e LISTE

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Importiamo le pagine a cui navigare
import 'package:app/search_page.dart';
import 'package:app/add_item_page.dart';
import 'package:app/item_list_page.dart';
import 'package:app/item_detail_page.dart';
import 'package:app/library_page.dart';
import 'package:app/api_config.dart'; // Importato l'URL base

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Ora sono List
  List _latestSales = [];
  List _latestItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Funzione per caricare i dati della dashboard
  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        // Usiamo kBaseUrl
        http.get(Uri.parse('$kBaseUrl/api/dashboard/latest-sale')),
        http.get(Uri.parse('$kBaseUrl/api/dashboard/latest-item')),
      ]);

      if (!mounted) return;

      setState(() {
        // CORREZIONE: Decodifichiamo come List<dynamic>
        if (responses[0].statusCode == 200) {
          _latestSales = jsonDecode(responses[0].body) as List<dynamic>;
        }
        if (responses[1].statusCode == 200) {
          _latestItems = jsonDecode(responses[1].body) as List<dynamic>;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Errore di rete o conversione: $e';
        });
      }
      print('Errore caricamento dashboard: $e');
    }
  }

  // Funzione per navigare e ricaricare
  void _navigateAndReload(Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (result == true) {
      _fetchDashboardData();
    }
  }

  // Funzione per navigare al dettaglio dopo aver preso i dati
  void _navigateToDetail(int itemId) async {
    try {
      // Usiamo kBaseUrl
      final url = '$kBaseUrl/api/items/$itemId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final itemData = jsonDecode(response.body);
        _navigateAndReload(ItemDetailPage(item: itemData));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: Articolo non trovato.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore di rete durante il recupero dei dettagli.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchDashboardData,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Riga 1: I "Tastoni" ---
                  Row(
                    children: [
                      _buildDashboardButton(
                        context,
                        icon: Icons.search,
                        label: 'Ricerca',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),

                      _buildDashboardButton(
                        context,
                        icon: Icons.inventory_2,
                        label: 'Libreria',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LibraryPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),

                      _buildDashboardButton(
                        context,
                        icon: Icons.add,
                        label: 'Inserisci',
                        onTap: () {
                          _navigateAndReload(const AddItemPage());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // FIX 2: Avvolgiamo la lista delle vendite in un Card
                  Card(
                    color: Colors.black, // <-- Cambiato a nero
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildSalesList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // FIX 2: Impostiamo il colore del Card su nero per gli ULTIMI ARRIVI
                  Card(
                    color: Colors.black, // <-- Cambiato a nero
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildArrivalsList(),
                    ),
                  ),
                ],
              ),
    );
  }

  // Widget Helper per i "Tastoni" (Invariato)
  Widget _buildDashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  // Widget per la lista delle Vendite (AGGIORNATO)
  Widget _buildSalesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FIX 1 e 3: Nuovo Titolo e stile più marcato
        Text(
          'ULTIME VENDITE',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        if (_latestSales.isEmpty)
          const Text('Nessuna vendita recente.')
        else
          // Usiamo un Column perché vogliamo i separatori
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _latestSales.map((sale) => _buildSaleTile(sale)).toList(),
          ),
      ],
    );
  }

  Widget _buildSaleTile(Map<String, dynamic> sale) {
    String title =
        '${sale['item_name']} ${sale['variant_name'] != null ? '(${sale['variant_name']})' : ''}';

    // CORREZIONE: Gestione sicura del prezzo
    String price = '€ 0.00';
    if (sale['total_price'] != null) {
      final num? totalPrice = num.tryParse(sale['total_price'].toString());
      if (totalPrice != null) {
        if (totalPrice == totalPrice.toInt()) {
          // FIX CHIAVE: Rimosso il '+'
          price = '€ ${totalPrice.toInt()}';
        } else {
          // FIX CHIAVE: Rimosso il '+'
          price = '€ ${totalPrice.toStringAsFixed(2)}';
        }
      }
    }

    return InkWell(
      onTap: () {
        // Naviga al dettaglio usando l'item_id
        _navigateToDetail(sale['item_id']);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Text(
              price,
              style: TextStyle(
                color: Colors.green[600], // Verde per i guadagni
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget per la lista dei Nuovi Arrivi (AGGIORNATO)
  Widget _buildArrivalsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FIX 3: Nuovo Titolo e stile più marcato
        Text(
          'ULTIMI ARRIVI',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        if (_latestItems.isEmpty)
          const Text('Nessun articolo aggiunto di recente.')
        else
          // Usiamo un ListView.separated per avere le linee divisorie
          ListView.separated(
            physics:
                const NeverScrollableScrollPhysics(), // Non far scrollare la lista interna
            shrinkWrap: true, // Adatta la lista al contenuto
            itemCount: _latestItems.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = _latestItems[index];
              return _buildArrivalTile(item);
            },
          ),
      ],
    );
  }

  // Widget per la singola riga di arrivo (Invariato)
  Widget _buildArrivalTile(Map<String, dynamic> item) {
    return InkWell(
      onTap: () {
        // Naviga al dettaglio usando l'item_id
        _navigateToDetail(item['item_id']);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(
              Icons.new_releases,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Senza Nome',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  item['category_name'] ?? 'N/D',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
