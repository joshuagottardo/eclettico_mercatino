// lib/item_detail_page.dart - AGGIORNATO CON FOTO PER VARIANTI

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:app/add_variant_page.dart';
import 'package:app/sell_item_dialog.dart';
import 'package:app/photo_viewer_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/add_item_page.dart';

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

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _refreshAllData(isInitialLoad: true);
  }

  // --- FUNZIONI DI CARICAMENTO DATI ---

  Future<void> _refreshAllData({bool isInitialLoad = false}) async {
    if (!isInitialLoad) {
      setState(() {
        _isVariantsLoading = true;
        _isLogLoading = true;
        _isPhotosLoading = true;
      });
    }
    if (!isInitialLoad) {
      await _fetchItemDetails();
    }
    if (_currentItem['has_variants'] == 1) {
      await _fetchVariants();
    }
    await _fetchSalesLog();
    await _fetchPhotos();
  }

  Future<void> _fetchItemDetails() async {
    try {
      final url =
          'http://trentin-nas.synology.me:4000/api/items/${_currentItem['item_id']}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _currentItem = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print('Errore ricaricando item details: $e');
    }
  }

  Future<void> _fetchVariants() async {
    if (!mounted) return;
    setState(() {
      _isVariantsLoading = true;
    });
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
    if (!mounted) return;
    setState(() {
      _isLogLoading = true;
    });
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
    if (!mounted) return;
    setState(() {
      _isPhotosLoading = true;
    });
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

  // --- FUNZIONI DI AZIONE ---

  // (1 - MODIFICA) Funzione _pickAndUploadImage
  Future<void> _pickAndUploadImage() async {
    // (A - NUOVO) Chiediamo all'utente a cosa collegare la foto
    final dynamic photoTarget = await _showPhotoTargetDialog();

    // 'cancel' è il valore speciale che restituiamo se l'utente preme "Annulla"
    if (photoTarget == 'cancel') {
      return; // L'utente ha annullato il primo pop-up
    }

    // (B) Apri il selettore file per scegliere un'immagine
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      return; // L'utente ha annullato il selettore
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // (C) Prepara la richiesta "multipart"
      const url = 'http://trentin-nas.synology.me:4000/api/photos/upload';
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // (D) Aggiungi i campi di testo
      request.fields['item_id'] = _currentItem['item_id'].toString();

      // (E - NUOVO) Aggiungiamo il variant_id SE l'utente ne ha scelto uno
      // Se photoTarget è 'null', significa che ha scelto "Articolo Principale"
      if (photoTarget != null) {
        request.fields['variant_id'] = photoTarget.toString();
      }

      // (F) Aggiungi il file
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo', // Questo DEVE corrispondere a 'photo' in index.js
          pickedFile.path,
        ),
      );

      // (G) Invia la richiesta
      var streamedResponse = await request.send();

      // (H) Controlla la risposta
      if (streamedResponse.statusCode == 201) {
        _dataDidChange = true;
        _fetchPhotos(); // Successo! Ricarica la galleria
      } else {
        final response = await http.Response.fromStream(streamedResponse);
        print('Errore upload: ${response.body}');
      }
    } catch (e) {
      print('Errore (catch) durante l\'upload: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // (2 - NUOVO) Funzione per mostrare il pop-up di selezione
  Future<dynamic> _showPhotoTargetDialog() {
    // 'null' rappresenta l'articolo principale
    dynamic selectedTarget = null; // 'dynamic' per contenere null o int

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        // Usiamo StatefulBuilder per permettere al dialog di aggiornarsi
        // quando l'utente seleziona un'opzione (senza aggiornare l'intera pagina)
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Lega foto a:'),
              content: SingleChildScrollView( // Per sicurezza se ci sono troppe varianti
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Opzione 1: Articolo Principale
                    RadioListTile<dynamic>(
                      title: const Text('Articolo Principale'),
                      value: null, // Il nostro "ID" per l'articolo principale
                      groupValue: selectedTarget,
                      onChanged: (value) {
                        dialogSetState(() {
                          selectedTarget = value;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    const Divider(),
                    // Opzione 2..N: Le Varianti
                    ..._variants.map((variant) {
                      return RadioListTile<dynamic>(
                        title: Text(variant['variant_name'] ?? 'Variante'),
                        value: variant['variant_id'], // L'ID vero e proprio
                        groupValue: selectedTarget,
                        onChanged: (value) {
                          dialogSetState(() {
                            selectedTarget = value;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'), // Valore speciale
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Restituisce l'ID selezionato (o null)
                    Navigator.pop(context, selectedTarget);
                  },
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

  // --- FUNZIONE PRINCIPALE BUILD ---
  @override
  Widget build(BuildContext context) {
    final item = _currentItem;

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
            // Bottone Modifica
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifica Articolo',
              onPressed: () async {
                final bool? itemChanged = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddItemPage(
                      itemId: item['item_id'],
                    ),
                  ),
                );
                if (itemChanged == true) {
                  _dataDidChange = true;
                  _refreshAllData();
                }
              },
            ),

            // Bottone Vendi
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('VENDI'),
              onPressed: () async {
                final bool? saleRegistered = await showDialog(
                  context: context,
                  builder: (context) {
                    return SellItemDialog(
                      itemId: item['item_id'],
                      hasVariants: item['has_variants'] == 1,
                      variants: _variants,
                    );
                  },
                );
                if (saleRegistered == true) {
                  _dataDidChange = true;
                  if (item['has_variants'] == 1) _fetchVariants();
                  _fetchSalesLog();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ... (Sezioni Info e Varianti sono invariate) ...
            Text(
              'CODICE UNIVOCo',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 12, letterSpacing: 1.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['unique_code'] ?? 'N/D',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.copy,
                      color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _copyToClipboard(item['unique_code'] ?? ''),
                  tooltip: 'Copia codice',
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow('Categoria', item['category_name']),
            _buildInfoRow('Brand', item['brand']),
            _buildInfoRow('Descrizione', item['description']),
            const Divider(height: 32),
            _buildInfoRow('Valore Stimato', '€ ${item['value'] ?? 'N/D'}'),
            _buildInfoRow(
                'Prezzo di Vendita', '€ ${item['sale_price'] ?? 'N/D'}'),
            if (item['has_variants'] == 1) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('VARIANTI',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          letterSpacing: 1.5)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Aggiungi'),
                    onPressed: () async {
                      final bool? newVariantAdded = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                AddVariantPage(itemId: item['item_id'])),
                      );
                      if (newVariantAdded == true) {
                        _dataDidChange = true;
                        _fetchVariants();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildVariantsSection(),
            ] else ...[
              const Divider(height: 32),
              _buildInfoRow('Pezzi Disponibili', '${item['quantity'] ?? '0'}'),
              _buildInfoRow(
                  'Prezzo di Acquisto', '€ ${item['purchase_price'] ?? 'N/D'}'),
            ],

            // Sezione Galleria Foto
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GALLERIA FOTO',
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        letterSpacing: 1.5)),
                TextButton.icon(
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: const Text('Aggiungi'),
                  onPressed: _isUploading ? null : _pickAndUploadImage,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPhotoGallery(), // (MODIFICATA)

            // Sezione Log Vendite
            const Divider(height: 32),
            Text('LOG VENDITE',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            _buildSalesLogSection(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  // (3 - MODIFICA) _buildPhotoGallery
  Widget _buildPhotoGallery() {
    if (_isPhotosLoading)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    if (_photos.isEmpty)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nessuna foto trovata.')));

    return SizedBox(
      height: 140, // Aumentata l'altezza per far spazio al testo
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final photo = _photos[index];
          final photoUrl =
              'http://trentin-nas.synology.me:4000/${photo['file_path']}';

          // (NUOVO) Cerca il nome della variante a cui la foto è collegata
          String targetName = 'Articolo Principale';
          if (photo['variant_id'] != null) {
            // Cerca nella nostra lista _variants
            final matchingVariant = _variants.firstWhere(
              (v) => v['variant_id'] == photo['variant_id'],
              orElse: () => null, // Ritorna null se non trova
            );
            if (matchingVariant != null) {
              targetName = matchingVariant['variant_name'] ?? 'Variante';
            } else {
              targetName = 'Variante'; // La foto è legata ma la variante non è (ancora) caricata
            }
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1, // Foto quadrate
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => PhotoViewerPage(photoUrl: photoUrl),
                      ),
                    );
                  },
                  // (NUOVO) Usiamo GridTile per aggiungere una barra in basso
                  child: GridTile(
                    footer: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      color: Colors.black.withOpacity(0.6),
                      child: Text(
                        targetName,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
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
                            child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, color: Colors.grey);
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
    if (_isVariantsLoading)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    if (_variants.isEmpty)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nessuna variante trovata.')));
    return Column(
      children: _variants.map((variant) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(variant['variant_name'] ?? 'Senza nome'),
            subtitle: Text(
                'Pezzi: ${variant['quantity']} | Prezzo Acq: € ${variant['purchase_price']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              /* TODO: Aprire dettaglio variante */
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalesLogSection() {
    if (_isLogLoading)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    if (_salesLog.isEmpty)
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nessuna vendita registrata.')));
    return Column(
      children: _salesLog.map((sale) {
        String title = 'Venduto su ${sale['platform_name'] ?? 'N/D'}';
        if (sale['variant_name'] != null) {
          title += ' (${sale['variant_name']})';
        }
        String date = sale['sale_date']?.split('T')[0] ?? 'Data sconosciuta';
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading:
                const Icon(Icons.check_circle_outline, color: Colors.green),
            title: Text(title),
            subtitle: Text(
                '$date | ${sale['quantity_sold']} pz | Tot: € ${sale['total_price']}'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
                color: Colors.grey[400], fontSize: 12, letterSpacing: 1.5),
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