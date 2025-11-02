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
      _fetchItemsByCategory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

  // (FIX 2 e 3) Widget Card AGGIORNATO
  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isSold = item['is_sold'] == 1;

    Color cardColor =
        isSold ? const Color(0xFF422B2B) : Theme.of(context).cardColor;
    Color textColor =
        isSold
            ? Colors.grey[300]!
            : Theme.of(context).textTheme.bodyLarge!.color!;
    Color iconColor =
        isSold ? Colors.grey[400]! : Theme.of(context).colorScheme.primary;

    // (FIX 2) Logica Icona
    final IconData itemIcon =
        isSold
            ? Iconsax.money_remove
            : getIconForCategory(item['category_name']);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: () {
          _navigateAndReload(context, ItemDetailPage(item: item));
        },
        // (FIX 2) Icona
        leading: Icon(itemIcon, color: iconColor),
        // (FIX 3) Solo Nome
        title: Text(
          item['name'] ?? 'Articolo senza nome',
          style: TextStyle(color: textColor), // Rimosso Bold
        ),
        // (FIX 3) Niente Sottotitolo
        subtitle: null,
        // (FIX 3) Quantità
        trailing: Text(
          (int.tryParse(item['display_quantity'].toString()) ?? 0).toString(),
          style: TextStyle(
            color: Colors.grey[600], // (FIX 3) Colore grigio
            fontSize: 14, // (FIX 3) Font più piccolo
          ),
        ),
      ),
    );
  }
}
