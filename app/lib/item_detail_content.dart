// lib/item_detail_page.dart - FIX COMPLETO (FINALIZZAZIONE UI)

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
import 'package:app/api_config.dart'; // Importato

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
    _dataDidChange = true;
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
  bool _dataDidChange = false;
  List _allPlatforms = [];
  bool _platformsLoading = true;
  bool _isItemSold = false;
  bool _isSalesLogOpen = false; // Stato per il Drawer Log
  bool _isDeleting = false;

  // Colori (resi stabili e definiti)
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
    _isItemSold = _currentItem['is_sold'] == 1;
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
    // (FIX 3) Rimosso PopScope ridondante.
    // La navigazione "indietro" è gestita dal wrapper (item_detail_page.dart)
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text('Dettagli'),
                actions: [
                  // FIX 1: Tasto Copia (Codice Univoco)
                  IconButton(
                    tooltip:
                        'Copia Codice: ${_currentItem['unique_code'] ?? 'N/D'}',
                    icon: const Icon(Iconsax.copy),
                    onPressed:
                        () => _copyToClipboard(
                          _currentItem['unique_code'].toString(),
                        ),
                  ),

                  // FIX 2: RIMOSSO Tasto Aggiorna (Icons.refresh)

                  // Bottone Modifica Articolo
                  IconButton(
                    tooltip: 'Modifica Articolo',
                    icon: const Icon(Icons.edit),
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
                  // Bottone Vendi Articolo
                  IconButton(
                    tooltip: 'Registra Vendita',
                    icon: const Icon(Icons.sell_outlined),
                    onPressed:
                        _calculateTotalStock() > 0
                            ? () async {
                              final bool? dataChanged = await showDialog(
                                context: context,
                                builder:
                                    (context) => SellItemDialog(
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
                              );
                              if (dataChanged == true) {
                                _markChanged();
                                _refreshAllData();
                              }
                            }
                            : null, // Disabilita se stock è zero
                  ),
                ],
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        // (FIX) Avvolgiamo in una Column per aggiungere i bottoni su tablet
        child: Column(
          children: [
            // (FIX) Mostra la barra azioni solo se l'AppBar è nascosta
            if (!widget.showAppBar) _buildActionButtonsRow(),

            // (FIX) Expanded assicura che lo scroll riempia lo spazio rimanente
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

                    // --- 4. PIATTAFORME COLLEGATE ---
                    if (_allPlatforms.isNotEmpty && !_platformsLoading)
                      Text(
                        'PIATTAFORME',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _headerTextColor,
                        ),
                      ),
                    if (_allPlatforms.isNotEmpty && !_platformsLoading)
                      _buildPlatformsSection(),
                    const SizedBox(height: 24),

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
                      const SizedBox(height: 16), // Spazio prima del bottone
                      // FIX CHIAVE: Tasto Aggiungi Variante spostato in basso
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: _navigateToAddVariant,
                          icon: const Icon(Iconsax.add_square),
                          label: const Text('Aggiungi variante'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
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
                  ], // Chiusura Column interna
                ),
              ),
            ), // Chiusura Expanded
          ], // Chiusura Column esterna
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

  // Funzione helper per mostrare errori (dovresti già averla)
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

  // --- FUNZIONI DI AZIONE (Invariate) ---

  // Funzioni di caricamento (AGGIORNATE per selezione multipla)
  Future<void> _pickAndUploadImage() async {
    final dynamic photoTarget = await _showPhotoTargetDialog();
    if (photoTarget == 'cancel') return;

    // (FIX 1) Usa pickMultiImage per selezionare più file
    final List<XFile> pickedFiles = await _picker.pickMultiImage();

    // Controlla se almeno un file è stato selezionato
    if (pickedFiles.isEmpty) return;

    // Avvia l'indicatore di caricamento
    setState(() {
      _isUploading = true;
    });

    try {
      // (FIX 2) Itera su ogni file selezionato per l'upload
      for (final XFile pickedFile in pickedFiles) {
        await _uploadSingleImage(pickedFile, photoTarget);
      }

      // Se almeno un upload ha avuto successo, ricarica la galleria
      _fetchPhotos();

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
      // La gestione dell'errore per il singolo file è spostata in _uploadSingleImage
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // (NUOVA FUNZIONE) Gestisce l'upload di un singolo file
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
        // Potresti voler mostrare un errore per ogni file fallito qui,
        // ma per ora logghiamo e proseguiamo con il prossimo file.
      }
    } catch (e) {
      print('Errore upload di ${pickedFile.name}: $e');
      // Ignora l'errore per continuare con il prossimo file, l'errore generale
      // verrà catturato dal blocco superiore se necessario.
    }
  }

  Future<dynamic> _showPhotoTargetDialog() {
    dynamic selectedTarget;
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
                    }),
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

  // Widget _buildPriceAndPurchaseInfo() { ... } (Invariato)
  Widget _buildPriceAndPurchaseInfo() {
    final String purchasePrice = '€ ${_currentItem['purchase_price'] ?? 'N/D'}';
    final String estimatedValue = '€ ${_currentItem['value'] ?? 'N/D'}';

    return Row(
      children: [
        // Valore Stimato
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
        const SizedBox(width: 16),
        // Prezzo Acquisto
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
                purchasePrice,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildInfoDetailSection() { ... } (Invariato)
  Widget _buildInfoDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  // Widget _buildInfoRow(...) { ... } (Invariato)
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
          const Divider(
            height: 1,
            color: Color(0xFF2A2A2A),
          ), // Divisore più discreto
        ],
      ),
    );
  }

  // Widget _buildStockAndSalePrice() { ... } (Invariato)
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
                  Text(
                    totalStock.toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: totalStock > 0 ? _availableColor : _soldColor,
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
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: _headerTextColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    salePrice,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
    );
  }

  // Widget _buildSalesLogDrawer() { ... } (Invariato)
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
          color: _logDrawerColor, // Nuovo colore: Grigio molto scuro
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
            // Lo sfondo del corpo del log sarà lo stesso della Card
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

  // Widget _buildSalesLogSection() { ... } (Invariato)
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
                        (context) => EditSaleDialog(
                          sale: sale,
                          allPlatforms: _allPlatforms,
                          currentStock: currentStock!,
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

  // (FIX) Widget helper per mostrare i bottoni su tablet/desktop
  Widget _buildActionButtonsRow() {
    // Usiamo un colore di sfondo simile all'AppBar per coerenza
    return Container(
      color:
          Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Allinea i bottoni a destra
        children: [
          // Tasto Copia (Codice Univoco)
          IconButton(
            tooltip: 'Copia Codice: ${_currentItem['unique_code'] ?? 'N/D'}',
            icon: const Icon(Iconsax.copy),
            onPressed:
                () => _copyToClipboard(_currentItem['unique_code'].toString()),
          ),

          // Bottone Modifica Articolo
          IconButton(
            tooltip: 'Modifica Articolo',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final bool? dataChanged = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AddItemPage(itemId: _currentItem['item_id']),
                ),
              );
              if (dataChanged == true) {
                _markChanged();
                _refreshAllData();
              }
            },
          ),

          // Bottone Vendi Articolo
          IconButton(
            tooltip: 'Registra Vendita',
            icon: const Icon(Icons.sell_outlined),
            onPressed:
                _calculateTotalStock() > 0
                    ? () async {
                      final bool? dataChanged = await showDialog(
                        context: context,
                        builder:
                            (context) => SellItemDialog(
                              itemId: _currentItem['item_id'],
                              variants: _variants,
                              allPlatforms: _allPlatforms,
                              hasVariants: _currentItem['has_variants'] == 1,
                              mainItemQuantity:
                                  (_currentItem['quantity'] as num?)?.toInt() ??
                                  0,
                            ),
                      );
                      if (dataChanged == true) {
                        _markChanged();
                        _refreshAllData();
                      }
                    }
                    : null, // Disabilita se stock è zero
          ),
        ],
      ),
    );
  }

  // Funzione Helper per costruire le piattaforme di una variante (Mantenuta ma non usata)
  Widget _buildVariantPlatformsList(List<dynamic> platformIds) {
    if (platformIds.isEmpty || _allPlatforms.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<String> platformNames =
        platformIds
            .map((id) {
              final platform = _allPlatforms.firstWhere(
                (p) =>
                    (p['platform_id'] as num?)?.toInt() ==
                    (id as num?)?.toInt(),
                orElse: () => null,
              );
              return platform != null ? platform['name'].toString() : null;
            })
            .whereType<String>()
            .toList();

    if (platformNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          platformNames.map((name) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(name, style: const TextStyle(color: Colors.white70)),
            );
          }).toList(),
    );
  }

  // --- WIDGET VARIANTE ---
  Widget _buildVariantsSection() {
    final Color soldColor = Colors.red[500]!;
    final Color availableColor =
        Colors.green[500]!; // FIX 4: Colore verde per disponibile

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

            return Card(
              color:
                  isVariantSold
                      ? soldColor.withOpacity(0.2)
                      : Theme.of(context).cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(
                  variant['variant_name'] ?? 'Senza nome',
                  style: TextStyle(
                    color: statusColor, // FIX 4: Usa colore verde/rosso
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
                        color:
                            isVariantSold
                                ? Colors.grey[400]
                                : Colors.grey[300], // Colore del sottotitolo
                      ),
                    ),
                    // FIX 3: RIMOSSO _buildVariantPlatformsList(variant['platforms'] ?? []),
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
                    _markChanged();
                    _refreshAllData();
                  }
                },
              ),
            );
          }).toList(),
    );
  }

  // Widget _buildPhotoGallery() { ... } (Invariato)
  Widget _buildPhotoGallery() {
    final Color accentColor = Theme.of(context).colorScheme.primary;
    if (_isPhotosLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nessuna foto trovata.'),
            ),
            if (!_isUploading)
              TextButton.icon(
                onPressed: _pickAndUploadImage,
                icon: const Icon(Iconsax.image),
                label: const Text('Aggiungi foto'),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              final photoUrl = '$kBaseUrl/${photo['file_path']}';
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
                                  photos: _photos.cast<Map<String, dynamic>>(),
                                  // (FIX) Passa l'indice della foto cliccata
                                  initialIndex: index,
                                ),
                          ),
                        );
                        if (photoDeleted == true) {
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
        ),
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
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _pickAndUploadImage,
              icon: const Icon(Iconsax.add_square),
              label: const Text('Aggiungi foto'),
              style: TextButton.styleFrom(foregroundColor: accentColor),
            ),
          ),
      ],
    );
  }

  // Widget _buildPlatformsSection() { ... } (Invariato)
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
                  backgroundColor: accentColor.withOpacity(0.1),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
              .toList(),
    );
  }
}
