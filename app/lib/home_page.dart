// lib/home_page.dart - AGGIORNATO CON FILTRI AVANZATI

import 'dart:convert';
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List _allItems = [];
  List _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();

  // (1 - NUOVO) Variabili per i filtri
  List _allCategories = []; // Caricate dall'API
  List _allBrands = []; // Costruita da _allItems
  bool _filtersLoading = true; // Unico loader per categorie/brand

  // (2 - NUOVO) Stato dei filtri attivi
  int? _selectedCategoryId;
  String? _selectedBrand;
  bool _showOnlyAvailable = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);

    // (3 - MODIFICA) Carichiamo sia gli articoli che i dati per i filtri
    _fetchPageData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  // (4 - NUOVO) Funzione unica per caricare tutti i dati
  Future<void> _fetchPageData() async {
    setState(() {
      _isLoading = true;
      _filtersLoading = true;
      _errorMessage = null;
    });

    try {
      // Eseguiamo i caricamenti in parallelo
      final responses = await Future.wait([
        http.get(Uri.parse('http://trentin-nas.synology.me:4000/api/items')),
        http.get(
          Uri.parse('http://trentin-nas.synology.me:4000/api/categories'),
        ),
      ]);

      // Gestione risposta Articoli
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        _allItems = data;

        // (5 - NUOVO) Costruiamo la lista di Brand dinamicamente
        // Usiamo un Set per avere solo valori unici, poi convertiamo in Lista
        _allBrands =
            _allItems
                .map((item) => item['brand'] as String?) // Prende tutti i brand
                .where(
                  (brand) => brand != null && brand.isNotEmpty,
                ) // Filtra i nulli/vuoti
                .toSet() // Rimuove i duplicati
                .toList(); // Converte in lista
        _allBrands.sort(); // Ordina alfabeticamente
      } else {
        throw Exception('Errore nel recupero articoli');
      }

      // Gestione risposta Categorie
      if (responses[1].statusCode == 200) {
        _allCategories = jsonDecode(responses[1].body);
      } else {
        throw Exception('Errore nel recupero categorie');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore di rete o caricamento: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filtersLoading = false;
          _filterItems(); // Applica i filtri (anche quelli di default)
        });
      }
    }
  }

  // (6 - MODIFICA) Questa funzione ora applica TUTTI i filtri
  void _filterItems() {
    final searchTerm = _searchController.text.toLowerCase();

    // Inizia con la lista completa
    List tempFilteredList = _allItems;

    // --- Applica i filtri di stato ---

    // 1. Filtro Disponibilità
    if (_showOnlyAvailable) {
      tempFilteredList =
          tempFilteredList.where((item) {
            return item['is_sold'] == 0;
          }).toList();
    }

    // 2. Filtro Categoria
    if (_selectedCategoryId != null) {
      tempFilteredList =
          tempFilteredList.where((item) {
            return item['category_id'] == _selectedCategoryId;
          }).toList();
    }

    // 3. Filtro Brand
    if (_selectedBrand != null) {
      tempFilteredList =
          tempFilteredList.where((item) {
            return item['brand'] == _selectedBrand;
          }).toList();
    }

    // --- Applica il filtro di Ricerca (alla fine) ---
    if (searchTerm.isNotEmpty) {
      tempFilteredList =
          tempFilteredList.where((item) {
            final name = item['name']?.toLowerCase() ?? '';
            final code = item['unique_code']?.toLowerCase() ?? '';
            return name.contains(searchTerm) || code.contains(searchTerm);
          }).toList();
    }

    // Aggiorna l'interfaccia
    setState(() {
      _filteredItems = tempFilteredList;
    });
  }

  // Funzione di navigazione (invariata)
  Future<void> _navigateAndReload(BuildContext context, Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (result == true) {
      _fetchPageData(); // Ricarica tutto
    }
  }

  // (7 - NUOVO) Funzione per mostrare il pannello filtri
  void _showFilterSheet() {
    // Usiamo showModalBottomSheet per un pannello che sale dal basso
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E), // Sfondo scuro
      builder: (context) {
        // Usiamo StatefulBuilder affinché il pannello possa
        // gestire il suo stato temporaneo (selezioni)
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtri',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      TextButton(
                        child: const Text('Pulisci Filtri'),
                        onPressed: () {
                          // Resetta i filtri
                          setSheetState(() {
                            _selectedCategoryId = null;
                            _selectedBrand = null;
                            _showOnlyAvailable = false;
                          });
                          // Applica e chiudi
                          _filterItems();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const Divider(),

                  // --- Filtro Disponibilità ---
                  SwitchListTile.adaptive(
                    title: const Text('Mostra solo disponibili'),
                    value: _showOnlyAvailable,
                    onChanged: (value) {
                      setSheetState(() {
                        _showOnlyAvailable = value;
                      });
                      _filterItems(); // Applica subito
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  // --- Filtro Categoria ---
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    value: _selectedCategoryId,
                    items: [
                      // Aggiungi un'opzione "Tutte"
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Tutte le categorie'),
                      ),
                      ..._allCategories.map<DropdownMenuItem<int>>((category) {
                        return DropdownMenuItem<int>(
                          value: category['category_id'],
                          child: Text(category['name']),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        _selectedCategoryId = value;
                      });
                      _filterItems(); // Applica subito
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Filtro Brand ---
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Brand'),
                    value: _selectedBrand,
                    items: [
                      // Aggiungi un'opzione "Tutti"
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tutti i brand'),
                      ),
                      ..._allBrands.map<DropdownMenuItem<String>>((brand) {
                        return DropdownMenuItem<String>(
                          value: brand,
                          child: Text(brand),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        _selectedBrand = value;
                      });
                      _filterItems(); // Applica subito
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cerca per nome o codice...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                    : null,
          ),
          onSubmitted: (value) => _filterItems(),
        ),
        actions: [
          // (8 - MODIFICA) Collega il bottone alla funzione
          IconButton(
            icon: Icon(
              Icons.filter_list,
              // (9 - NUOVO) Cambia colore se i filtri sono attivi
              color:
                  (_selectedCategoryId != null ||
                          _selectedBrand != null ||
                          _showOnlyAvailable)
                      ? Theme.of(context).colorScheme.primary
                      : null,
            ),
            tooltip: 'Filtri',
            onPressed:
                _filtersLoading
                    ? null
                    : _showFilterSheet, // Disabilita se sta caricando
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
              : _errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMessage!, textAlign: TextAlign.center),
                ),
              )
              : _filteredItems.isEmpty
              ? Center(
                child: Text(
                  _searchController.text.isEmpty &&
                          _selectedCategoryId == null &&
                          _selectedBrand == null &&
                          !_showOnlyAvailable
                      ? 'Nessun articolo. Aggiungine uno!'
                      : 'Nessun articolo trovato con questi filtri.',
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return _buildItemCard(item);
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _navigateAndReload(context, const AddItemPage());
        },
        tooltip: 'Aggiungi articolo',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // Widget helper per la Card (INVARIATO)
  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isSold = item['is_sold'] == 1;

    Color cardColor =
        isSold ? const Color(0xFF422B2B) : Theme.of(context).cardColor;
    Color textColor =
        isSold
            ? Colors.grey[300]!
            : Theme.of(context).textTheme.bodyLarge!.color!;
    Color subtitleColor =
        isSold
            ? Colors.grey[400]!
            : Theme.of(context).textTheme.bodySmall!.color!;
    Color iconColor =
        isSold ? Colors.grey[400]! : Theme.of(context).colorScheme.primary;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: () {
          _navigateAndReload(context, ItemDetailPage(item: item));
        },
        leading: Icon(
          isSold
              ? Icons.money_off
              : (item['has_variants'] == 1
                  ? Icons.category
                  : Icons.inventory_2),
          color: iconColor,
        ),
        title: Text(
          item['name'] ?? 'Articolo senza nome',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Codice: ${item['unique_code'] ?? 'N/D'}',
              style: TextStyle(color: subtitleColor),
            ),
            if (item['category_name'] != null && item['category_name'] != '')
              Text(
                'Categoria: ${item['category_name']}',
                style: TextStyle(color: subtitleColor),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: iconColor),
      ),
    );
  }
}
