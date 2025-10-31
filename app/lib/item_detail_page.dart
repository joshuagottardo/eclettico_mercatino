// lib/item_detail_page.dart - AGGIORNATO PER PASSARE STOCK AL DIALOG

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

  // --- FUNZIONI DI CARICAMENTO DATI (TUTTE INVARIATE) ---

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
    /* ... codice invariato ... */
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

  // --- FUNZIONI DI AZIONE (INVARIATE) ---
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
    /* ... codice invariato ... */
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codice copiato negli appunti!')),
    );
  }

  // --- FUNZIONE PRINCIPALE BUILD ---
  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    final bool isPageLoading =
        _isVariantsLoading ||
        _isLogLoading ||
        _isPhotosLoading ||
        _platformsLoading;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataDidChange);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, _dataDidChange);
            },
          ),
          title: Text(item['name'] ?? 'Dettaglio Articolo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifica Articolo',
              onPressed: () async {
                final bool? itemChanged = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddItemPage(itemId: item['item_id']),
                  ),
                );
                if (itemChanged == true) {
                  _dataDidChange = true;
                  _refreshAllData();
                }
              },
            ),
            // (1 - MODIFICA) Bottone VENDI
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor:
                    _isItemSold
                        ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5)
                        : Theme.of(context).colorScheme.primary,
              ),
              icon: Icon(
                Icons.sell_outlined,
                color:
                    _isItemSold
                        ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5)
                        : Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'VENDI',
                style: TextStyle(
                  color:
                      _isItemSold
                          ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5)
                          : Theme.of(context).colorScheme.primary,
                ),
              ),
              onPressed:
                  _isItemSold
                      ? null
                      : () async {
                        final bool? saleRegistered = await showDialog(
                          context: context,
                          builder: (context) {
                            return SellItemDialog(
                              itemId: item['item_id'],
                              hasVariants: item['has_variants'] == 1,
                              variants: _variants,
                              // (2 - NUOVO) Passiamo lo stock dell'articolo singolo
                              itemQuantity: item['quantity'],
                            );
                          },
                        );
                        if (saleRegistered == true) {
                          _dataDidChange = true;
                          // (3 - MODIFICA) Ricarica tutto per aggiornare
                          // lo stock E lo stato is_sold
                          _refreshAllData();
                        }
                      },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body:
            isPageLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // ... (Banner VENDUTO e Sezioni Info... invariate) ...
                    if (_isItemSold)
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.money_off,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ARTICOLO VENDUTO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          onPressed:
                              () => _copyToClipboard(item['unique_code'] ?? ''),
                          tooltip: 'Copia codice',
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow('Categoria', item['category_name']),
                    _buildInfoRow('Brand', item['brand']),
                    _buildInfoRow('Descrizione', item['description']),
                    const Divider(height: 32),
                    _buildInfoRow(
                      'Valore Estimato',
                      '€ ${item['value'] ?? 'N/D'}',
                    ),
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
                              final bool? dataChanged = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddVariantPage(
                                        itemId: item['item_id'],
                                      ),
                                ),
                              );
                              if (dataChanged == true) {
                                _dataDidChange = true;
                                _refreshAllData();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildVariantsSection(),
                    ] else ...[
                      const Divider(height: 32),
                      // (4 - MODIFICA) Mostra lo stock reale
                      _buildInfoRow(
                        'Pezzi Disponibili',
                        '${item['quantity'] ?? '0'}',
                      ),
                      _buildInfoRow(
                        'Prezzo di Acquisto',
                        '€ ${item['purchase_price'] ?? 'N/D'}',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PIATTAFORME DI PUBBLICAZIONE',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPlatformsSection(),
                    ],

                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GALLERIA FOTO',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                        TextButton.icon(
                          icon:
                              _isUploading
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 16,
                                  ),
                          label: const Text('Aggiungi'),
                          onPressed: _isUploading ? null : _pickAndUploadImage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoGallery(),

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
                    _buildSalesLogSection(),
                  ],
                ),
      ),
    );
  }

  // --- WIDGET HELPER (INVARIATI) ---

  Widget _buildPlatformsSection() {
    /* ... codice invariato ... */
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
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide.none,
                ),
              )
              .toList(),
    );
  }

  Widget _buildPhotoGallery() {
    /* ... codice invariato ... */
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
              (v) => v['variant_id'] == photo['variant_id'],
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder:
                            (context) => PhotoViewerPage(photoUrl: photoUrl),
                      ),
                    );
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
    /* ... codice invariato ... */
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
            return Card(
              color:
                  isVariantSold
                      ? const Color(0xFF422B2B)
                      : Theme.of(context).cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(
                  variant['variant_name'] ?? 'Senza nome',
                  style: TextStyle(
                    color: isVariantSold ? Colors.grey[300] : null,
                    decoration:
                        isVariantSold ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  'Pezzi: ${variant['quantity']} | Prezzo Acq: € ${variant['purchase_price']}',
                  style: TextStyle(
                    color: isVariantSold ? Colors.grey[400] : null,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
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

  Widget _buildSalesLogSection() {
    /* ... codice invariato ... */
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
            String title = 'Venduto su ${sale['platform_name'] ?? 'N/D'}';
            if (sale['variant_name'] != null)
              title += ' (${sale['variant_name']})';
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
                trailing: const Icon(Icons.edit_note_outlined, size: 20),
                onTap: () async {
                  final bool? dataChanged = await showDialog(
                    context: context,
                    builder:
                        (context) => EditSaleDialog(
                          sale: sale,
                          allPlatforms: _allPlatforms,
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

  Widget _buildInfoRow(String label, String? value) {
    /* ... codice invariato ... */
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
