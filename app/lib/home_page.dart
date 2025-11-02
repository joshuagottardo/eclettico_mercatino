// lib/home_page.dart - FIX LAYOUT RESPONSIVE (ROBUSTO)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Importiamo le pagine a cui navigare
import 'package:app/search_page.dart';
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_page.dart';
import 'package:app/library_page.dart';
import 'package:app/statistics_page.dart';
import 'package:app/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
        http.get(Uri.parse('$kBaseUrl/api/dashboard/latest-sale')),
        http.get(Uri.parse('$kBaseUrl/api/dashboard/latest-item')),
      ]);

      if (!mounted) return;

      setState(() {
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
                  // --- (FIX 1 e 2) LAYOUT BOTTONI RESPONSIVO ---
                  _buildButtonLayout(context), // Nuovo widget helper

                  const SizedBox(height: 32),

                  // Card ULTIME VENDITE
                  Card(
                    color: Colors.black,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildSalesList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Card ULTIMI ARRIVI
                  Card(
                    color: Colors.black,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildArrivalsList(),
                    ),
                  ),
                ],
              ),
    );
  }

  // --- (FIX 1 e 2) WIDGET PER LAYOUT RESPONSIVO (AGGIORNATO) ---
  Widget _buildButtonLayout(BuildContext context) {
    // Definiamo le funzioni onTap per chiarezza
    void onTapSearch() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchPage()),
      );
    }

    void onTapLibrary() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LibraryPage()),
      );
    }

    void onTapInsert() {
      _navigateAndReload(const AddItemPage());
    }

    void onTapStats() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StatisticsPage()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint per desktop (non iPad)
        const double desktopBreakpoint = 900.0;

        if (constraints.maxWidth > desktopBreakpoint) {
          // LAYOUT DESKTOP: 1 riga con 4 bottoni (tutti expanded)
          return Row(
            children: [
              _buildDashboardButton(
                context,
                icon: Icons.search,
                label: 'Ricerca',
                onTap: onTapSearch,
                isExpanded: true, // <---
              ),
              const SizedBox(width: 16),
              _buildDashboardButton(
                context,
                icon: Icons.inventory_2,
                label: 'Libreria',
                onTap: onTapLibrary,
                isExpanded: true, // <---
              ),
              const SizedBox(width: 16),
              _buildDashboardButton(
                context,
                icon: Icons.add,
                label: 'Inserisci',
                onTap: onTapInsert,
                isExpanded: true, // <---
              ),
              const SizedBox(width: 16),
              _buildDashboardButton(
                context,
                icon: Icons.auto_graph,
                label: 'Statistiche',
                onTap: onTapStats,
                isExpanded: true, // <---
              ),
            ],
          );
        } else {
          // LAYOUT MOBILE/TABLET: 3+1
          return Column(
            // Assicura che i figli (come il bottone 'Statistiche') si allarghino
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _buildDashboardButton(
                    context,
                    icon: Icons.search,
                    label: 'Ricerca',
                    onTap: onTapSearch,
                    isExpanded: true, // <---
                  ),
                  const SizedBox(width: 16),
                  _buildDashboardButton(
                    context,
                    icon: Icons.inventory_2,
                    label: 'Libreria',
                    onTap: onTapLibrary,
                    isExpanded: true, // <---
                  ),
                  const SizedBox(width: 16),
                  _buildDashboardButton(
                    context,
                    icon: Icons.add,
                    label: 'Inserisci',
                    onTap: onTapInsert,
                    isExpanded: true, // <---
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDashboardButton(
                context,
                icon: Icons.auto_graph,
                label: 'Statistiche',
                onTap: onTapStats,
                isExpanded:
                    false, // <--- Non è in una Row, non deve essere Expanded
              ),
            ],
          );
        }
      },
    );
  }
  // --- FINE SEZIONE FIX ---

  // --- (FIX 1) WIDGET HELPER TASTONE (AGGIORNATO) ---
  Widget _buildDashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isExpanded = false, // NUOVO PARAMETRO
  }) {
    // Rimuoviamo la logica 'isFullWidth'
    final buttonContent = InkWell(
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
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );

    // Usiamo il nuovo parametro
    return isExpanded ? Expanded(child: buttonContent) : buttonContent;
  }
  // --- FINE FIX ---

  // Widget per la lista delle Vendite (Invariato)
  Widget _buildSalesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _latestSales.map((sale) => _buildSaleTile(sale)).toList(),
          ),
      ],
    );
  }

  // Widget per la singola vendita (Invariato, non ha icone)
  Widget _buildSaleTile(Map<String, dynamic> sale) {
    String title =
        '${sale['item_name']} ${sale['variant_name'] != null ? '(${sale['variant_name']})' : ''}';

    String price = '€ 0.00';
    if (sale['total_price'] != null) {
      final num? totalPrice = num.tryParse(sale['total_price'].toString());
      if (totalPrice != null) {
        if (totalPrice == totalPrice.toInt()) {
          price = '€ ${totalPrice.toInt()}';
        } else {
          price = '€ ${totalPrice.toStringAsFixed(2)}';
        }
      }
    }

    return InkWell(
      onTap: () {
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
                color: Colors.green[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget per la lista dei Nuovi Arrivi (Invariato)
  Widget _buildArrivalsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
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

  // --- (FIX 3) WIDGET RIGA "ULTIMI ARRIVI" (ICONA RIMOSSA) ---
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
            // Icona e SizedBox rimossi
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
