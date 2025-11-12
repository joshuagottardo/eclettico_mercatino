import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:eclettico/snackbar_helper.dart';

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

  // --- MODIFICA: Aggiunto FocusNode per la tastiera ---
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // --- MODIFICA: Richiedi il focus per la tastiera ---
    // Lo facciamo dopo che il primo frame è stato disegnato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose(); // <-- Ricorda di fare il dispose
    super.dispose();
  }

  // --- MODIFICA: Nuove funzioni per navigare ---
  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.photos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  // --- FINE MODIFICA ---

  Future<PermissionStatus> _requestMediaPermission() async {
    // ... (funzione invariata)
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

  Future<void> _downloadPhoto() async {
    if (widget.photos.isEmpty || _isDownloading) return;

    setState(() => _isDownloading = true);

    showFloatingSnackBar(context, 'Download in corso...', isError: false);
    Padding;

    try {
      // 1) Dati immagine (comune a entrambi)
      final currentPhoto = widget.photos[_currentIndex];
      final String filePath = (currentPhoto['file_path'] ?? '').toString();
      if (filePath.isEmpty) {
        _showFeedback(success: false, message: 'Percorso immagine non valido.');
        return;
      }
      final String photoUrl = '$kBaseUrl/$filePath';

      String name = photoUrl.split('/').last.split('?').first;
      if (!name.contains('.')) {
        name = '$name.jpg';
      }

      final dio = Dio();
      final resp = await dio.get<List<int>>(
        photoUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (resp.statusCode != 200 || resp.data == null) {
        throw Exception('Download fallito (${resp.statusCode})');
      }
      final bytes = Uint8List.fromList(resp.data!);

      // 3) Logica di salvataggio diversa per piattaforma
      final bool isMobile = Theme.of(context).platform == TargetPlatform.iOS;

      if (isMobile) {
        // --- SALVATAGGIO MOBILE (iOS / Android) ---

        // 3a) Permessi
        final status = await _requestMediaPermission();

        if (status.isPermanentlyDenied) {
          _showFeedback(
            success: false,
            message: 'Permesso negato. Apri Impostazioni e abilitalo.',
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

        // 3b) Salvataggio in galleria
        final result = await ImageGallerySaver.saveImage(
          bytes,
          quality: 100,
          name: name.replaceAll(
            RegExp(r'\.[^.]+$'),
            '',
          ), // Rimuovi estensione solo qui
          isReturnImagePathOfIOS: true,
        );

        final bool ok =
            (result is Map) &&
            (result['isSuccess'] == true ||
                result['filePath'] != null ||
                result['savedPath'] != null);

        _showFeedback(
          success: ok,
          message:
              ok ? 'Foto salvata in Libreria.' : 'Salvataggio non riuscito.',
        );
      } else {
        // --- SALVATAGGIO DESKTOP (Windows / macOS / Linux) ---

        // 3a) Apri "Salva con nome..."
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Salva foto',
          fileName: name, // Usa il nome file completo di estensione
        );

        // 3b) Se l'utente ha scelto un percorso
        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          _showFeedback(success: true, message: 'Foto salvata!');
        } else {
          // L'utente ha premuto "Annulla"
          _showFeedback(success: false, message: 'Salvataggio annullato.');
        }
      }
    } catch (e) {
      if (e is MissingPluginException) {
        _showFeedback(
          success: false,
          message: 'Salvataggio non supportato su questa piattaforma.',
        );
      } else {
        _showFeedback(success: false, message: 'Errore: $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

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
        HapticFeedback.mediumImpact();
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

  void _showFeedback({required bool success, required String message}) {
    // ... (funzione invariata)
    if (mounted) {
      showFloatingSnackBar(context, message, isError: !success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool actionInProgress = _isDownloading || _isDeleting;
    final bool hasPhotos = widget.photos.isNotEmpty;

    // --- MODIFICA: Determina se siamo su mobile ---
    final bool isMobile = Theme.of(context).platform == TargetPlatform.iOS;

    // --- MODIFICA: Avvolgi tutto in KeyboardListener ---
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        // Ascolta solo quando il tasto è PREMUTO
        if (event is KeyDownEvent) {
          // Freccia sinistra
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousPage();
          }
          // Freccia destra
          else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextPage();
          }
          // Tasto ESC
          else if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (!actionInProgress) Navigator.pop(context);
          }
        }
      },
      child: GestureDetector(
        onVerticalDragEnd: (DragEndDetails details) {
          // ... (swipe verticale invariato)
          const double minSwipeVelocity = 350.0;
          if (details.primaryVelocity != null &&
              details.primaryVelocity!.abs() > minSwipeVelocity) {
            if (actionInProgress) return;
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            // ... (appBar invariata)
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
                onPressed:
                    actionInProgress || !hasPhotos ? null : _downloadPhoto,
                tooltip: 'Scarica foto',
              ),
            ],
          ),
          // --- MODIFICA: Avvolgi il PageView in uno Stack ---
          body: Stack(
            children: [
              PageView.builder(
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
                          final cacheW = (constraints.maxWidth * dpr)
                              .round()
                              .clamp(256, 4096);

                          return Hero(
                            tag:
                                '$kBaseUrl/${photo['file_path']}', // Lo stesso TAG usato nell'altra pagina
                            child: Image.network(
                              compressedPhotoUrl,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: cacheW,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Iconsax.gallery_slash,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              // --- MODIFICA: Aggiungi le frecce su Desktop ---
              if (!isMobile) ...[
                // Freccia Sinistra
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Iconsax.arrow_left_2),
                      color: Colors.white,
                      tooltip: 'Foto precedente (←)',
                      onPressed: _previousPage,
                    ),
                  ),
                ),
                // Freccia Destra
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Iconsax.arrow_right_3),
                      color: Colors.white,
                      tooltip: 'Foto successiva (→)',
                      onPressed: _nextPage,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
