// lib/item_detail_page.dart - FIX COMPLETO (STABILITÀ, STRUTTURA E BUG)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:app/add_variant_page.dart';
import 'package:app/sell_item_dialog.dart';
import 'package:app/photo_viewer_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/add_item_page.dart';
import 'package:app/edit_sale_dialog.dart';
import 'package:app/icon_helper.dart';
import 'package:iconsax/iconsax.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late Map<String, dynamic> _currentItem;

  List _variants = [];
  bool _isVariantsLoading = false;
  List _salesLog = [];
  bool _isLogLoading = false;
  List _photos = [];
  bool _isPhotosLoading = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  bool _dataDidChange = false;
  List _allPlatforms = [];
  bool _platformsLoading = true;
  bool _isItemSold = false;
  bool _isSalesLogOpen = false; // Stato per il Drawer Log

  // Colori (resi stabili e definiti)
  final Color _soldColor = Colors.red[500]!;
  final Color _availableColor = Colors.green[500]!;
  final Color _headerTextColor = Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _isVariantsLoading = true;
    _isLogLoading = true;
    _isPhotosLoading = true;
    _platformsLoading = true;
    _isItemSold = _currentItem['is_sold'] == 1;
    _refreshAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_currentItem['is_sold'] == 1 ? 'Venduto · ' : '') +
              'Dettaglio articolo',
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Carte: prezzi (valore stimato / prezzo acquisto) e stock attuale
              _buildPriceStockCards(),
              const SizedBox(height: 16),

              // Varianti (se presenti)
              if (_currentItem['has_variants'] == 1) ...[
                _buildVariantsSection(),
                const SizedBox(height: 16),
              ],

              // Drawer del log vendite (collassabile)
              _buildSalesLogDrawer(),
              const SizedBox(height: 16),

              // Galleria foto
              _buildPhotoGallery(),
              const SizedBox(height: 16),

              // Piattaforme collegate
              _buildPlatformsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- FUNZIONI DI CARICAMENTO DATI (Invariate) ---
  Future<void> _refreshAllData() async {
    if (mounted) {
      setState(() {
        _isVariantsLoading = true;
        _isLogLoading = true;
        _isPhotosLoading = true;
        _platformsLoading = true;
      });
    }
    await _fetchItemDetails();
    if (_currentItem['has_variants'] == 1) {
      await _fetchVariants();
    } else {
      if (mounted) setState(() => _isVariantsLoading = false);
    }
    await Future.wait([_fetchSalesLog(), _fetchPhotos(), _fetchPlatforms()]);
  }

  Future<void> _fetchItemDetails() async {
    try {
      final url =
          'http://trentin-nas.synology.me:4000/api/items/${_currentItem['item_id']}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _currentItem = jsonDecode(response.body);
          _isItemSold = _currentItem['is_sold'] == 1;
        });
      }
    } catch (e) {
      print('Errore ricaricando item details: $e');
    }
  }

  Future<void> _fetchVariants() async {
    if (!mounted) return;
    try {
      final itemId = _currentItem['item_id'];
      final url =
          'http://trentin-nas.synology.me:4000/api/items/$itemId/variants';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _variants = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted)
        setState(() {
          _isVariantsLoading = false;
        });
    }
  }

  Future<void> _fetchSalesLog() async {
    /* ... codice invariato ... */
    if (!mounted) return;
    try {
      final itemId = _currentItem['item_id'];
      final url = 'http://trentin-nas.synology.me:4000/api/items/$itemId/sales';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _salesLog = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted)
        setState(() {
          _isLogLoading = false;
        });
    }
  }

  Future<void> _fetchPhotos() async {
    /* ... codice invariato ... */
    if (!mounted) return;
    try {
      final itemId = _currentItem['item_id'];
      final url =
          'http://trentin-nas.synology.me:4000/api/items/$itemId/photos';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _photos = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted)
        setState(() {
          _isPhotosLoading = false;
        });
    }
  }

  Future<void> _fetchPlatforms() async {
    /* ... codice invariato ... */
    if (!mounted) return;
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/platforms';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _allPlatforms = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print('Errore caricamento piattaforme: $e');
    } finally {
      if (mounted)
        setState(() {
          _platformsLoading = false;
        });
    }
  }

  // --- FUNZIONI DI AZIONE (Invariate) ---
  Future<void> _pickAndUploadImage() async {
    /* ... codice invariato ... */
    final dynamic photoTarget = await _showPhotoTargetDialog();
    if (photoTarget == 'cancel') return;
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;
    setState(() {
      _isUploading = true;
    });
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/photos/upload';
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['item_id'] = _currentItem['item_id'].toString();
      if (photoTarget != null) {
        request.fields['variant_id'] = photoTarget.toString();
      }
      request.files.add(
        await http.MultipartFile.fromPath('photo', pickedFile.path),
      );
      var streamedResponse = await request.send();
      if (streamedResponse.statusCode == 201) {
        _dataDidChange = true;
        _fetchPhotos();
      } else {
        final response = await http.Response.fromStream(streamedResponse);
        print('Errore upload: ${response.body}');
      }
    } catch (e) {
      print('Errore (catch) durante l\'upload: $e');
    } finally {
      if (mounted)
        setState(() {
          _isUploading = false;
        });
    }
  }

  Future<dynamic> _showPhotoTargetDialog() {
    /* ... codice invariato ... */
    dynamic selectedTarget = null;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Lega foto a:'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<dynamic>(
                      title: const Text('Articolo Principale'),
                      value: null,
                      groupValue: selectedTarget,
                      onChanged:
                          (value) => dialogSetState(() {
                            selectedTarget = value;
                          }),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    const Divider(),
                    ..._variants.map((variant) {
                      return RadioListTile<dynamic>(
                        title: Text(variant['variant_name'] ?? 'Variante'),
                        value: variant['variant_id'],
                        groupValue: selectedTarget,
                        onChanged:
                            (value) => dialogSetState(() {
                              selectedTarget = value;
                            }),
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedTarget),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codice copiato negli appunti!')),
    );
  }

  int _calculateTotalStock() {
    if (_currentItem['has_variants'] == 1) {
      return _variants.fold<int>(0, (int sum, variant) {
        if (variant['is_sold'] == 0) {
          return sum + ((variant['quantity'] as num?)?.toInt() ?? 0);
        }
        return sum;
      });
    } else {
      return (_currentItem['quantity'] as num?)?.toInt() ?? 0;
    }
  }

  // (3 - WIDGET CORRETTO: Funzione per i dettagli)
  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _headerTextColor, // Colore del testo header
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'Non specificato',
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(height: 1), // Aggiungi un divisore
        ],
      ),
    );
  }

  Widget _buildVariantPlatformsList(List<dynamic> platforms) {
    if (platforms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          platforms.map((p) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                p.toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }).toList(),
    );
  }

  // (4 - WIDGET PER L'HIGHLIGHT DI STOCK E PREZZO)
  Widget _buildPriceStockCards() {
    final int totalStock = _calculateTotalStock();
    final String purchasePrice = '€ ${_currentItem['purchase_price'] ?? 'N/D'}';
    final String salePrice = '€ ${_currentItem['sale_price'] ?? 'N/D'}';
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
      child: Column(
        children: [
          // Valore Stimato e Prezzo Acquisto sulla stessa riga
          Row(
            children: [
              // Valore Stimato
              Expanded(
                child: Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VALORE STIMATO',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: _headerTextColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '€ ${_currentItem['value'] ?? 'N/D'}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Prezzo Acquisto
              Expanded(
                child: Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREZZO ACQUISTO',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: _headerTextColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          purchasePrice,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stock & Prezzo Vendita (due blocchi grandi)
          Row(
            children: [
              // Stock
              Expanded(
                child: Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEZZI DISP.',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: _headerTextColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalStock.toString(),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color:
                                totalStock > 0 ? _availableColor : _soldColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Prezzo Vendita
              Expanded(
                child: Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREZZO VENDITA',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: _headerTextColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          salePrice,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // (6 - NUOVO WIDGET) Logica del Drawer Vendite
  Widget _buildSalesLogDrawer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOG VENDITE',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
        ),
        const SizedBox(height: 8),
        // Testa del Drawer
        Card(
          child: InkWell(
            onTap: () {
              setState(() {
                _isSalesLogOpen = !_isSalesLogOpen; // Inverti lo stato
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSalesLogOpen
                        ? 'Chiudi Storico'
                        : 'Apri Storico Vendite (${_salesLog.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  // Icona dinamica con rotazione (usa AnimatedRotation)
                  AnimatedRotation(
                    turns: _isSalesLogOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Iconsax.arrow_down_1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Corpo del Drawer
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            height: _isSalesLogOpen ? null : 0, // Altezza dinamica
            child: Visibility(
              visible: _isSalesLogOpen,
              child: _buildSalesLogSection(),
            ),
          ),
        ),
      ],
    );
  }

  // (7 - WIDGET AGGIORNATO) Corpo del Log Vendite
  Widget _buildSalesLogSection() {
    if (_isLogLoading)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    if (_salesLog.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna vendita registrata.'),
        ),
      );

    return Column(
      children:
          _salesLog.map((sale) {
            // Logica del Titolo (solo Variante / Piattaforma)
            String title = sale['platform_name'] ?? 'N/D';
            if (sale['variant_name'] != null) {
              title = '${sale['variant_name']} / $title';
            }

            String date =
                sale['sale_date']?.split('T')[0] ?? 'Data sconosciuta';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: Icon(Iconsax.coin, color: _availableColor),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Data: $date | Q.tà: ${sale['quantity_sold']} | Totale: € ${sale['total_price']}',
                ),
                trailing: Icon(
                  Iconsax.edit,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () async {
                  int? currentStock;
                  final int? saleVariantId =
                      (sale['variant_id'] as num?)?.toInt();

                  if (saleVariantId != null) {
                    final matchingVariant = _variants.firstWhere(
                      (v) =>
                          (v['variant_id'] as num?)?.toInt() == saleVariantId,
                      orElse: () => null,
                    );
                    if (matchingVariant != null) {
                      currentStock =
                          (matchingVariant['quantity'] as num?)?.toInt();
                    }
                  } else {
                    if (_currentItem['has_variants'] == 0) {
                      currentStock =
                          (_currentItem['quantity'] as num?)?.toInt();
                    } else {
                      currentStock = null;
                    }
                  }

                  if (currentStock == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Errore: Stock non trovato (articolo/variante inesistente?).',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final bool? dataChanged = await showDialog(
                    context: context,
                    builder:
                        (context) => EditSaleDialog(
                          sale: sale,
                          allPlatforms: _allPlatforms,
                          currentStock: currentStock!,
                        ),
                  );
                  if (dataChanged == true) {
                    _dataDidChange = true;
                    _refreshAllData();
                  }
                },
              ),
            );
          }).toList(),
    );
  }

  // (10 - WIDGETS INVARIATI)
  Widget _buildPlatformsSection() {
    /* ... codice invariato ... */
    final Color accentColor = Theme.of(context).colorScheme.primary;
    final List<dynamic> selectedIds = _currentItem['platforms'] ?? [];
    if (selectedIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Nessuna piattaforma selezionata.'),
        ),
      );
    }
    final List<String> platformNames =
        _allPlatforms
            .where((platform) => selectedIds.contains(platform['platform_id']))
            .map((platform) => platform['name'].toString())
            .toList();
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children:
          platformNames
              .map(
                (name) => Chip(
                  label: Text(name),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: accentColor.withOpacity(0.1),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
              .toList(),
    );
  }

  Widget _buildPhotoGallery() {
    /* ... codice invariato ... */
    final Color accentColor = Theme.of(context).colorScheme.primary;
    if (_isPhotosLoading)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    if (_photos.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna foto trovata.'),
        ),
      );
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final photo = _photos[index];
          final photoUrl =
              'http://trentin-nas.synology.me:4000/${photo['file_path']}';
          String targetName = 'Articolo Principale';
          if (photo['variant_id'] != null) {
            final matchingVariant = _variants.firstWhere(
              (v) =>
                  (v['variant_id'] as num?)?.toInt() ==
                  (photo['variant_id'] as num?)?.toInt(),
              orElse: () => null,
            );
            if (matchingVariant != null) {
              targetName = matchingVariant['variant_name'] ?? 'Variante';
            } else {
              targetName = 'Variante';
            }
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1,
                child: InkWell(
                  onTap: () async {
                    final bool? photoDeleted = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder:
                            (context) => PhotoViewerPage(
                              photoId: photo['photo_id'],
                              photoUrl: photoUrl,
                            ),
                      ),
                    );
                    if (photoDeleted == true) {
                      _dataDidChange = true;
                      _fetchPhotos();
                    }
                  },
                  child: GridTile(
                    footer: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      color: Colors.black.withOpacity(0.6),
                      child: Text(
                        targetName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVariantsSection() {
    final Color _soldColor = Colors.red[500]!;
    final Color _availableColor = Colors.green[500]!;

    if (_isVariantsLoading)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    if (_variants.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna variante trovata.'),
        ),
      );

    return Column(
      children:
          _variants.map((variant) {
            final bool isVariantSold = variant['is_sold'] == 1;
            final Color statusColor =
                isVariantSold ? _soldColor : _availableColor;

            return Card(
              color:
                  isVariantSold
                      ? _soldColor.withOpacity(0.2)
                      : Theme.of(context).cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(
                  variant['variant_name'] ?? 'Senza nome',
                  style: TextStyle(
                    color: isVariantSold ? _soldColor : Colors.white,
                    decoration:
                        isVariantSold ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pezzi: ${(variant['quantity'] as num?)?.toInt() ?? 0} | Prezzo Acq: € ${variant['purchase_price']}',
                      style: TextStyle(
                        color: isVariantSold ? Colors.grey[400] : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildVariantPlatformsList(variant['platforms'] ?? []),
                  ],
                ),
                trailing: Icon(Iconsax.arrow_right_3, color: statusColor),
                onTap: () async {
                  final bool? dataChanged = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddVariantPage(
                            itemId: _currentItem['item_id'],
                            variantId: variant['variant_id'],
                          ),
                    ),
                  );
                  if (dataChanged == true) {
                    _dataDidChange = true;
                    _refreshAllData();
                  }
                },
              ),
            );
          }).toList(),
    );
  }
}
