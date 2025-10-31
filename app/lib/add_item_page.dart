// lib/add_item_page.dart - AGGIORNATO CON CATEGORIE DINAMICHE

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddItemPage extends StatefulWidget {
  final int? itemId;
  const AddItemPage({super.key, this.itemId});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();

  // (1 - MODIFICA) Rimuoviamo il _categoryController
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _valueController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();

  // (2 - NUOVO) Variabili per il dropdown delle categorie
  List _categories = []; // Conterrà la lista di categorie dall'API
  int? _selectedCategoryId; // Conterrà l'ID della categoria scelta
  bool _categoriesLoading = true; // Flag per il caricamento

  // Variabili di stato
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isPageLoading = false;
  bool _hasVariants = false;

  @override
  void initState() {
    super.initState();
    
    // (3 - NUOVO) Carichiamo le categorie all'avvio
    _fetchCategories();

    if (widget.itemId != null) {
      _isEditMode = true;
      _isPageLoading = true; // Imposta _isPageLoading qui
      _loadItemData();
    }
  }

  // (4 - NUOVO) Funzione per caricare le categorie dall'API
  Future<void> _fetchCategories() async {
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/categories';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _categories = jsonDecode(response.body);
            _categoriesLoading = false;
          });
        }
      } else {
        _showError('Errore nel caricare le categorie');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
      if (mounted) {
        setState(() {
          _categoriesLoading = false;
        });
      }
    }
  }

  // Funzione per caricare i dati dell'articolo (Aggiornata)
  Future<void> _loadItemData() async {
    // Non impostare _isPageLoading qui, è già stato fatto in initState
    try {
      final url = 'http://trentin-nas.synology.me:4000/api/items/${widget.itemId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final item = jsonDecode(response.body);

        _nameController.text = item['name'] ?? '';
        // (5 - MODIFICA) Impostiamo l'ID della categoria
        _selectedCategoryId = item['category_id'];
        _descriptionController.text = item['description'] ?? '';
        _brandController.text = item['brand'] ?? '';
        _valueController.text = item['value']?.toString() ?? '';
        _salePriceController.text = item['sale_price']?.toString() ?? '';
        _hasVariants = item['has_variants'] == 1;
        if (!_hasVariants) {
          _quantityController.text = item['quantity']?.toString() ?? '';
          _purchasePriceController.text =
              item['purchase_price']?.toString() ?? '';
        }
      } else {
        _showError('Errore nel caricare i dati dell\'articolo');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    }
  }

  // Funzione per salvare (Aggiornata)
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // (6 - NUOVO) Validazione per il dropdown
    if (_selectedCategoryId == null) {
      _showError('Per favore, seleziona una categoria');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final body = {
      "name": _nameController.text,
      // (7 - MODIFICA) Inviamo l'ID della categoria
      "category_id": _selectedCategoryId,
      "description": _descriptionController.text,
      "brand": _brandController.text,
      "value": double.tryParse(_valueController.text),
      "sale_price": double.tryParse(_salePriceController.text),
      "has_variants": _hasVariants,
      "quantity": _hasVariants ? null : int.tryParse(_quantityController.text),
      "purchase_price":
          _hasVariants ? null : double.tryParse(_purchasePriceController.text),
      "platforms": []
    };

    try {
      http.Response response;

      if (_isEditMode) {
        final url =
            'http://trentin-nas.synology.me:4000/api/items/${widget.itemId}';
        response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      } else {
        const url = 'http://trentin-nas.synology.me:4000/api/items';
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _valueController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditMode ? 'Modifica Articolo' : 'Aggiungi Nuovo Articolo'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _submitForm,
            tooltip: 'Salva',
          )
        ],
      ),
      body: _isPageLoading || _categoriesLoading // (8 - MODIFICA) Mostra loader
          ? Center(
              child:
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome Articolo'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Per favore, inserisci un nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // (9 - MODIFICA) Sostituzione del campo Categoria
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    value: _selectedCategoryId,
                    // Costruiamo la lista di opzioni
                    items: _categories.map<DropdownMenuItem<int>>((category) {
                      return DropdownMenuItem<int>(
                        value: category['category_id'],
                        child: Text(category['name']),
                      );
                    }).toList(),
                    // Funzione chiamata quando un'opzione viene scelta
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Obbligatoria' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // ... (tutti gli altri campi restano invariati) ...
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _valueController,
                          decoration:
                              const InputDecoration(labelText: 'Valore (€)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _salePriceController,
                          decoration: const InputDecoration(
                              labelText: 'Prezzo Vendita (€)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile.adaptive(
                    title: const Text('L\'articolo ha varianti?'),
                    subtitle: const Text(
                        'Se sì, quantità e prezzi saranno gestiti per ogni variante'),
                    value: _hasVariants,
                    onChanged: (bool value) {
                      if (_isEditMode && !value) {
                        _showError(
                            'Non puoi disattivare le varianti su un articolo esistente.');
                        return;
                      }
                      setState(() {
                        _hasVariants = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  if (!_hasVariants) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration:
                                const InputDecoration(labelText: 'N. Pezzi'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceController,
                            decoration: const InputDecoration(
                                labelText: 'Prezzo Acquisto (€)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ]
                ],
              ),
            ),
    );
  }
}