import 'dart:convert';
import 'package:eclettico/add_item_page.dart';
import 'package:eclettico/item_detail_content.dart';
import 'package:eclettico/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/api_config.dart';
import 'package:eclettico/empty_state_widget.dart';

class SearchPage extends StatefulWidget {
  final int? preselectedItemId;
  const SearchPage({super.key, this.preselectedItemId});
  static const double kTabletBreakpoint = 800.0;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
  

  Map<String, dynamic>? _selectedItem;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Breakpoint per tablet
  
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

          // --- INIZIO MODIFICA ---
          // Controlla se dobbiamo preselezionare un articolo
          if (widget.preselectedItemId != null) {
            try {
              _selectedItem = _allItems.firstWhere(
                (item) => item['item_id'] == widget.preselectedItemId,
              );
            } catch (e) {
              _selectedItem = null; // L'articolo non è stato trovato
            }
          }
          // Altrimenti, aggiorna quello già selezionato (logica di prima)
          else if (_selectedItem != null) {
            try {
              _selectedItem = _allItems.firstWhere(
                (item) => item['item_id'] == _selectedItem!['item_id'],
              );
            } catch (e) {
              _selectedItem = null;
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

  // --- NUOVO BUILD METHOD RESPONSIVO ---
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= SearchPage.kTabletBreakpoint;

        if (isTablet) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

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
        itemCount: 10,
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

  Widget _buildMobileLayout() {
    return PopScope(
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

  Widget _buildTabletLayout() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildSearchAppBar(),
        body: Row(
          children: [
            Expanded(flex: 1, child: _buildBodyContent(isTablet: true)),

            const VerticalDivider(width: 1),

            Expanded(
              flex: 2,
              child:
                  _selectedItem == null
                      ? const Center(
                        child: Text('Seleziona un articolo dalla lista'),
                      )
                      : ItemDetailContent(
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

  AppBar _buildSearchAppBar() {
    return AppBar(
      title: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
        ), // Aggiunge spazio sopra e sotto
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cerca per nome o codice...',
            prefixIcon: Icon(Iconsax.search_normal_1, color: Colors.grey[600]),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Iconsax.close_square),
                      onPressed: () => _searchController.clear(),
                    )
                    : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
          ),
          onSubmitted: (value) => _filterItems(),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Iconsax.filter,
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
      child: const Icon(Iconsax.add, color: Colors.black),
    );
  }

  Widget _buildThumbnail(String? thumbnailPath) {
    final double thumbSize = 80.0; // Dimensione aumentata
    final Color placeholderColor = Colors.grey[850]!;

    return ClipRRect(
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
      final bool isFiltering = _searchController.text.isNotEmpty ||
          _selectedCategoryId != null ||
          _selectedBrand != null ||
          _showOnlyAvailable;

      if (isFiltering) {
        return const EmptyStateWidget(
          icon: Iconsax.search_status,
          title: 'Nessun risultato',
          subtitle: 'Non abbiamo trovato articoli che corrispondono alla tua ricerca. Prova a cambiare i filtri.',
        );
      } else {
        return EmptyStateWidget(
          icon: Iconsax.box_add,
          title: 'Magazzino Vuoto',
          subtitle: 'Non ci sono ancora articoli nel tuo magazzino.\nInizia aggiungendone uno!',
          actionLabel: 'Aggiungi Articolo',
          onAction: () => _navigateAndReload(context, const AddItemPage()),
        );
      }
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

  Widget _buildItemCard(Map<String, dynamic> item, {required bool isTablet}) {
    final bool isSold = item['is_sold'] == 1;

    final bool isSelected =
        isTablet &&
        _selectedItem != null &&
        _selectedItem!['item_id'] == item['item_id'];

    // --- INIZIO MODIFICA ---
    // 1. Leggiamo il nuovo flag dall'API
    final bool isPublished =
        item['is_published'] == 1 || item['is_published'] == true;

    Color cardColor;
    if (isSelected) {
      // Priorità 1: Se è selezionato su tablet, ha il colore di selezione
      cardColor = Theme.of(context).colorScheme.primary.withAlpha(77);
    } else if (isSold) {
      // Priorità 2: Se è venduto, è rosso
      cardColor = const Color(0xFF422B2B);
    } else if (!isPublished) {
      // Priorità 3: Se non venduto E non pubblicato, è sbiadito
      cardColor = const Color(0xFF4E3F2A);
    } else {
      // Altrimenti, è normale
      cardColor = Theme.of(context).cardColor;
    }
    // --- FINE MODIFICA ---

    Color textColor =
        isSold
            ? Colors.grey[400]!
            : Theme.of(context).textTheme.bodyLarge!.color!;

    final String brand = item['brand'] ?? 'N/D';

    return Card(
      color: cardColor, // Usa il colore calcolato
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      clipBehavior: Clip.antiAlias,
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
              if (item['has_variants'] == 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Iconsax.add,
                    size: 18,
                    color: Colors.grey[600], // Sottile e non rumoroso
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
