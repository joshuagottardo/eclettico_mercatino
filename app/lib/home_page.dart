// lib/home_page.dart - AGGIORNATO CON STILE "VENDUTO" RIFINITO

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // (1 - MODIFICA) Riportiamo le due liste per la ricerca
  List _allItems = [];
  List _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  // (2 - MODIFICA) Riportiamo il controller per la ricerca
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Aggiungiamo l'ascoltatore
    _searchController.addListener(_filterItems);
    _fetchItems();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/items';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          final data = jsonDecode(response.body);
          setState(() {
            _allItems = data;
            // Applichiamo subito il filtro (se c'è testo nella barra)
            _filterItems();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Errore nel recupero degli articoli: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore di rete: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // (3 - MODIFICA) Riportiamo la funzione di filtro
  void _filterItems() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems =
            _allItems.where((item) {
              final name = item['name']?.toLowerCase() ?? '';
              final code = item['unique_code']?.toLowerCase() ?? '';
              return name.contains(searchTerm) || code.contains(searchTerm);
            }).toList();
      }
    });
  }

  // (4 - MODIFICA) Riportiamo la funzione di navigazione
  Future<void> _navigateAndReload(BuildContext context, Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (result == true) {
      _fetchItems(); // Ricarica i dati
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // (5 - MODIFICA) Riportiamo la barra di ricerca
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cerca per nome o codice...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                    : null,
          ),
          onSubmitted: (value) => _filterItems(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtri',
            onPressed: () {},
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
              // (6 - MODIFICA) Usiamo _filteredItems
              : _filteredItems.isEmpty
              ? Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'Nessun articolo. Aggiungine uno!'
                      : 'Nessun articolo trovato.',
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
      // (7 - MODIFICA) Riportiamo il FloatingActionButton
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

  // Widget helper per costruire una singola Card Articolo
  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isSold = item['is_sold'] == 1;

    // (FIX 1) Un rosso molto scuro e desaturato, "meno acceso"
    Color cardColor =
        isSold ? const Color(0xFF422B2B) : Theme.of(context).cardColor;
    // Colori di testo e icone che funzionano bene sul rosso scuro
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
          // (8 - MODIFICA) Usiamo la funzione di navigazione
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
            // (FIX 2) Badge "VENDUTO" rimosso
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: iconColor),
      ),
    );
  }
}
