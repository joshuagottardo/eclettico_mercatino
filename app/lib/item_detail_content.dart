// lib/item_detail_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/add_variant_page.dart';
import 'package:eclettico/sell_item_dialog.dart';
import 'package:eclettico/photo_viewer_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eclettico/add_item_page.dart';
import 'package:eclettico/edit_sale_dialog.dart';
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
    // Notifica solo il wrapper, non serve un flag locale
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
  bool _isSalesLogOpen = false; // Stato per il Drawer Log
  bool _isDeleting = false;

  // Colori
  final Color _soldColor = Colors.red[500]!;
  final Color _availableColor = Colors.green[500]!;
  final Color _headerTextColor = Colors.grey[600]!;

  // Colore per il card del Log Vendite
  final Color _logDrawerColor = const Color(0xFF161616);

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
    final bool? dataChanged = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddVariantPage(
              itemId: _currentItem['item_id'],
              variantId:
                  null, // Passiamo null per indicare la creazione di una nuova variante
            ),
      ),
    );
    if (dataChanged == true) {
      _markChanged();
      _refreshAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text(_currentItem['name'] ?? 'Dettagli'),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Iconsax.more), // Icona tre puntini
                    onSelected: (String result) {
                      // Gestiamo l'azione in base al valore
                      if (result == 'edit') {
                        // Logica "Modifica"
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
                        // Logica "Vendi"
                        showDialog(
                          context: context,
                          builder:
                              (context) => SellItemDialog(
                                itemId: _currentItem['item_id'],
                                variants: _variants,
                                allPlatforms: _allPlatforms,
                                hasVariants: _currentItem['has_variants'] == 1,
                                mainItemQuantity:
                                    (_currentItem['quantity'] as num?)
                                        ?.toInt() ??
                                    0,
                              ),
                        ).then((dataChanged) {
                          if (dataChanged == true) {
                            _markChanged();
                            _refreshAllData();
                          }
                        });
                      } else if (result == 'copy_desc') {
                        // NUOVA Logica "Copia"
                        _copyDescriptionToClipboard();
                      } else if (result == 'barcode') {
                        _saveBarcodeImage();
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          // 1. Modifica Articolo
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Iconsax.edit),
                              title: Text('Modifica Articolo'),
                            ),
                          ),
                          // 2. Registra Vendita
                          PopupMenuItem<String>(
                            value: 'sell',
                            enabled: _calculateTotalStock() > 0,
                            child: const ListTile(
                              leading: Icon(Iconsax.receipt),
                              title: Text('Registra Vendita'),
                            ),
                          ),
                          // 3. Copia Descrizione (NUOVO)
                          const PopupMenuItem<String>(
                            value: 'copy_desc',
                            child: ListTile(
                              leading: Icon(Iconsax.note_text),
                              title: Text('Copia Descrizione'),
                            ),
                          ),
                          // 4. Salva Barcode
                          const PopupMenuItem<String>(
                            value: 'barcode',
                            child: ListTile(
                              leading: Icon(Iconsax.barcode),
                              title: Text('Salva Barcode'),
                            ),
                          ),
                        ],
                  ),
                ],
                // --- FINE MODIFICA ---
              )
              : null,
      // ...
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        //  Avvolgiamo in una Column per aggiungere i bottoni su tablet
        child: Column(
          children: [
            //  Mostra la barra azioni solo se l'AppBar è nascosta
            if (!widget.showAppBar) _buildActionButtonsRow(),

            //  Expanded assicura che lo scroll riempia lo spazio rimanente
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16), // Il padding rimane qui
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. PEZZI DISPONIBILI e PREZZO VENDITA (In cima) ---
                    _buildStockAndSalePrice(),
                    const SizedBox(height: 24),

                    // --- 2. DETTAGLI BASE (Categoria, Brand, Descrizione) ---
                    _buildInfoDetailSection(),
                    const SizedBox(height: 16),

                    // --- 3. VALORE STIMATO e PREZZO ACQUISTO (Affiancati) ---
                    _buildPriceAndPurchaseInfo(),
                    const SizedBox(height: 24),

                    // --- 4. PIATTAFORME COLLEGATE (Solo se non ha varianti) ---
                    if (_currentItem['has_variants'] != 1) ...[
                      // Mostra il titolo solo se ci sono piattaforme da mostrare
                      if (_allPlatforms.isNotEmpty && !_platformsLoading)
                        Text(
                          'PIATTAFORME',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: _headerTextColor),
                        ),

                      // Mostra le piattaforme
                      if (_allPlatforms.isNotEmpty && !_platformsLoading)
                        _buildPlatformsSection(),

                      const SizedBox(height: 24),
                    ],

                    // --- 5. VARIANTI (se presenti) ---
                    if (_currentItem['has_variants'] == 1) ...[
                      Text(
                        'VARIANTI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _headerTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVariantsSection(),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.center,
                        child: ElevatedButton.icon(
                          onPressed: _navigateToAddVariant,
                          icon: const Icon(
                            Iconsax.add_square,
                            color: Colors.black, // <-- IMPOSTA IL COLORE QUI
                          ),
                          label: const Text('Aggiungi variante'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.grey[300], // Bianco "sporco"
                            foregroundColor: Colors.black, // Icona e testo neri
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- 6. GALLERIA FOTO ---
                    Text(
                      'GALLERIA FOTO',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoGallery(),
                    const SizedBox(height: 24),

                    // --- 7. LOG VENDITE (Grigio scuro) ---
                    _buildSalesLogDrawer(),
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

  // --- NUOVO WIDGET: Il bottone "+" per aggiungere foto ---
  Widget _buildAddPhotoButton({dynamic targetVariantId}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        // Un colore leggermente diverso per far capire che è un bottone
        color: Colors.grey[850],
        child: AspectRatio(
          aspectRatio: 1,
          child: InkWell(
            // Disabilita il tap se stiamo già caricando
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

  // --- NUOVO WIDGET: La singola foto nella galleria ---
  Widget _buildPhotoTile({required Map<String, dynamic> photo}) {
    // Logica per trovare l'URL (presa dalla vecchia funzione)
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
              // Trova l'indice di questa foto nella lista _photos GLOBALE
              final int globalIndex = _photos.indexWhere(
                (p) => p['photo_id'] == photo['photo_id'],
              );

              if (globalIndex == -1) {
                _showError("Errore: foto non trovata.");
                return;
              }

              // Apri il visualizzatore
              final bool? photoDeleted = await Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder:
                      (context) => PhotoViewerPage(
                        photos: _photos.cast<Map<String, dynamic>>(),
                        initialIndex: globalIndex, // Passa l'indice globale
                      ),
                ),
              );
              if (photoDeleted == true) {
                _fetchPhotos();
              }
            },
            // Logica per mostrare l'immagine (presa dalla vecchia funzione)
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final cacheW = (constraints.maxWidth * dpr).round().clamp(
                  256,
                  4096,
                );

                return Image.network(
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- NUOVA FUNZIONE PER COPIARE LA DESCRIZIONE ---
  Future<void> _copyDescriptionToClipboard() async {
    final String name = _currentItem['name'] ?? 'Senza nome';
    final String brand = _currentItem['brand'] ?? 'N/D';
    final String description =
        _currentItem['description'] ?? 'Nessuna descrizione';
    final String condition = (_currentItem['is_used'] == 0) ? 'Nuovo' : 'Usato';

    // Formatta il testo come richiesto
    final String textToCopy = '$name | $brand\n- $description\n- $condition';

    await Clipboard.setData(ClipboardData(text: textToCopy));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descrizione copiata negli appunti!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<PermissionStatus> _requestMediaPermission() async {
    // iOS: usa add-only per salvare in Libreria senza leggere
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      final status = await Permission.photosAddOnly.request();
      return status;
    }

    // Android: prova prima "photos" (API 33+), fallback a "storage"
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status;
  }

  // --- FUNZIONE PER SALVARE IL BARCODE (AGGIORNATA PER DESKTOP) ---
  Future<void> _saveBarcodeImage() async {
    final String? uniqueCode = _currentItem['unique_code']?.toString();
    if (uniqueCode == null || uniqueCode.isEmpty) {
      _showError('Codice univoco non disponibile.');
      return;
    }

    // Mostra feedback di avvio
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salvataggio codice a barre...')),
    );

    try {
      // --- LOGICA DI GENERAZIONE IMMAGINE (invariata) ---
      final barcode = bc.Barcode.code128();
      final image = img.Image(width: 400, height: 150);
      img.fill(image, color: img.ColorRgb8(255, 255, 255)); // Sfondo bianco
      bci.drawBarcode(image, barcode, uniqueCode, font: img.arial24);
      final Uint8List pngBytes = Uint8List.fromList(img.encodePng(image));
      // --- FINE GENERAZIONE ---

      // --- LOGICA DI SALVATAGGIO (DIVERSA PER PIATTAFORMA) ---
      final bool isMobile = Theme.of(context).platform == TargetPlatform.iOS;

      if (isMobile) {
        // --- SALVATAGGIO SU MOBILE (iOS / Android) ---

        // 1. Chiedi i permessi
        final status = await _requestMediaPermission();
        if (!status.isGranted && !status.isLimited) {
          _showError('Permesso per salvare nelle Foto non concesso.');
          if (status.isPermanentlyDenied) {
            await openAppSettings();
          }
          return;
        }

        // 2. Salva in galleria
        final result = await ImageGallerySaver.saveImage(
          pngBytes,
          quality: 100,
          name: 'barcode_$uniqueCode',
        );

        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Codice a barre salvato in galleria!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showError('Salvataggio non riuscito.');
        }
      } else {
        // --- SALVATAGGIO SU DESKTOP (Windows / macOS / Linux) ---

        // 1. Apri il dialog "Salva con nome..."
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Salva codice a barre',
          fileName: 'barcode_$uniqueCode.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        // 2. Se l'utente ha scelto un percorso e premuto "Salva"
        if (outputFile != null) {
          // 3. Scrivi i bytes del PNG nel file
          final file = File(outputFile);
          await file.writeAsBytes(pngBytes);

          // 4. Mostra feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Codice a barre salvato!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // L'utente ha premuto "Annulla"
          _showError('Salvataggio annullato.');
        }
      }
    } catch (e) {
      // L'errore che ricevevi prima ora è gestito
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

  // Funzione per gestire l'eliminazione dell'articolo
  Future<void> _deleteItem() async {
    // 1. Chiedi conferma
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Articolo eliminato con successo.'),
              backgroundColor: Colors.green,
            ),
          );
          _markChanged();
          // Torna alla pagina precedente (Home/Search) e segnala il cambiamento (true)
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 400) {
        // Errore gestito (es. ha vendite)
        final error = jsonDecode(response.body);
        _showError(error['error'] ?? 'Non puoi eliminare questo articolo.');
      } else {
        // Errore server
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

  // Funzione helper per mostrare errori
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
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

  // --- FUNZIONI DI AZIONE ---

  // --- MODIFICATA: Ora accetta un 'targetVariantId' ---
  Future<void> _pickAndUploadImage({dynamic targetVariantId}) async {
    // Rimosso: _showPhotoTargetDialog()
    final dynamic photoTarget = targetVariantId;

    //  Usa pickMultiImage per selezionare più file
    final List<XFile> pickedFiles = await _picker.pickMultiImage();

    // Controlla se almeno un file è stato selezionato
    if (pickedFiles.isEmpty) return;

    // Avvia l'indicatore di caricamento
    setState(() {
      _isUploading = true;
    });

    try {
      // Itera su ogni file selezionato per l'upload
      for (final XFile pickedFile in pickedFiles) {
        // Passa il targetVariantId alla funzione di upload
        await _uploadSingleImage(pickedFile, photoTarget);
      }

      // Se almeno un upload ha avuto successo, ricarica la galleria
      _fetchPhotos();
      _markChanged();

      // Mostra un feedback di successo per il blocco di file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caricamento di ${pickedFiles.length} foto completato!',
          ),
        ),
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

  // Gestisce l'upload di un singolo file
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

  // Nuovo widget per lo skeleton della galleria
  Widget _buildPhotoGallerySkeleton() {
    final Color baseColor = Colors.grey[850]!;
    final Color highlightColor = Colors.grey[700]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: SizedBox(
        height: 140, // Altezza fissa della galleria
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4, // Mostra 4 box finti
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(color: baseColor), // Box pieno
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPriceAndPurchaseInfo() {
    // String purchasePrice = '€ ${_currentItem['purchase_price'] ?? 'N/D'}'; // Non più usato qui
    final String estimatedValue = '€ ${_currentItem['value'] ?? 'N/D'}';
    final bool hasVariants = _currentItem['has_variants'] == 1; // Controllo

    return Row(
      children: [
        // Valore Stimato (Sempre visibile)
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // --- INIZIO MODIFICA ---
        // Mostra il Prezzo Acquisto SOLO SE l'articolo NON ha varianti
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
                  '€ ${_currentItem['purchase_price'] ?? 'N/D'}', // Calcolato qui
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        // --- FINE MODIFICA ---
      ],
    );
  }

  Widget _buildInfoDetailSection() {
    final String conditionDisplay =
        (_currentItem['is_used'] == 0) ? 'Nuovo' : 'Usato';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          'CONDIZIONE',
          conditionDisplay, // <-- Usa la stringa determinata
          Iconsax.shield_tick,
        ),
        _buildInfoRow(
          'CATEGORIA',
          _currentItem['category_name'],
          _currentItem['category_name'] != null
              ? getIconForCategory(_currentItem['category_name'])
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
        // Stock (Pezzi Disponibili)
        Expanded(
          child: Card(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PEZZI DISPONIBILI', // Titolo intero
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                  ),
                  const SizedBox(height: 8),

                  // --- INIZIO MODIFICA ---
                  // Aggiunto FittedBox per ridimensionare il testo se necessario
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      totalStock.toString(),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color: totalStock > 0 ? _availableColor : _soldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                    ),
                  ),
                  // --- FINE MODIFICA ---
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
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                  ),
                  const SizedBox(height: 8),

                  // --- INIZIO MODIFICA ---
                  // Aggiunto FittedBox per ridimensionare il testo se necessario
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      salePrice,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                    ),
                  ),
                  // --- FINE MODIFICA ---
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

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
          color: _logDrawerColor,
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
                  // Icona dinamica con rotazione
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
            color: _logDrawerColor,
            child: Visibility(
              visible: _isSalesLogOpen,
              child: _buildSalesLogSection(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesLogSection() {
    if (_isLogLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_salesLog.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Nessuna vendita registrata.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      children:
          _salesLog.map((sale) {
            String title = sale['platform_name'] ?? 'N/D';
            if (sale['variant_name'] != null) {
              title = '${sale['variant_name']} / $title';
            }

            String date =
                sale['sale_date']?.split('T')[0] ?? 'Data sconosciuta';

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
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
                        (context) => ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: EditSaleDialog(
                            sale: sale,
                            allPlatforms: _allPlatforms,
                            currentStock: currentStock!,
                          ),
                        ),
                  );
                  if (dataChanged == true) {
                    _markChanged();
                    _refreshAllData();
                  }
                },
              ),
            );
          }).toList(),
    );
  }

  // --- MODIFICATA: Widget helper per mostrare i bottoni su tablet/desktop ---
  Widget _buildActionButtonsRow() {
    // Usiamo un colore di sfondo simile all'AppBar per coerenza
    return Container(
      color:
          Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Titolo a sx, bottoni a dx
        children: [
          // Titolo a sinistra
          Expanded(
            child: Text(
              _currentItem['name'] ?? 'Dettagli',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          // Bottoni con testo (TextButton.icon)
          Row(
            children: [
              // 1. Modifica Articolo
              Tooltip(
                // <-- INIZIO FIX
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
              ), // <-- FINE FIX
              const SizedBox(width: 8),

              // 2. Vendi Articolo
              Tooltip(
                // <-- INIZIO FIX
                message: 'Registra Vendita',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.receipt),
                  label: const Text('Vendi'),
                  onPressed:
                      _calculateTotalStock() > 0
                          ? () async {
                            final bool? dataChanged = await showDialog(
                              context: context,
                              builder:
                                  (context) => ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 600,
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
                          : null, // Disabilita se stock è zero
                ),
              ), // <-- FINE FIX
              const SizedBox(width: 8),

              // 3. Copia Descrizione (NUOVO)
              Tooltip(
                // <-- INIZIO FIX
                message: 'Copia Descrizione',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.note_text),
                  label: const Text('Copia'),
                  onPressed: _copyDescriptionToClipboard,
                ),
              ), // <-- FINE FIX
              const SizedBox(width: 8),

              // 4. Barcode
              Tooltip(
                // <-- INIZIO FIX
                message: 'Salva Barcode',
                child: TextButton.icon(
                  icon: const Icon(Iconsax.barcode),
                  label: const Text('Barcode'),
                  onPressed: _saveBarcodeImage,
                ),
              ), // <-- FINE FIX
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection() {
    final Color soldColor = Colors.red[500]!;
    final Color availableColor =
        Colors.green[500]!; // Colore verde per disponibile

    if (_isVariantsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_variants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nessuna variante trovata.'),
        ),
      );
    }

    return Column(
      children:
          _variants.map((variant) {
            final bool isVariantSold = variant['is_sold'] == 1;
            final Color statusColor =
                isVariantSold ? soldColor : availableColor;

            // --- INIZIO MODIFICA ---
            return Card(
              color:
                  isVariantSold
                      ? soldColor.withAlpha(51)
                      : Theme.of(context).cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                // 1. Il titolo (ora centrato verticalmente)
                title: Text(
                  variant['variant_name'] ?? 'Senza nome',
                  style: TextStyle(
                    color: statusColor, // Usa colore verde/rosso
                    decoration:
                        isVariantSold ? TextDecoration.lineThrough : null,
                  ),
                ),

                // 2. Sottotitolo (RIMOSSO)

                // 3. Trailing (Sostituito con il numero di pezzi)
                trailing: Text(
                  ((variant['quantity'] as num?)?.toInt() ?? 0).toString(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // Stessa dimensione del titolo
                  ),
                ),
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
                    _markChanged();
                    _refreshAllData();
                  }
                },
              ),
            );
            // --- FINE MODIFICA ---
          }).toList(),
    );
  }

  // --- MODIFICATA: Widget galleria a sezioni ---
  Widget _buildPhotoGallery() {
    if (_isPhotosLoading) {
      return _buildPhotoGallerySkeleton();
    }

    // 1. Filtra le foto dell'articolo principale (quelle senza variant_id)
    final List<Map<String, dynamic>> mainPhotos =
        _photos
            .where((p) => p['variant_id'] == null)
            .cast<Map<String, dynamic>>()
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- SEZIONE ARTICOLO PRINCIPALE ---
        Text(
          'Foto Articolo Principale',
          style: TextStyle(
            color: _headerTextColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140, // Altezza fissa per la riga
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: mainPhotos.length + 1, // +1 per il bottone "Aggiungi"
            itemBuilder: (context, index) {
              if (index == 0) {
                // Bottone "Aggiungi" per l'articolo (target = null)
                return _buildAddPhotoButton(targetVariantId: null);
              }
              // Mostra la foto
              final photo = mainPhotos[index - 1];
              return _buildPhotoTile(photo: photo);
            },
          ),
        ),
        const SizedBox(height: 24), // Spazio tra le sezioni
        // --- SEZIONI VARIANTI ---
        // Itera su ogni variante e crea una sezione per lei
        ..._variants.map((variant) {
          final int variantId = variant['variant_id'];
          final String variantName = variant['variant_name'] ?? 'Variante';

          // Filtra le foto solo per QUESTA variante
          final List<Map<String, dynamic>> variantPhotos =
              _photos
                  .where((p) => p['variant_id'] == variantId)
                  .cast<Map<String, dynamic>>()
                  .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Variante: $variantName',
                style: TextStyle(
                  color: _headerTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: variantPhotos.length + 1, // +1 per il bottone
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Bottone "Aggiungi" per QUESTA variante
                      return _buildAddPhotoButton(targetVariantId: variantId);
                    }
                    final photo = variantPhotos[index - 1];
                    return _buildPhotoTile(photo: photo);
                  },
                ),
              ),
              const SizedBox(height: 24), // Spazio tra le varianti
            ],
          );
        }).toList(),

        // --- LOADER (se stiamo caricando) ---
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

  // Widget _buildPlatformsSection()
  Widget _buildPlatformsSection() {
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
                  backgroundColor: accentColor.withAlpha(25),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
              .toList(),
    );
  }
}
