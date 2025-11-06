// lib/item_detail_page.dart

import 'package:flutter/material.dart';
import 'package:app/item_detail_content.dart';


class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  bool _dataDidChange = false;

  @override
  Widget build(BuildContext context) {
    //  Rimuoviamo Scaffold e AppBar da questo wrapper.
    //  Sostituiamo WillPopScope con PopScope.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        Navigator.pop(context, _dataDidChange);
      },
      child: GestureDetector(
        onHorizontalDragEnd: (DragEndDetails details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 100) {
            Navigator.pop(context, _dataDidChange);
          }
        },
        child: ItemDetailContent(
          item: widget.item,
          onDataChanged: (didChange) {
            _dataDidChange = didChange;
          },
        ),
      ),
    );
  }
}
