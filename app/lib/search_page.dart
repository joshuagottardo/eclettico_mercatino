// lib/search_page.dart - AGGIORNATO CON NUOVO STILE LISTA E ICONE

import 'dart:convert';
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/icon_helper.dart'; // (FIX 2) Importa l'helper
import 'package:iconsax/iconsax.dart'; // (FIX 2) Importa iconsax

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // ... (Tutta la logica e gli stati sono invariati) ...
  List _allItems = [];
  List _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _searchController = TextEditingController();
  List _allCategories = [];
  List _allBrands = [];
  bool _filtersLoading = true;
  int? _selectedCategoryId;
  String? _selectedBrand;
  bool _showOnlyAvailable = false;
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _fetchPageData();
  }
  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _fetchPageData() async {
    setState(() {
      _isLoading = true;
      _filtersLoading = true;
      _errorMessage = null;
    });
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://trentin-nas.synology.me:4000/api/items')),
        http.get(
          Uri.parse('http://trentin-nas.synology.me:4000/api/categories'),
        ),
      ]);
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        _allItems = data;
        _allBrands = _allItems
            .map((item) => item['brand'] as String?)
            .where(
              (brand) => brand != null && brand.isNotEmpty,
            )
            .toSet()
            .toList();
        _allBrands.sort();
      } else {
        throw Exception('Errore nel recupero articoli');
      }
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
          _filterItems();
        });
      }
    }
  }
  void _filterItems() {
    final searchTerm = _searchController.text.toLowerCase();
    List tempFilteredList = _allItems;
    if (_showOnlyAvailable) {
      tempFilteredList = tempFilteredList.where((item) {
        return item['is_sold'] == 0;
      }).toList();
    }
    if (_selectedCategoryId != null) {
      tempFilteredList = tempFilteredList.where((item) {
        return item['category_id'] == _selectedCategoryId;
      }).toList();
    }
    if (_selectedBrand != null) {
      tempFilteredList = tempFilteredList.where((item) {
        return item['brand'] == _selectedBrand;
      }).toList();
    }
    if (searchTerm.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((item) {
        final name = item['name']?.toLowerCase() ?? '';
        final code = item['unique_code']?.toLowerCase() ?? '';
        return name.contains(searchTerm) || code.contains(searchTerm);
      }).toList();
    }
    setState(() {
      _filteredItems = tempFilteredList;
    });
  }
  Future<void> _navigateAndReload(BuildContext context, Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (result == true) {
      _fetchPageData();
    }
  }
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
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
                          setSheetState(() {
                            _selectedCategoryId = null;
                            _selectedBrand = null;
                            _showOnlyAvailable = false;
                          });
                          _filterItems();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    title: const Text('Mostra solo disponibili'),
                    value: _showOnlyAvailable,
                    onChanged: (value) {
                      setSheetState(() {
                        _showOnlyAvailable = value;
                      });
                      _filterItems();
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    value: _selectedCategoryId,
                    items: [
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
                      _filterItems();
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Brand'),
                    value: _selectedBrand,
                    items: [
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
                      _filterItems();
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
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
          ),
          onSubmitted: (value) => _filterItems(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: (_selectedCategoryId != null ||
                      _selectedBrand != null ||
                      _showOnlyAvailable)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Filtri',
            onPressed: _filtersLoading ? null : _showFilterSheet,
          ),
        ],
      ),
      body: _isLoading
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
                        // (FIX 3) Usa la nuova card
                        return _buildItemCard(item); 
                      },
                    ),
      // Il bottone + rimane qui perché questa è la pagina di Ricerca/Gestione
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

  // (FIX 2 e 3) Widget Card AGGIORNATO
  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isSold = item['is_sold'] == 1;

    Color cardColor =
        isSold ? const Color(0xFF422B2B) : Theme.of(context).cardColor;
    Color textColor =
        isSold ? Colors.grey[300]! : Theme.of(context).textTheme.bodyLarge!.color!;
    Color iconColor =
        isSold ? Colors.grey[400]! : Theme.of(context).colorScheme.primary;

    // (FIX 2) Logica Icona
    final IconData itemIcon = isSold 
        ? Iconsax.money_remove 
        : getIconForCategory(item['category_name']);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: () {
          _navigateAndReload(context, ItemDetailPage(item: item));
        },
        // (FIX 2) Icona
        leading: Icon(
          itemIcon,
          color: iconColor,
        ),
        // (FIX 3) Solo Nome
        title: Text(
          item['name'] ?? 'Articolo senza nome',
          style: TextStyle(color: textColor), // Rimosso Bold
        ),
        // (FIX 3) Niente Sottotitolo
        subtitle: null,
        // (FIX 3) Quantità
        trailing: Text(
          (int.tryParse(item['display_quantity'].toString()) ?? 0).toString(),
          style: TextStyle(
            color: Colors.grey[600], // (FIX 3) Colore grigio
            fontSize: 14, // (FIX 3) Font più piccolo
          ),
        ),
      ),
    );
  }
}