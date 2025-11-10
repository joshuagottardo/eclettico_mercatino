import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/search_page.dart';
import 'package:eclettico/add_item_page.dart';
import 'package:eclettico/item_detail_page.dart';
import 'package:eclettico/library_page.dart';
import 'package:eclettico/statistics_page.dart';
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';

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

// Funzione per navigare alla SearchPage con preselezion
  void _navigateToDetail(int itemId) async {
    // Usiamo LayoutBuilder per capire se siamo su Desktop
    final bool isDesktop =
        MediaQuery.of(context).size.width >= SearchPage.kTabletBreakpoint;

    if (isDesktop) {
      // --- SU DESKTOP ---
      // Naviga alla SearchPage e passa l'ID per la preselezione
      _navigateAndReload(SearchPage(preselectedItemId: itemId));
    } else {
      // --- SU MOBILE / TABLET ---
      // Mantiene il comportamento vecchio (vista dettaglio mobile)
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
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
                  _buildButtonLayout(context),

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

  Widget _buildButtonLayout(BuildContext context) {
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
        // --- INIZIO MODIFICA ---
        // Definiamo i nostri breakpoint
        const double desktopBreakpoint = 900.0;
        const double narrowBreakpoint = 500.0; // Breakpoint per telefoni
        // --- FINE MODIFICA ---

        if (constraints.maxWidth > desktopBreakpoint) {
          // --- LAYOUT DESKTOP (4 in fila) ---
          // Aggiunto IntrinsicHeight e stretch per sicurezza
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDashboardButton(
                  context,
                  icon: Iconsax.search_normal_1,
                  label: 'Ricerca',
                  onTap: onTapSearch,
                  isExpanded: true,
                ),
                const SizedBox(width: 16),
                _buildDashboardButton(
                  context,
                  icon: Iconsax.box,
                  label: 'Libreria',
                  onTap: onTapLibrary,
                  isExpanded: true,
                ),
                const SizedBox(width: 16),
                _buildDashboardButton(
                  context,
                  icon: Iconsax.add,
                  label: 'Inserisci',
                  onTap: onTapInsert,
                  isExpanded: true,
                ),
                const SizedBox(width: 16),
                _buildDashboardButton(
                  context,
                  icon: Iconsax.status_up,
                  label: 'Statistiche',
                  onTap: onTapStats,
                  isExpanded: true,
                ),
              ],
            ),
          );
        } else if (constraints.maxWidth > narrowBreakpoint) {
          // --- LAYOUT TABLET (3+1) ---
          // Aggiunto IntrinsicHeight e stretch alla riga da 3
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.search_normal_1,
                      label: 'Ricerca',
                      onTap: onTapSearch,
                      isExpanded: true,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.box,
                      label: 'Libreria',
                      onTap: onTapLibrary,
                      isExpanded: true,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.add,
                      label: 'Inserisci',
                      onTap: onTapInsert,
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildDashboardButton(
                context,
                icon: Iconsax.status_up,
                label: 'Statistiche',
                onTap: onTapStats,
                isExpanded: false,
              ),
            ],
          );
        } else {
          // --- LAYOUT TELEFONO (2+2) ---
          // Aggiunto IntrinsicHeight e stretch alle due righe
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.search_normal_1,
                      label: 'Ricerca',
                      onTap: onTapSearch,
                      isExpanded: true,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.box,
                      label: 'Magazzino',
                      onTap: onTapLibrary,
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.add,
                      label: 'Inserisci',
                      onTap: onTapInsert,
                      isExpanded: true,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardButton(
                      context,
                      icon: Iconsax.status_up,
                      label: 'Statistiche',
                      onTap: onTapStats,
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isExpanded = false,
  }) {
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

    return isExpanded ? Expanded(child: buttonContent) : buttonContent;
  }

  // Widget per la lista delle Vendite
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

  // Widget per la singola vendita
  Widget _buildSaleTile(Map<String, dynamic> sale) {
    String title =
        '${sale['item_name']} ${sale['variant_name'] != null ? '(${sale['variant_name']})' : ''}';

    // --- AGGIUNGI QUESTA RIGA ---
    final String brand = sale['brand'] ?? 'N/D';
    // -------------------------

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  // Aggiunto il sottotitolo
                  Text(
                    brand, // Ora questa variabile esiste ed è corretta
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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

  // Widget per la lista dei Nuovi Arrivi
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
          Column(
            children:
                _latestItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: _buildArrivalTile(item),
                  );
                }).toList(),
          ),
      ],
    );
  }

  // ---  WIDGET RIGA "ULTIMI ARRIVI"  ---
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Senza Nome',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  item['brand'] ?? 'N/D',
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
