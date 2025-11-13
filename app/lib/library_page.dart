// lib/library_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/item_list_page.dart';
import 'package:eclettico/icon_helper.dart';
import 'package:eclettico/api_config.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List _categories = [];
  bool _isLoading = true;
  bool _dataDidChange = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      const url = '$kBaseUrl/api/categories';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _categories = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print(e);
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1200) return 8;
    if (width > 800) return 4;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Gesture attiva se NON ci sono cambiamenti, bloccata se ci sono
      canPop: !_dataDidChange,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Libreria'),
          // Tasto indietro manuale per sicurezza
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataDidChange),
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                  // ... resto del codice identico ...
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _buildCategoryButton(
                      context,
                      label: category['name'],
                      icon: IconHelper.getIconForCategory(category['name']),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ItemListPage(
                                  categoryId: category['category_id'],
                                  categoryName: category['name'],
                                ),
                          ),
                        );

                        if (result == true) {
                          // Se la lista articoli è cambiata, segniamo che
                          // anche la libreria è "sporca"
                          _dataDidChange = true;
                        }
                      },
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildCategoryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
