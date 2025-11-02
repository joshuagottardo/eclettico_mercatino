// lib/search_page.dart - AGGIORNATO CON MASTER-DETAIL

import 'dart:convert';
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_content.dart'; // Importa il nuovo contenuto
import 'package:app/item_detail_page.dart'; // Importa ancora per il mobile
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:app/api_config.dart'; // Importato

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Stati esistenti
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

  // --- (FIX 1) NUOVI STATI PER MASTER-DETAIL ---
  Map<String, dynamic>? _selectedItem;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Breakpoint per tablet
  static const double kTabletBreakpoint = 800.0;
  bool _dataDidChange = false;

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
        http.get(Uri.parse('$kBaseUrl/api/items')),
        http.get(Uri.parse('$kBaseUrl/api/categories')),
      ]);
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        _allItems = data;
        _allBrands =
            _allItems
                .map((item) => item['brand'] as String?)
                .where((brand) => brand != null && brand.isNotEmpty)
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

          // (FIX 1) Se un item era selezionato, aggiornalo
          if (_selectedItem != null) {
            try {
              // Aggiorna i dati dell'item selezionato
              _selectedItem = _allItems.firstWhere(
                (item) => item['item_id'] == _selectedItem!['item_id'],
              );
            } catch (e) {
              _selectedItem = null; // L'item è stato eliminato o non c'è più
            }
          }
        });
      }
    }
  }

  int availableQtyFromItem(Map<String, dynamic> item) {
    final hasVariants =
        item['has_variants'] == 1 || item['has_variants'] == true;
    if (!hasVariants) {
      final q = item['quantity'];
      if (q is int) return q;
      if (q is num) return q.toInt();
      return 0;
    }
    final variants = (item['variants'] as List?) ?? const [];
    int sum = 0;
    for (final v in variants) {
      final q = v is Map ? v['quantity'] : null;
      if (q is int) {
        sum += q;
      } else if (q is num) {
        sum += q.toInt();
      }
    }
    return sum;
  }

  void _filterItems() {
    final searchTerm = _searchController.text.toLowerCase();
    List tempFilteredList = _allItems;
    if (_showOnlyAvailable) {
      tempFilteredList =
          tempFilteredList.where((item) {
            return item['is_sold'] == 0;
          }).toList();
    }
    if (_selectedCategoryId != null) {
      tempFilteredList =
          tempFilteredList.where((item) {
            return item['category_id'] == _selectedCategoryId;
          }).toList();
    }
    if (_selectedBrand != null) {
      tempFilteredList =
          tempFilteredList.where((item) {
            return item['brand'] == _selectedBrand;
          }).toList();
    }
    if (searchTerm.isNotEmpty) {
      tempFilteredList =
          tempFilteredList.where((item) {
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
      _dataDidChange = true;
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
                      }),
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
                      }),
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

  // --- (FIX 1) NUOVO BUILD METHOD RESPONSIVO ---
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= kTabletBreakpoint;

        if (isTablet) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // (FIX) Nuovo widget per l'animazione "skeleton" della lista
  Widget _buildSkeletonList() {
    final Color baseColor = Colors.grey[850]!;
    final Color highlightColor = Colors.grey[700]!;
    final Color boxColor = Colors.grey[850]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 10, // Mostra 10 righe finte
        itemBuilder: (context, index) {
          return Card(
            color: baseColor,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              leading: Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: boxColor,
                  shape: BoxShape.circle,
                ),
              ),
              title: Container(
                height: 16.0,
                width: 200.0,
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              trailing: Container(
                width: 30.0,
                height: 14.0,
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- (FIX 1) LAYOUT MOBILE (Il vecchio build()) ---
  Widget _buildMobileLayout() {
    return PopScope(
      // <-- (FIX) Aggiunto
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // didPop è true se il sistema *ha tentato* di chiudere la pagina
        if (didPop) return;

        // Passa il risultato (se i dati sono cambiati) alla pagina precedente
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildSearchAppBar(),
        body: _buildBodyContent(isTablet: false),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  // --- (FIX 1) LAYOUT TABLET (Master-Detail) ---
  Widget _buildTabletLayout() {
    return PopScope(
      // <-- (FIX) Aggiunto
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // didPop è true se il sistema *ha tentato* di chiudere la pagina
        if (didPop) return;

        // Passa il risultato (se i dati sono cambiati) alla pagina precedente
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildSearchAppBar(), // L'AppBar è condivisa
        body: Row(
          children: [
            // Pannello MASTER (Lista)
            Expanded(
              flex: 1, // La lista occupa 1/3 dello spazio
              child: _buildBodyContent(isTablet: true),
            ),

            const VerticalDivider(width: 1),

            // Pannello DETAIL (Contenuto)
            Expanded(
              flex: 2, // Il dettaglio occupa 2/3 dello spazio
              child:
                  _selectedItem == null
                      ? const Center(
                        child: Text('Seleziona un articolo dalla lista'),
                      )
                      : ItemDetailContent(
                        // Usiamo UniqueKey per forzare il rebuild quando l'item cambia
                        key: UniqueKey(),
                        item: _selectedItem!,
                        showAppBar: false,
                        onDataChanged: (didChange) {
                          if (didChange) {
                            // Se i dati cambiano (es. modifica o delete)
                            // ricarichiamo i dati della lista
                            _fetchPageData();
                          }
                        },
                      ),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  // --- (FIX 1) Widget condivisi ---

  AppBar _buildSearchAppBar() {
    return AppBar(
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
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color:
                (_selectedCategoryId != null ||
                        _selectedBrand != null ||
                        _showOnlyAvailable)
                    ? Theme.of(context).colorScheme.primary
                    : null,
          ),
          tooltip: 'Filtri',
          onPressed: _filtersLoading ? null : _showFilterSheet,
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        _navigateAndReload(context, const AddItemPage());
      },
      tooltip: 'Aggiungi articolo',
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.add, color: Colors.black),
    );
  }

  // (FIX) Sostituito: Nuovo widget per la thumbnail (più grande)
  Widget _buildThumbnail(String? thumbnailPath) {
    final double thumbSize = 80.0; // Dimensione aumentata
    final Color placeholderColor = Colors.grey[850]!;

    return ClipRRect(
      // (FIX) Aumentato il raggio per un look più moderno
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: thumbSize,
        height: thumbSize,
        color: placeholderColor,
        child:
            thumbnailPath != null
                ? Image.network(
                  '$kBaseUrl/$thumbnailPath',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Iconsax.gallery_slash,
                      size: 32,
                      color: Colors.grey[600],
                    );
                  },
                )
                // Icona placeholder se non c'è thumbnail
                : Icon(Iconsax.gallery, size: 32, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildBodyContent({required bool isTablet}) {
    if (_isLoading) {
      return _buildSkeletonList();
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_filteredItems.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty &&
                  _selectedCategoryId == null &&
                  _selectedBrand == null &&
                  !_showOnlyAvailable
              ? 'Nessun articolo. Aggiungine uno!'
              : 'Nessun articolo trovato con questi filtri.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        // Passiamo 'isTablet' al builder della card
        return _buildItemCard(item, isTablet: isTablet);
      },
    );
  }

  // (FIX) Sostituito: Widget Card AGGIORNATO con nuovo layout
  Widget _buildItemCard(Map<String, dynamic> item, {required bool isTablet}) {
    final bool isSold = item['is_sold'] == 1;

    final bool isSelected =
        isTablet &&
        _selectedItem != null &&
        _selectedItem!['item_id'] == item['item_id'];

    Color cardColor;
    if (isSelected) {
      cardColor = Theme.of(context).colorScheme.primary.withAlpha(77);
    } else if (isSold) {
      cardColor = const Color(0xFF422B2B);
    } else {
      cardColor = Theme.of(context).cardColor;
    }

    Color textColor =
        isSold
            ? Colors.grey[400]! // Testo più sbiadito se venduto
            : Theme.of(context).textTheme.bodyLarge!.color!;

    final String brand = item['brand'] ?? 'N/D';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      clipBehavior: Clip.antiAlias, // Per smussare gli angoli dell'InkWell
      child: InkWell(
        onTap: () {
          if (isTablet) {
            setState(() {
              _selectedItem = item;
            });
          } else {
            _navigateAndReload(context, ItemDetailPage(item: item));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0), // Spaziatura interna della card
          child: Row(
            children: [
              // 1. Thumbnail (a sinistra)
              _buildThumbnail(item['thumbnail_path']?.toString()),

              const SizedBox(width: 16),

              // 2. Testo (a destra)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome articolo (Titolo)
                    Text(
                      item['name'] ?? 'Articolo senza nome',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: isSold ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Brand (Sottotitolo)
                    Text(
                      brand,
                      style: TextStyle(
                        color: isSold ? Colors.grey[500] : Colors.grey[400],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // (FIX) Contatore quantità (trailing) RIMOSSO
            ],
          ),
        ),
      ),
    );
  }
}
