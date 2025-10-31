// lib/photo_viewer_page.dart - AGGIORNATO CON DOWNLOAD

import 'dart:io'; // Ci servirà per la piattaforma
import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // (1) Nuovo Import
import 'package:path_provider/path_provider.dart'; // (2) Nuovo Import

class PhotoViewerPage extends StatefulWidget {
  final String photoUrl;
  const PhotoViewerPage({super.key, required this.photoUrl});

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  // (3) Stato per il download
  bool _isDownloading = false;

  // (4) Nuova funzione per scaricare la foto
  Future<void> _downloadPhoto() async {
    setState(() { _isDownloading = true; });

    // (A) Trova la cartella Download
    // Nota: getDownloadsDirectory() funziona solo su Desktop. 
    // Per mobile (iOS/Android) dovremo usare un'altra logica in futuro.
    Directory? downloadsDir;
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      downloadsDir = await getDownloadsDirectory();
    } else {
      // Per iOS/Android è più complesso, per ora salviamo in una cartella temporanea
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) {
      _showDownloadAlert(success: false, message: 'Cartella download non trovata.');
      return;
    }

    // (B) Ricava il nome del file dall'URL (es. "photo-123.jpg")
    final String fileName = Uri.parse(widget.photoUrl).pathSegments.last;
    
    // (C) Crea il percorso completo di salvataggio
    final String savePath = '${downloadsDir.path}/$fileName';

    // (D) Avvia il download con Dio
    try {
      Dio dio = Dio();
      await dio.download(
        widget.photoUrl,
        savePath,
      );
      
      // (E) Mostra un messaggio di successo
      _showDownloadAlert(success: true, message: 'Foto salvata in Download!');

    } catch (e) {
      // (F) Gestisci errori
      print('Errore download: $e');
      _showDownloadAlert(success: false, message: 'Download fallito.');
    } finally {
      if (mounted) {
        setState(() { _isDownloading = false; });
      }
    }
  }

  // Helper per mostrare un messaggio
  void _showDownloadAlert({required bool success, required String message}) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // (5) Aggiorna il bottone nell'AppBar
          IconButton(
            icon: _isDownloading
                ? const SizedBox( // Mostra un loader se sta scaricando
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.download_outlined),
            onPressed: _isDownloading ? null : _downloadPhoto, // Collega la funzione
            tooltip: 'Scarica foto',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
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
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.broken_image, color: Colors.grey, size: 80);
              },
            ),
          ),
        ),
      ),
    );
  }
}