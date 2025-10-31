// lib/item_detail_page.dart - AGGIORNATO CON UPLOAD FOTO

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:app/add_variant_page.dart';
import 'package:app/sell_item_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/photo_viewer_page.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // Variabili di stato
  List _variants = [];
  bool _isVariantsLoading = false;
  List _salesLog = [];
  bool _isLogLoading = false;
  List _photos = [];
  bool _isPhotosLoading = false;

  // (2 - NUOVO) Stato per il caricamento di una foto
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker(); // Istanza di ImagePicker

  @override
  void initState() {
    super.initState();
    if (widget.item['has_variants'] == 1) {
      _fetchVariants();
    }
    _fetchSalesLog();
    _fetchPhotos();
  }

  // --- FUNZIONI DI CARICAMENTO DATI ---
  // ... (tutte le funzioni _fetch... rimangono invariate) ...
  Future<void> _fetchVariants() async {
    /* ... codice ... */
    setState(() {
      _isVariantsLoading = true;
    });
    try {
      final itemId = widget.item['item_id'];
      final url =
          'http://trentin-nas.synology.me:4000/api/items/$itemId/variants';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted)
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
    /* ... codice ... */
    setState(() {
      _isLogLoading = true;
    });
    try {
      final itemId = widget.item['item_id'];
      final url = 'http://trentin-nas.synology.me:4000/api/items/$itemId/sales';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted)
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
    /* ... codice ... */
    setState(() {
      _isPhotosLoading = true;
    });
    try {
      final itemId = widget.item['item_id'];
      final url =
          'http://trentin-nas.synology.me:4000/api/items/$itemId/photos';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted)
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

  // (3 - NUOVO) Funzione per scegliere e caricare una foto
  Future<void> _pickAndUploadImage() async {
    // (A) Apri il selettore file per scegliere un'immagine
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) {
      return; // L'utente ha annullato
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // (B) Prepara la richiesta "multipart" (per file)
      const url = 'http://trentin-nas.synology.me:4000/api/photos/upload';
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // (C) Aggiungi i campi di testo (come item_id)
      request.fields['item_id'] = widget.item['item_id'].toString();
      // TODO: Aggiungere un modo per selezionare la variante (variant_id)
      // request.fields['description'] = 'Descrizione foto';

      // (D) Aggiungi il file
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo', // Questo DEVE corrispondere a 'photo' in index.js
          pickedFile.path,
        ),
      );

      // (E) Invia la richiesta
      var streamedResponse = await request.send();

      // (F) Controlla la risposta
      if (streamedResponse.statusCode == 201) {
        _fetchPhotos(); // Successo! Ricarica la galleria
      } else {
        // Leggi la risposta di errore dal server
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

  // Funzione per copiare (invariata)
  void _copyToClipboard(String text) {
    /* ... codice ... */
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codice copiato negli appunti!')),
    );
  }

  // --- FUNZIONE PRINCIPALE BUILD ---
  @override
  Widget build(BuildContext context) {
    // ... (codice invariato) ...
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        /* ... codice appbar invariato ... */
        title: Text(item['name'] ?? 'Dettaglio Articolo'),
        actions: [
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
                    itemId: widget.item['item_id'],
                    hasVariants: widget.item['has_variants'] == 1,
                    variants: _variants,
                  );
                },
              );
              if (saleRegistered == true) {
                _fetchSalesLog();
                if (widget.item['has_variants'] == 1) _fetchVariants();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        /* ... codice listview e sezioni info/varianti invariato ... */
        padding: const EdgeInsets.all(16.0),
        children: [
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
                onPressed: () => _copyToClipboard(item['unique_code'] ?? ''),
                tooltip: 'Copia codice',
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow('Categoria', item['category']),
          _buildInfoRow('Brand', item['brand']),
          _buildInfoRow('Descrizione', item['description']),
          const Divider(height: 32),
          _buildInfoRow('Valore Stimato', '€ ${item['value'] ?? 'N/D'}'),
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
                    final bool? newVariantAdded = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AddVariantPage(itemId: widget.item['item_id']),
                      ),
                    );
                    if (newVariantAdded == true) _fetchVariants();
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
              'Prezzo di Acquisto',
              '€ ${item['purchase_price'] ?? 'N/D'}',
            ),
          ],

          // (4 - SEZIONE GALLERIA MODIFICATA)
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
              // Bottone Aggiungi (ora è attivo!)
              TextButton.icon(
                // (5) Mostra un loader se sta caricando
                icon:
                    _isUploading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Aggiungi'),
                // (6) Collega la funzione e disabilita durante l'upload
                onPressed: _isUploading ? null : _pickAndUploadImage,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPhotoGallery(), // (invariato)
          // --- Sezione Log Vendite (invariata) ---
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
    );
  }

  // --- TUTTI I WIDGET HELPER (_build...Section, _buildInfoRow) ---
  // --- SONO INVARIATI ---

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
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        // Cerca questo blocco (dentro _buildPhotoGallery)
        itemBuilder: (context, index) {
          final photo = _photos[index];
          final photoUrl =
              'http://trentin-nas.synology.me:4000/${photo['file_path']}';

          // (1) SOSTITUISCI QUESTA PARTE
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1,

                // (2) CON QUESTA NUOVA PARTE
                child: InkWell(
                  // <-- Aggiunto InkWell per l'effetto "tocco"
                  onTap: () {
                    // (3) Apriamo la nuova pagina!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // (4) Usiamo fullscreenDialog per un'apertura "dal basso"
                        fullscreenDialog: true,
                        builder:
                            (context) => PhotoViewerPage(photoUrl: photoUrl),
                      ),
                    );
                  },
                  // (5) Il resto del codice dell'immagine è ora "figlio" di InkWell
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
                      return const Icon(Icons.broken_image, color: Colors.grey);
                    },
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
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(variant['variant_name'] ?? 'Senza nome'),
                subtitle: Text(
                  'Pezzi: ${variant['quantity']} | Prezzo Acq: € ${variant['purchase_price']}',
                ),
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
