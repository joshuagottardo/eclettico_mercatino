// lib/add_item_page.dart - AGGIORNATO CON NAVIGAZIONE AL DETTAGLIO

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// Importiamo le pagine necessarie
import 'package:app/item_detail_page.dart'; 

class AddItemPage extends StatefulWidget {
  final int? itemId;
  const AddItemPage({super.key, this.itemId});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _valueController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();

  // Dati per Categorie
  List _categories = [];
  int? _selectedCategoryId;
  bool _categoriesLoading = true;

  // Dati per Piattaforme
  List _platforms = []; 
  bool _platformsLoading = true; 
  final Set<int> _selectedPlatformIds = {};

  // Variabili di stato
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isPageLoading = false;
  bool _hasVariants = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    if (widget.itemId != null) {
      _isEditMode = true;
      _isPageLoading = true;
      _loadItemData();
    }
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchCategories(), _fetchPlatforms()]);
  }

  Future<void> _fetchCategories() async {
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/categories';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted)
          setState(() {
            _categories = jsonDecode(response.body);
          });
      }
    } catch (e) {
      _showError('Errore caricamento categorie');
    } finally {
      if (mounted)
        setState(() {
          _categoriesLoading = false;
        });
    }
  }

  Future<void> _fetchPlatforms() async {
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/platforms';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted)
          setState(() {
            _platforms = jsonDecode(response.body);
          });
      }
    } catch (e) {
      _showError('Errore caricamento piattaforme');
    } finally {
      if (mounted)
        setState(() {
          _platformsLoading = false;
        });
    }
  }

  Future<void> _loadItemData() async {
    try {
      final url =
          'http://trentin-nas.synology.me:4000/api/items/${widget.itemId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final item = jsonDecode(response.body);

        _nameController.text = item['name'] ?? '';
        _selectedCategoryId = item['category_id'];
        _descriptionController.text = item['description'] ?? '';
        _brandController.text = item['brand'] ?? '';
        _valueController.text = item['value']?.toString() ?? '';
        _salePriceController.text = item['sale_price']?.toString() ?? '';
        _hasVariants = item['has_variants'] == 1;

        if (item['platforms'] != null) {
          _selectedPlatformIds.clear();
          _selectedPlatformIds.addAll(List<int>.from(item['platforms']));
        }

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
      if (mounted)
        setState(() {
          _isPageLoading = false;
        });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showError('Per favore, seleziona una categoria');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final body = {
      "name": _nameController.text,
      "category_id": _selectedCategoryId,
      "description": _descriptionController.text,
      "brand": _brandController.text,
      "value": double.tryParse(_valueController.text),
      "sale_price": double.tryParse(_salePriceController.text),
      "has_variants": _hasVariants,
      "quantity": _hasVariants ? null : int.tryParse(_quantityController.text),
      "purchase_price":
          _hasVariants ? null : double.tryParse(_purchasePriceController.text),
      "platforms": _selectedPlatformIds.toList(),
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
        // --- LOGICA DI CREAZIONE ---
        const url = 'http://trentin-nas.synology.me:4000/api/items';
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // (1 - NUOVA LOGICA) Se l'articolo è stato creato, naviga alla sua pagina
          if (!_isEditMode && response.statusCode == 201) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            final int newItemId = responseData['newItemId']; 
            
            // Reperiamo l'articolo appena creato per avere tutti i dati
            _navigateToNewItemDetail(newItemId);
            
          } else {
            // Se è una MODIFICA, torniamo alla pagina precedente (dettaglio)
            Navigator.pop(context, true); 
          }
        }
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }
  
  // (2 - NUOVA FUNZIONE) Prende il nuovo ID e naviga al dettaglio
  void _navigateToNewItemDetail(int itemId) async {
    // Prima, chiudi la pagina di aggiunta
    Navigator.pop(context, true); 
    
    // Poi, naviga al dettaglio dell'articolo appena creato
    // Usiamo una rotta 'GET /api/items/:id' per prelevare i dati completi
    try {
        final url = 'http://trentin-nas.synology.me:4000/api/items/$itemId';
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
            final itemData = jsonDecode(response.body);
            
            // Naviga alla pagina di dettaglio
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ItemDetailPage(item: itemData)),
            );
        } else {
            _showError('Articolo creato, ma errore nel caricare i dettagli.');
        }
    } catch (e) {
        _showError('Errore di rete dopo la creazione.');
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
          _isEditMode ? 'Modifica Articolo' : 'Aggiungi Nuovo Articolo',
        ),
        actions: [
          IconButton(
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.save),
            onPressed: _isLoading ? null : _submitForm,
            tooltip: 'Salva',
          ),
        ],
      ),
      body:
          _isPageLoading || _categoriesLoading || _platformsLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // ... (Campi modulo invariati, solo la logica di navigazione è cambiata)
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Articolo',
                      ),
                      validator: (v) => v!.isEmpty ? 'Obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      value: _selectedCategoryId,
                      items:
                          _categories.map<DropdownMenuItem<int>>((category) {
                            return DropdownMenuItem<int>(
                              value: category['category_id'],
                              child: Text(category['name']),
                            );
                          }).toList(),
                      onChanged:
                          (value) => setState(() {
                            _selectedCategoryId = value;
                          }),
                      validator:
                          (value) => value == null ? 'Obbligatoria' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(labelText: 'Brand'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _valueController,
                            decoration: const InputDecoration(
                              labelText: 'Valore (€)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _salePriceController,
                            decoration: const InputDecoration(
                              labelText: 'Prezzo Vendita (€)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile.adaptive(
                      title: const Text('L\'articolo ha varianti?'),
                      subtitle: const Text(
                        'Se sì, quantità e prezzi saranno gestiti per ogni variante',
                      ),
                      value: _hasVariants,
                      onChanged: (bool value) {
                        if (_isEditMode && !value) {
                          _showError(
                            'Non puoi disattivare le varianti su un articolo esistente.',
                          );
                          return;
                        }
                        setState(() {
                          _hasVariants = value;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),

                    // --- CAMPI CONDIZIONALI (Quantità, Prezzo e Piattaforme) ---
                    if (!_hasVariants) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: const InputDecoration(
                                labelText: 'N. Pezzi',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              decoration: const InputDecoration(
                                labelText: 'Prezzo Acquisto (€)',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // (8 - NUOVO) Sezione Checkbox Piattaforme
                      Text(
                        'Piattaforme di Pubblicazione',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._buildPlatformCheckboxes(),
                    ],
                  ],
                ),
              ),
    );
  }

  // (9 - NUOVO) Funzione Helper per costruire le checkbox
  List<Widget> _buildPlatformCheckboxes() {
    return _platforms.map((platform) {
      final platformId = platform['platform_id'];
      return CheckboxListTile(
        title: Text(platform['name']),
        value: _selectedPlatformIds.contains(platformId),
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedPlatformIds.add(platformId);
            } else {
              _selectedPlatformIds.remove(platformId);
            }
          });
        },
        activeColor: Theme.of(context).colorScheme.primary,
      );
    }).toList();
  }
}