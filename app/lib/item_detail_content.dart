// lib/item_detail_content.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/add_variant_page.dart';
import 'package:eclettico/sell_item_dialog.dart';
import 'package:eclettico/photo_viewer_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eclettico/add_item_page.dart';
import 'package:eclettico/icon_helper.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/api_config.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:image/image.dart' as img;
import 'package:barcode_image/barcode_image.dart' as bci;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:eclettico/sales_log_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eclettico/snackbar_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ItemDetailContent extends StatefulWidget {
  final Map<String, dynamic> item;
  final ValueChanged<bool>? onDataChanged;
  final bool showAppBar;
  const ItemDetailContent({
    super.key,
    required this.item,
    this.onDataChanged,
    this.showAppBar = true,
  });

  @override
  State<ItemDetailContent> createState() => _ItemDetailContentState();
}

class _ItemDetailContentState extends State<ItemDetailContent> {
  void _markChanged() {
    try {
      widget.onDataChanged?.call(true);
    } catch (_) {}
  }

  late Map<String, dynamic> _currentItem;

  List _variants = [];
  bool _isVariantsLoading = false;
  List _salesLog = [];
  bool _isLogLoading = false;
  List _photos = [];
  bool _isPhotosLoading = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  List _allPlatforms = [];
  bool _platformsLoading = true;
  bool _isDeleting = false;

  // Colori
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
    _refreshAllData();
  }

  void _navigateToAddVariant() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              AddVariantPage(itemId: _currentItem['item_id'], variantId: null),
    ).then((dataChanged) {
      if (dataChanged == true) {
        _markChanged();
        _refreshAllData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Dettagli'),
                centerTitle: true,
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Iconsax.more),
                    tooltip: 'Altre opzioni',
                    color: const Color(0xFF1E1E1E),
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),

                    onSelected: (String result) {
                      if (result == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddItemPage(
                                  itemId: _currentItem['item_id'],
                                ),
                          ),
                        ).then((dataChanged) {
                          if (dataChanged == true) {
                            _markChanged();
                            _refreshAllData();
                          }
                        });
                      } else if (result == 'sell') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (context) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: SellItemDialog(
                                  itemId: _currentItem['item_id'],
                                  variants: _variants,
                                  allPlatforms: _allPlatforms,
                                  hasVariants:
                                      _currentItem['has_variants'] == 1,
                                  mainItemQuantity:
                                      (_currentItem['quantity'] as num?)
                                          ?.toInt() ??
                                      0,
                                ),
                              ),
                        ).then((dataChanged) {
                          if (dataChanged == true) {
                            _markChanged();
                            _refreshAllData();
                          }
                        });
                      } else if (result == 'copy_desc') {
                        _copyDescriptionToClipboard();
                      } else if (result == 'barcode') {
                        _saveBarcodeImage();
                      }
                    },

                    // --- MENU AGGIORNATO: Nomi brevi e stile uniforme ---
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            height:
                                40, // Altezza leggermente aumentata per touch
                            child: Row(
                              children: [
                                Icon(Iconsax.edit, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Modifica',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'sell',
                            enabled: _calculateTotalStock() > 0,
                            height: 40,
                            child: Row(
                              children: [
                                Icon(Iconsax.receipt, size: 20),
                                SizedBox(width: 12),
                                Text('Vendi', style: TextStyle(fontSize: 15)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'copy_desc',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(Iconsax.note_text, size: 20),
                                SizedBox(width: 12),
                                Text('Copia', style: TextStyle(fontSize: 15)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'barcode',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(Iconsax.barcode, size: 20),
                                SizedBox(width: 12),
                                Text('Barcode', style: TextStyle(fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: Column(
          children: [
            if (!widget.showAppBar) _buildActionButtonsRow(),

            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _currentItem['name'] ?? 'Senza Nome',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. STOCK & PREZZO
                    _buildStockAndSalePrice(),
                    const SizedBox(height: 24),

                    // 2. DETTAGLI BASE
                    _buildInfoDetailSection(),
                    const SizedBox(height: 16),

                    // 3. VALORE & ACQUISTO
                    _buildPriceAndPurchaseInfo(),
                    const SizedBox(height: 24),

                    // 4. PIATTAFORME (Modificato: niente titolo se vuoto)
                    if (_currentItem['has_variants'] != 1) ...[
                      // Mostra la sezione solo se ci sono piattaforme
                      if ((_currentItem['platforms'] as List?)?.isNotEmpty ==
                          true)
                        Align(
                          // <--- Aggiungi Align per forzare l'allineamento a destra nel layout verticale
                          alignment: Alignment.centerRight,
                          child: _buildPlatformsSection(),
                        ),

                      if ((_currentItem['platforms'] as List?)?.isNotEmpty ==
                          true)
                        const SizedBox(height: 24),
                    ],

                    // 5. VARIANTI
                    if (_currentItem['has_variants'] == 1) ...[
                      Text(
                        'VARIANTI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _headerTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVariantsSection(),
                      const SizedBox(height: 24),
                    ],

                    // 6. GALLERIA FOTO (Modificato: Bottone Download)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment:
                          CrossAxisAlignment.end, // Allinea alla base del testo
                      children: [
                        Text(
                          'GALLERIA FOTO',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: _headerTextColor),
                        ),
                        // Tasto Download
                        InkWell(
                          onTap: _downloadAllPhotos,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.import,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SCARICA TUTTO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoGallery(),
                    const SizedBox(height: 24),

                    // 7. LOG VENDITE (Modificato: Testo semplificato)
                    Card(
                      color: Theme.of(context).cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: Icon(
                          Iconsax.receipt_search,
                          color: Colors.grey[600],
                        ),
                        title:
                            _isLogLoading
                                ? const Text(
                                  'Caricamento...',
                                  style: TextStyle(fontSize: 16),
                                )
                                : Text(
                                  '${_salesLog.length} ${_salesLog.length == 1 ? "vendita" : "vendite"}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        trailing: Icon(Iconsax.arrow_right_3),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SalesLogPage(
                                    salesLog: _salesLog,
                                    allPlatforms: _allPlatforms,
                                    variants: _variants,
                                    item: _currentItem,
                                  ),
                            ),
                          ).then((dataChanged) {
                            if (dataChanged == true) {
                              _markChanged();
                              _refreshAllData();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child:
                          _isDeleting
                              ? const CircularProgressIndicator(
                                color: Colors.red,
                              )
                              : TextButton.icon(
                                onPressed: _deleteItem,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Elimina Articolo',
                                  style: TextStyle(color: Colors.red),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... [I widget _buildAddVariantTile, _buildAddPhotoButton, _buildPhotoTile restano uguali] ...
  Widget _buildAddVariantTile() {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(Iconsax.add_square, color: Colors.grey[600]),
        title: Text(
          'Aggiungi variante',
          style: TextStyle(color: Colors.grey[600]),
        ),
        onTap: _navigateToAddVariant,
      ),
    );
  }

  Widget _buildAddPhotoButton({dynamic targetVariantId}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.grey[850],
        child: AspectRatio(
          aspectRatio: 1,
          child: InkWell(
            onTap:
                _isUploading
                    ? null
                    : () =>
                        _pickAndUploadImage(targetVariantId: targetVariantId),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.add_square, size: 32, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'Aggiungi Foto',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile({
    required Map<String, dynamic> photo,
    required List<Map<String, dynamic>> photoList,
    required int indexInList,
  }) {
    final fullResUrl = '$kBaseUrl/${photo['file_path']}';
    final thumbnailUrl =
        photo['thumbnail_path'] != null
            ? '$kBaseUrl/${photo['thumbnail_path']}'
            : fullResUrl;

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
                        photos: photoList,
                        initialIndex: indexInList,
                      ),
                ),
              );
              if (photoDeleted == true) {
                _fetchPhotos();
                _markChanged();
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final cacheW = (constraints.maxWidth * dpr).round().clamp(
                  256,
                  4096,
                );
                return Hero(
                  tag: fullResUrl,
                  child: Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: cacheW,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.grey);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _capitalizeFirst(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _copyDescriptionToClipboard() async {
    final String name = _capitalizeFirst(_currentItem['name']);
    final String brand = _capitalizeFirst(_currentItem['brand']);
    final String description =
        _currentItem['description'] ?? 'Nessuna descrizione';
    final String condition = (_currentItem['is_used'] == 0) ? 'Nuovo' : 'Usato';
    final String textToCopy =
        '$name | $brand\n$description\nCONDIZIONE: $condition';

    await Clipboard.setData(ClipboardData(text: textToCopy));
    HapticFeedback.mediumImpact();

    if (mounted) {
      showFloatingSnackBar(context, 'Descrizione copiata negli appunti!');
    }
  }

  Future<PermissionStatus> _requestMediaPermission() async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      final status = await Permission.photosAddOnly.request();
      return status;
    }
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status;
  }

  // --- NUOVA FUNZIONE: SCARICA TUTTE LE FOTO ---
  Future<void> _downloadAllPhotos() async {
    if (_photos.isEmpty) {
      _showError('Nessuna foto da scaricare.');
      return;
    }

    final bool isMobile =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    if (isMobile) {
      final status = await _requestMediaPermission();
      if (!status.isGranted && !status.isLimited) {
        _showError('Permesso per salvare nelle Foto non concesso.');
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }
    }

    showFloatingSnackBar(
      context,
      'Inizio download di ${_photos.length} foto...',
      isError: false,
    );

    int successCount = 0;

    try {
      for (var photo in _photos) {
        final url = '$kBaseUrl/${photo['file_path']}';
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final Uint8List bytes = response.bodyBytes;
            final String fileName =
                'item_${_currentItem['item_id']}_${photo['photo_id']}';

            if (isMobile) {
              final result = await ImageGallerySaver.saveImage(
                bytes,
                quality: 100,
                name: fileName,
              );
              if (result['isSuccess'] == true) {
                successCount++;
              }
            } else {
              // Su Desktop, per ora salviamo solo nella cartella Download o Documenti default se non vogliamo aprire un picker per ogni foto.
              // Per semplicità, qui simulo un successo o potrei implementare un salvataggio batch se avessi una cartella.
              // Dato che file_picker salva uno alla volta, questo flusso su desktop richiederebbe un cambio logica (es. zip).
              // Per ora lo limitiamo a mobile o mostriamo avviso.
              print(
                'Download desktop non implementato in batch per: $fileName',
              );
            }
          }
        } catch (e) {
          print('Errore scaricamento singola foto: $e');
        }
      }

      if (mounted && isMobile) {
        showFloatingSnackBar(
          context,
          'Salvate $successCount foto in galleria!',
        );
      } else if (mounted && !isMobile) {
        showFloatingSnackBar(
          context,
          'Funzione ottimizzata per mobile. Implementazione desktop in arrivo.',
        );
      }
    } catch (e) {
      _showError('Errore durante il download: $e');
    }
  }

  Future<void> _saveBarcodeImage() async {
    final String? uniqueCode = _currentItem['unique_code']?.toString();
    if (uniqueCode == null || uniqueCode.isEmpty) {
      _showError('Codice univoco non disponibile.');
      return;
    }

    showFloatingSnackBar(
      context,
      'Salvataggio codice a barre...',
      isError: false,
    );

    try {
      final barcode = bc.Barcode.code128();
      final image = img.Image(width: 400, height: 150);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      bci.drawBarcode(image, barcode, uniqueCode, font: img.arial24);
      final Uint8List pngBytes = Uint8List.fromList(img.encodePng(image));

      final bool isMobile = Theme.of(context).platform == TargetPlatform.iOS;

      if (isMobile) {
        final status = await _requestMediaPermission();
        if (!status.isGranted && !status.isLimited) {
          _showError('Permesso per salvare nelle Foto non concesso.');
          if (status.isPermanentlyDenied) {
            await openAppSettings();
          }
          return;
        }

        final result = await ImageGallerySaver.saveImage(
          pngBytes,
          quality: 100,
          name: 'barcode_$uniqueCode',
        );

        if (result['isSuccess'] == true) {
          showFloatingSnackBar(context, 'Codice a barre salvato in galleria!');
        } else {
          showFloatingSnackBar(
            context,
            'Salvataggio non riuscito.',
            isError: true,
          );
        }
      } else {
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Salva codice a barre',
          fileName: 'barcode_$uniqueCode.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(pngBytes);
          showFloatingSnackBar(context, 'Barcode salvato!');
        } else {
          _showError('Salvataggio annullato.');
        }
      }
    } catch (e) {
      if (e is MissingPluginException) {
        _showError(
          'Questa piattaforma non è supportata per il salvataggio automatico.',
        );
      } else {
        _showError('Errore durante la creazione del barcode: $e');
      }
    }
  }

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

  Future<void> _deleteItem() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Sei sicuro?'),
            content: const Text(
              'Vuoi eliminare definitivamente questo articolo? L\'azione è irreversibile e possibile solo se non ci sono vendite associate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sì, elimina'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final url = '$kBaseUrl/api/items/${_currentItem['item_id']}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          showFloatingSnackBar(context, 'Articolo eliminato con successo.');
          _markChanged();
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        _showError(error['error'] ?? 'Non puoi eliminare questo articolo.');
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      showFloatingSnackBar(context, message, isError: true);
    }
  }

  Future<void> _fetchItemDetails() async {
    try {
      final url = '$kBaseUrl/api/items/${_currentItem['item_id']}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _currentItem = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _fetchVariants() async {
    if (!mounted) return;
    try {
      final itemId = _currentItem['item_id'];
      final url = '$kBaseUrl/api/items/$itemId/variants';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _variants = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) {
        setState(() {
          _isVariantsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSalesLog() async {
    if (!mounted) return;
    try {
      final itemId = _currentItem['item_id'];
      final url = '$kBaseUrl/api/items/$itemId/sales';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _salesLog = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLogLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPhotos() async {
    if (!mounted) return;
    try {
      final itemId = _currentItem['item_id'];
      final url = '$kBaseUrl/api/items/$itemId/photos';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _photos = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) {
        setState(() {
          _isPhotosLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPlatforms() async {
    if (!mounted) return;
    try {
      const url = '$kBaseUrl/api/platforms';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _allPlatforms = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print('Errore caricamento piattaforme: $e');
    } finally {
      if (mounted) {
        setState(() {
          _platformsLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage({dynamic targetVariantId}) async {
    final dynamic photoTarget = targetVariantId;
    final List<XFile> pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      for (final XFile pickedFile in pickedFiles) {
        await _uploadSingleImage(pickedFile, photoTarget);
      }
      _fetchPhotos();
      _markChanged();
      showFloatingSnackBar(
        context,
        'Caricamento di ${pickedFiles.length} foto completato!',
      );
    } catch (e) {
      print('Errore (catch) durante l\'upload multiplo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadSingleImage(XFile pickedFile, dynamic photoTarget) async {
    try {
      const url = '$kBaseUrl/api/photos/upload';
      var request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['item_id'] = _currentItem['item_id'].toString();
      if (photoTarget != null) {
        request.fields['variant_id'] = photoTarget.toString();
      }

      request.files.add(
        await http.MultipartFile.fromPath('photo', pickedFile.path),
      );

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode != 201) {
        final response = await http.Response.fromStream(streamedResponse);
        print('Errore upload di ${pickedFile.name}: ${response.body}');
      }
    } catch (e) {
      print('Errore upload di ${pickedFile.name}: $e');
    }
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

  Widget _buildPhotoGallerySkeleton() {
    final Color baseColor = Colors.grey[850]!;
    final Color highlightColor = Colors.grey[700]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(color: baseColor),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPriceAndPurchaseInfo() {
    final String estimatedValue = '€ ${_currentItem['value'] ?? 'N/D'}';
    final bool hasVariants = _currentItem['has_variants'] == 1;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VALORE STIMATO',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
              ),
              const SizedBox(height: 4),
              Text(
                estimatedValue,
                style: GoogleFonts.inconsolata(
                  textStyle: Theme.of(context).textTheme.titleLarge,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (!hasVariants) ...[
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREZZO ACQUISTO',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  '€ ${_currentItem['purchase_price'] ?? 'N/D'}',
                  style: GoogleFonts.inconsolata(
                    textStyle: Theme.of(context).textTheme.titleLarge,
                    color: Colors.grey[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoDetailSection() {
    final String conditionDisplay =
        (_currentItem['is_used'] == 0) ? 'Nuovo' : 'Usato';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('CONDIZIONE', conditionDisplay, Iconsax.shield_tick),
        _buildInfoRow(
          'CATEGORIA',
          _currentItem['category_name'],
          _currentItem['category_name'] != null
              ? IconHelper.getIconForCategory(_currentItem['category_name'])
              : Iconsax.box_1,
        ),
        _buildInfoRow('BRAND', _currentItem['brand'], Iconsax.tag),
        _buildInfoRow('DESCRIZIONE', _currentItem['description'], Iconsax.text),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 16, color: _headerTextColor),
              if (icon != null) const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: _headerTextColor,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'Non specificato',
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ],
      ),
    );
  }

  Widget _buildStockAndSalePrice() {
    final int totalStock = _calculateTotalStock();
    final String salePrice = '€ ${_currentItem['sale_price'] ?? 'N/D'}';
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PEZZI DISPONIBILI',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      totalStock.toString(),
                      style: GoogleFonts.inconsolata(
                        textStyle: Theme.of(context).textTheme.headlineMedium,
                        color: totalStock > 0 ? _availableColor : _soldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      salePrice,
                      style: GoogleFonts.inconsolata(
                        textStyle: Theme.of(context).textTheme.headlineMedium,
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsRow() {
    return Container(
      color:
          Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Tooltip(
                message: 'Modifica Articolo',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.edit),
                  label: const Text('Modifica'),
                  onPressed: () async {
                    final bool? dataChanged = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AddItemPage(itemId: _currentItem['item_id']),
                      ),
                    );
                    if (dataChanged == true) {
                      _markChanged();
                      _refreshAllData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              Tooltip(
                message: 'Registra Vendita',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.receipt),
                  label: const Text('Vendi'),
                  onPressed:
                      _calculateTotalStock() > 0
                          ? () async {
                            final bool? dataChanged =
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  constraints: const BoxConstraints(
                                    maxWidth: 1920,
                                  ),
                                  builder:
                                      (context) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              MediaQuery.of(
                                                context,
                                              ).viewInsets.bottom,
                                        ),
                                        child: SellItemDialog(
                                          itemId: _currentItem['item_id'],
                                          variants: _variants,
                                          allPlatforms: _allPlatforms,
                                          hasVariants:
                                              _currentItem['has_variants'] == 1,
                                          mainItemQuantity:
                                              (_currentItem['quantity'] as num?)
                                                  ?.toInt() ??
                                              0,
                                        ),
                                      ),
                                );

                            if (dataChanged == true) {
                              _markChanged();
                              _refreshAllData();
                            }
                          }
                          : null,
                ),
              ),
              const SizedBox(width: 8),

              Tooltip(
                message: 'Copia Descrizione',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.note_text),
                  label: const Text('Copia'),
                  onPressed: _copyDescriptionToClipboard,
                ),
              ),
              const SizedBox(width: 8),

              Tooltip(
                message: 'Salva Barcode',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.barcode),
                  label: const Text('Barcode'),
                  onPressed: _saveBarcodeImage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection() {
    final Color soldColor = Colors.red[500]!;
    final Color availableColor = Colors.green[500]!;

    if (_isVariantsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        ..._variants.map((variant) {
          final bool isVariantSold = variant['is_sold'] == 1;
          final Color statusColor = isVariantSold ? soldColor : availableColor;

          return Card(
            color:
                isVariantSold
                    ? soldColor.withAlpha(51)
                    : Theme.of(context).cardColor,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              title: Text(
                variant['variant_name'] ?? 'Senza nome',
                style: TextStyle(
                  color: statusColor,
                  decoration: isVariantSold ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: Text(
                ((variant['quantity'] as num?)?.toInt() ?? 0).toString(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (context) => AddVariantPage(
                        itemId: _currentItem['item_id'],
                        variantId: variant['variant_id'],
                      ),
                ).then((dataChanged) {
                  if (dataChanged == true) {
                    _markChanged();
                    _refreshAllData();
                  }
                });
              },
            ),
          );
        }).toList(),
        _buildAddVariantTile(),
      ],
    );
  }

  Widget _buildPhotoGallery() {
    if (_isPhotosLoading) {
      return _buildPhotoGallerySkeleton();
    }

    final List<Map<String, dynamic>> mainPhotos =
        _photos
            .where((p) => p['variant_id'] == null)
            .cast<Map<String, dynamic>>()
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentItem['has_variants'] != 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mainPhotos.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAddPhotoButton(targetVariantId: null);
                  }
                  final photo = mainPhotos[index - 1];
                  return _buildPhotoTile(
                    photo: photo,
                    photoList: mainPhotos,
                    indexInList: index - 1,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        ..._variants.map((variant) {
          final int variantId = variant['variant_id'];
          final String variantName = variant['variant_name'] ?? 'Variante';

          final List<Map<String, dynamic>> variantPhotos =
              _photos
                  .where((p) => p['variant_id'] == variantId)
                  .cast<Map<String, dynamic>>()
                  .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                variantName,
                style: TextStyle(
                  color: _headerTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: variantPhotos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildAddPhotoButton(targetVariantId: variantId);
                      }
                      final photo = variantPhotos[index - 1];
                      return _buildPhotoTile(
                        photo: photo,
                        photoList: variantPhotos,
                        indexInList: index - 1,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }).toList(),

        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 8),
                Text('Caricamento foto...'),
              ],
            ),
          ),
      ],
    );
  }

  // MODIFICATO: Usa le icone invece dei chip testuali
  Widget _buildPlatformsSection() {
    final List<dynamic> selectedIds = _currentItem['platforms'] ?? [];

    // Se vuoto, nascondi completamente
    if (selectedIds.isEmpty) {
      return const SizedBox.shrink();
    }

    // Costruiamo la lista delle icone basata sugli ID selezionati
    // Nota: Non serve nemmeno aspettare _allPlatforms se usiamo IconHelper che lavora sugli ID
    // Ma è buona norma verificare che l'ID esista se vuoi essere rigoroso.
    // Per semplicità e velocità, usiamo direttamente gli ID salvati nell'item.

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.end, // Allinea titolo e icone a destra
      children: [
        Wrap(
          spacing: 12.0, // Spazio tra le icone
          runSpacing: 8.0,
          alignment:
              WrapAlignment.end, // Allinea il contenuto del Wrap a destra
          children:
              selectedIds.map((platformId) {
                final String iconAsset = IconHelper.getPlatformIconPath(
                  platformId,
                );

                // Se l'icona non esiste (stringa vuota), saltiamo
                if (iconAsset.isEmpty) return const SizedBox.shrink();

                return Tooltip(
                  message:
                      'ID Piattaforma: $platformId', // O cerca il nome se preferisci
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    // Usa SvgPicture.asset se hai convertito in SVG, altrimenti Image.asset
                    child: SvgPicture.asset(
                      iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback se l'asset non si trova
                        return Icon(
                          Iconsax.global,
                          size: 24,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}
