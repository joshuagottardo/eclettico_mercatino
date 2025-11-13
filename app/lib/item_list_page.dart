import 'dart:convert';
import 'package:eclettico/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/api_config.dart';
import 'package:eclettico/empty_state_widget.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
    // Se i dati sono cambiati (_dataDidChange == true), canPop diventa false.
    // Questo blocca la gesture SOLO se dobbiamo forzare il passaggio dei dati.
    // Se non hai fatto modifiche, la gesture funzionerà fluidamente.
    return PopScope(
      canPop: !_dataDidChange,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // Se siamo qui, canPop era false (quindi i dati sono cambiati).
        // Eseguiamo il pop manuale passando il risultato.
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.categoryName),
          // Aggiungiamo un leading personalizzato per assicurare
          // che il pulsante freccia funzioni sempre correttamente
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataDidChange),
          ),
        ),
        body:
            _isLoading
                ? _buildSkeletonList()
                : _items.isEmpty
                ? const EmptyStateWidget(
                  icon: Iconsax.box_remove,
                  title: 'Categoria Vuota',
                  subtitle:
                      'Non ci sono ancora articoli associati a questa categoria.',
                )
                : AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(child: _buildItemCard(item)),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }

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

  Widget _buildSkeletonList() {
    final Color baseColor = Colors.grey[850]!;
    final Color highlightColor = Colors.grey[700]!;

    final Color boxColor = Colors.grey[850]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 8,
        itemBuilder: (context, index) {
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

  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isSold = item['is_sold'] == 1;
    final bool isPublished =
        item['is_published'] == 1 || item['is_published'] == true;

    Color cardColor;
    if (isSold) {
      // Priorità 1: Se è venduto, è rosso
      cardColor = const Color(0xFF422B2B);
    } else if (!isPublished) {
      // Priorità 2: Se non venduto E non pubblicato, è sbiadito
      cardColor = const Color(0xFF4E3F2A);
    } else {
      // Altrimenti, è normale
      cardColor = Theme.of(context).cardColor;
    }
    // --- FINE MODIFICA ---

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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        // Sfondo semitrasparente basato sul colore del testo
                        color: textColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: textColor.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        brand.toUpperCase(), // Maiuscolo per stile "etichetta"
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 10, // Più piccolo ma leggibile
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (item['has_variants'] == 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Iconsax.add,
                    size: 18,
                    color: Colors.grey[600], // Sottile e non rumoroso
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
