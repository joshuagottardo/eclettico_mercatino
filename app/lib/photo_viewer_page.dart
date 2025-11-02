// lib/photo_viewer_page.dart - AGGIORNATO CON SWIPE (PAGEVIEW)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:app/api_config.dart';

class PhotoViewerPage extends StatefulWidget {
  // (1 - MODIFICA) Riceviamo l'elenco e l'indice iniziale
  final List<Map<String, dynamic>> photos;
  final int initialIndex;

  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  bool _isDownloading = false;
  bool _isDeleting = false;

  // (2 - NUOVO) Controller per il PageView
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // (3 - NUOVO) Inizializza il controller e l'indice
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // (4 - MODIFICA) Funzione per scaricare (usa _currentIndex)
  Future<void> _downloadPhoto() async {
    if (widget.photos.isEmpty) return;

    setState(() {
      _isDownloading = true;
    });

    // Prende l'URL della foto corrente
    final currentPhoto = widget.photos[_currentIndex];
    final photoUrl = '$kBaseUrl/${currentPhoto['file_path']}';

    try {
      // ... (Logica di download invariata) ...
      Directory? downloadsDir;
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        downloadsDir = await getDownloadsDirectory();
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      if (downloadsDir == null) {
        _showFeedback(
          success: false,
          message: 'Cartella download non trovata.',
        );
        return;
      }
      final String fileName = Uri.parse(photoUrl).pathSegments.last;
      final String savePath = '${downloadsDir.path}/$fileName';
      Dio dio = Dio();
      await dio.download(photoUrl, savePath);
      _showFeedback(success: true, message: 'Foto salvata in Download!');
    } catch (e) {
      print('Errore download: $e');
      _showFeedback(success: false, message: 'Download fallito.');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  // (5 - MODIFICA) Funzione per eliminare la foto (usa _currentIndex)
  Future<void> _deletePhoto() async {
    if (widget.photos.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Sei sicuro?'),
            content: const Text(
              'Vuoi eliminare definitivamente questa foto? L\'azione non è reversibile.',
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

    // Prende l'ID della foto corrente
    final currentPhoto = widget.photos[_currentIndex];
    final photoId = currentPhoto['photo_id'];

    try {
      final url = '$kBaseUrl/api/photos/$photoId';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          _showFeedback(success: true, message: 'Foto eliminata.');
          // Chiudi la pagina e passa "true" per ricaricare la galleria
          Navigator.pop(context, true);
          // NOTA: Non serve rimuovere l'item dalla lista localmente
          // perché chiudiamo subito la pagina e la galleria si ricarica.
        }
      } else {
        _showFeedback(
          success: false,
          message: 'Errore server: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showFeedback(success: false, message: 'Errore di rete: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // Helper per mostrare un messaggio (invariato)
  void _showFeedback({required bool success, required String message}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green[600] : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool actionInProgress = _isDownloading || _isDeleting;
    // (6 - NUOVO) Controllo se ci sono foto
    final bool hasPhotos = widget.photos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: actionInProgress ? null : () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon:
                _isDeleting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                    : const Icon(Icons.delete_outline, color: Colors.red),
            // Disabilita se non ci sono foto
            onPressed: actionInProgress || !hasPhotos ? null : _deletePhoto,
            tooltip: 'Elimina foto',
          ),
          IconButton(
            icon:
                _isDownloading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.download_outlined),
            // Disabilita se non ci sono foto
            onPressed: actionInProgress || !hasPhotos ? null : _downloadPhoto,
            tooltip: 'Scarica foto',
          ),
        ],
      ),
      // (7 - MODIFICA) Sostituito il body con un PageView.builder
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        // Aggiorna l'indice corrente quando la pagina cambia
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final photoUrl = '$kBaseUrl/${photo['file_path']}';

          // Mantiene lo zoom per ogni singola foto
          return InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // larghezza reale del riquadro in cui stai mostrando la foto
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  // limita per sicurezza (iOS ama avere un upper bound)
                  final cacheW = (constraints.maxWidth * dpr).round().clamp(
                    256,
                    4096,
                  );

                  return Image.network(
                    photoUrl, // 👈 lascia la tua variabile/url
                    fit: BoxFit.cover, // o quello che avevi (cover/contain)
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: cacheW, // 👈 la novità
                    // 👇 incolla qui ESATTAMENTE i tuoi builder se li avevi già:
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
          );
        },
      ),
    );
  }
}
