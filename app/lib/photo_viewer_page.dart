// lib/photo_viewer_page.dart - AGGIORNATO CON ELIMINAZIONE FOTO

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http; // (1 - NUOVO) Import per http.delete
import 'package:path_provider/path_provider.dart';

class PhotoViewerPage extends StatefulWidget {
  // (2 - MODIFICA) Riceviamo ID e URL
  final int photoId;
  final String photoUrl;

  const PhotoViewerPage({
    super.key,
    required this.photoId,
    required this.photoUrl,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  bool _isDownloading = false;
  bool _isDeleting = false; // (3 - NUOVO) Stato per l'eliminazione

  // Funzione per scaricare (invariata)
  Future<void> _downloadPhoto() async {
    setState(() {
      _isDownloading = true;
    });
    try {
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
      final String fileName = Uri.parse(widget.photoUrl).pathSegments.last;
      final String savePath = '${downloadsDir.path}/$fileName';
      Dio dio = Dio();
      await dio.download(widget.photoUrl, savePath);
      _showFeedback(success: true, message: 'Foto salvata in Download!');
    } catch (e) {
      print('Errore download: $e');
      _showFeedback(success: false, message: 'Download fallito.');
    } finally {
      if (mounted)
        setState(() {
          _isDownloading = false;
        });
    }
  }

  // (4 - NUOVO) Funzione per eliminare la foto
  Future<void> _deletePhoto() async {
    // Chiedi conferma
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
    try {
      final url =
          'http://trentin-nas.synology.me:4000/api/photos/${widget.photoId}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          _showFeedback(success: true, message: 'Foto eliminata.');
          // Chiudi la pagina e passa "true" per ricaricare la galleria
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
      if (mounted)
        setState(() {
          _isDeleting = false;
        });
    }
  }

  // Helper per mostrare un messaggio
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
    // Disabilita i bottoni se è in corso un'azione
    final bool actionInProgress = _isDownloading || _isDeleting;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          // Disabilita se in azione
          onPressed: actionInProgress ? null : () => Navigator.pop(context),
        ),
        actions: [
          // (5 - NUOVO) Bottone Elimina
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
            onPressed: actionInProgress ? null : _deletePhoto,
            tooltip: 'Elimina foto',
          ),

          // Bottone Download
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
            onPressed: actionInProgress ? null : _downloadPhoto,
            tooltip: 'Scarica foto',
          ),
        ],
      ),
      body: GestureDetector(
        onTap:
            actionInProgress
                ? null
                : () {
                  // Disabilita se in azione
                  Navigator.pop(context);
                },
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.network(
              widget.photoUrl,
              fit: BoxFit.contain,
              // ... (loadingBuilder e errorBuilder invariati) ...
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 80,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
