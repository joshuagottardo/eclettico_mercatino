// lib/item_list_page.dart (AGGIORNATO CON STILE E ICONE)

import 'dart:convert';
import 'package:app/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/icon_helper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:app/api_config.dart';

class ItemListPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ItemListPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  List _items = [];
  bool _isLoading = true;
  bool _dataDidChange = false;

  @override
  void initState() {
    super.initState();
    _fetchItemsByCategory();
  }

  Future<void> _fetchItemsByCategory() async {
    try {
      final url = '$kBaseUrl/api/items/category/${widget.categoryId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _items = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print(e);
    }
  }

  Future<void> _navigateAndReload(BuildContext context, Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (result == true) {
      _dataDidChange = true;
      _fetchItemsByCategory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // <-- (FIX) Aggiunto
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        Navigator.pop(context, _dataDidChange); // <-- (FIX) Passa il flag
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.categoryName)),
        body:
            _isLoading
                ? _buildSkeletonList()
                : _items.isEmpty
                ? Center(child: Text('Nessun articolo in questa categoria.'))
                : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    // (FIX 3) Usa la nuova card
                    return _buildItemCard(item);
                  },
                ),
      ),
    );
  }

  // (FIX) Nuovo widget per la thumbnail
  Widget _buildThumbnail(String? thumbnailPath) {
    final double thumbSize = 80.0;
    final Color placeholderColor = Colors.grey[850]!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: thumbSize,
        height: thumbSize,
        color: placeholderColor,
        child:
            thumbnailPath != null
                ? Image.network(
                  '$kBaseUrl/$thumbnailPath',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Iconsax.gallery_slash,
                      size: 32,
                      color: Colors.grey[600],
                    );
                  },
                )
                // Icona placeholder se non c'è thumbnail
                : Icon(Iconsax.gallery, size: 32, color: Colors.grey[600]),
      ),
    );
  }

  // (FIX) Nuovo widget per l'animazione "skeleton" della lista
  Widget _buildSkeletonList() {
    final Color baseColor = Colors.grey[850]!;
    final Color highlightColor = Colors.grey[700]!;

    // Questo è il colore dei "box" che verranno animati
    final Color boxColor = Colors.grey[850]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 8, // Mostra 8 "righe" finte durante il caricamento
        itemBuilder: (context, index) {
          // Questa Card imita perfettamente la tua _buildItemCard
          return Card(
            color: baseColor,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              // 1. Scheletro per l'Icona (un cerchio)
              leading: Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: boxColor,
                  shape: BoxShape.circle,
                ),
              ),
              // 2. Scheletro per il Titolo (una barra)
              title: Container(
                height: 16.0,
                width: 200.0, // La larghezza è fittizia, sarà espansa
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              // 3. Scheletro per il Trailing (una barra piccola)
              trailing: Container(
                width: 30.0,
                height: 14.0,
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // (FIX) Sostituito: Widget Card AGGIORNATO con nuovo layout
  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isSold = item['is_sold'] == 1;

    Color cardColor =
        isSold ? const Color(0xFF422B2B) : Theme.of(context).cardColor;
    Color textColor =
        isSold
            ? Colors.grey[400]!
            : Theme.of(context).textTheme.bodyLarge!.color!;

    final String brand = item['brand'] ?? 'N/D';

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _navigateAndReload(context, ItemDetailPage(item: item));
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              // 1. Thumbnail
              _buildThumbnail(item['thumbnail_path']?.toString()),

              const SizedBox(width: 16),

              // 2. Testo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Articolo senza nome',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: isSold ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brand,
                      style: TextStyle(
                        color: isSold ? Colors.grey[500] : Colors.grey[400],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
