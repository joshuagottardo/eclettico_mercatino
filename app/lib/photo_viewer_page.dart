// NUOVO: Importa i pacchetti per i permessi e la galleria
import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

// Import esistenti
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';

// RIMOSSO: 'dart:io' e 'path_provider.dart' (non più necessari per questa funzione)

class PhotoViewerPage extends StatefulWidget {
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

  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<PermissionStatus> _requestMediaPermission() async {
    // iOS: usa add-only per salvare in Libreria senza leggere
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      final status = await Permission.photosAddOnly.request();
      return status;
    }

    // Android: prova prima "photos" (API 33+ -> READ_MEDIA_IMAGES), fallback a "storage"
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status;
  }

  Future<void> _downloadPhoto() async {
    if (widget.photos.isEmpty || _isDownloading) return;

    setState(() => _isDownloading = true);
    try {
      // 1) Permessi
      final status = await _requestMediaPermission();

      if (status.isPermanentlyDenied) {
        _showFeedback(
          success: false,
          message:
              'Permesso negato in modo permanente. Apri Impostazioni e abilitalo.',
        );
        await openAppSettings();
        return;
      }
      if (!status.isGranted && !status.isLimited) {
        _showFeedback(
          success: false,
          message: 'Permesso per salvare nelle Foto non concesso.',
        );
        return;
      }

      // 2) Dati immagine
      final currentPhoto = widget.photos[_currentIndex];
      final String filePath = (currentPhoto['file_path'] ?? '').toString();
      if (filePath.isEmpty) {
        _showFeedback(success: false, message: 'Percorso immagine non valido.');
        return;
      }
      final String photoUrl = '$kBaseUrl/$filePath';

      // ricava un nome file “pulito” ed assicurati di avere un’estensione
      String name = photoUrl.split('/').last.split('?').first;
      if (!name.contains('.')) {
        // fallback: imposta jpg se manca estensione
        name = '$name.jpg';
      }
      final String nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');

      // 3) Download bytes
      final dio = Dio();
      final resp = await dio.get<List<int>>(
        photoUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (resp.statusCode != 200 || resp.data == null) {
        throw Exception('Download fallito (${resp.statusCode})');
      }
      final bytes = Uint8List.fromList(resp.data!);

      // 4) Salvataggio in galleria
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name:
            nameWithoutExt, // il plugin aggiunge estensione dal mime quando può
        isReturnImagePathOfIOS: true, // utile su iOS
      );

      final bool ok =
          (result is Map) &&
          (result['isSuccess'] == true ||
              result['filePath'] != null ||
              result['savedPath'] != null);

      _showFeedback(
        success: ok,
        message: ok ? 'Foto salvata in Libreria.' : 'Salvataggio non riuscito.',
      );
    } catch (e) {
      _showFeedback(success: false, message: 'Errore: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // La tua funzione _deletePhoto (INVARIATA)
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

    final currentPhoto = widget.photos[_currentIndex];
    final photoId = currentPhoto['photo_id'];

    try {
      final url = '$kBaseUrl/api/photos/$photoId';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          _showFeedback(success: true, message: 'Foto eliminata.');
          Navigator.pop(context, true);
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

  // La tua funzione _showFeedback (INVARIATA)
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

  // Il tuo metodo build() (INVARIATO)
  @override
  Widget build(BuildContext context) {
    final bool actionInProgress = _isDownloading || _isDeleting;
    final bool hasPhotos = widget.photos.isNotEmpty;

    // --- INIZIO MODIFICA ---

    // 1. Avvolgiamo tutto in un GestureDetector
    return GestureDetector(
      onVerticalDragEnd: (DragEndDetails details) {
        // 2. Definiamo una "soglia" di velocità
        // (puoi aggiustare questo valore se sembra troppo o troppo poco sensibile)
        const double minSwipeVelocity = 350.0;

        // 3. Controlliamo se la velocità dello swipe (in qualsiasi direzione)
        //    è maggiore della nostra soglia.
        if (details.primaryVelocity != null &&
            details.primaryVelocity!.abs() > minSwipeVelocity) {
          // 4. Non chiudiamo se stiamo già scaricando o eliminando
          if (actionInProgress) return;

          // 5. Chiudiamo la pagina
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Iconsax.close_square),
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
                      : const Icon(Iconsax.trash, color: Colors.red),
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
                      : const Icon(Iconsax.document_download),
              onPressed: actionInProgress || !hasPhotos ? null : _downloadPhoto,
              tooltip: 'Scarica foto',
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final photo = widget.photos[index];
            final photoId = photo['photo_id'];
            final compressedPhotoUrl =
                '$kBaseUrl/api/photos/compressed/$photoId';

            return InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dpr = MediaQuery.devicePixelRatioOf(context);
                    final cacheW = (constraints.maxWidth * dpr).round().clamp(
                      256,
                      4096,
                    );

                    return Image.network(
                      compressedPhotoUrl,
                      fit: BoxFit.contain,
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
                        return const Icon(
                          Iconsax.gallery_slash,
                          color: Colors.grey,
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
