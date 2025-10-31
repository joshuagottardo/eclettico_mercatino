// lib/add_variant_page.dart - AGGIORNATO CON CHECKBOX PIATTAFORME

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddVariantPage extends StatefulWidget {
  final int itemId;
  const AddVariantPage({super.key, required this.itemId});

  @override
  State<AddVariantPage> createState() => _AddVariantPageState();
}

class _AddVariantPageState extends State<AddVariantPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  // (1 - NUOVO) Dati per Piattaforme
  List _platforms = [];
  bool _platformsLoading = true;
  final Set<int> _selectedPlatformIds = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // (2 - NUOVO) Carichiamo le piattaforme
    _fetchPlatforms();
  }

  // (3 - NUOVO) Funzione per caricare le piattaforme
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

  Future<void> _saveVariant() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final body = {
      "variant_name": _nameController.text,
      "purchase_price": double.tryParse(_purchasePriceController.text),
      "quantity": int.tryParse(_quantityController.text),
      "description": _descriptionController.text,
      // (4 - MODIFICA) Inviamo la lista di ID
      "platforms": _selectedPlatformIds.toList(),
    };

    try {
      final url =
          'http://trentin-nas.synology.me:4000/api/items/${widget.itemId}/variants';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
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
    _purchasePriceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi Variante'),
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
            onPressed: _isLoading ? null : _saveVariant,
            tooltip: 'Salva',
          ),
        ],
      ),
      // (5 - MODIFICA) Mostra loader se carica piattaforme
      body:
          _platformsLoading
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
                    // ... (Campi nome, quantità, prezzo, descrizione INVARIATI) ...
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Variante (es. Rosso, XL)',
                      ),
                      validator: (v) => v!.isEmpty ? 'Obbligatorio' : null,
                    ),
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
                            validator: (v) => v!.isEmpty ? 'Obbl.' : null,
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
                            validator: (v) => v!.isEmpty ? 'Obbl.' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione (opzionale)',
                      ),
                      maxLines: 3,
                    ),

                    // (6 - NUOVO) Sezione Checkbox Piattaforme
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Piattaforme di Pubblicazione',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._buildPlatformCheckboxes(),
                  ],
                ),
              ),
    );
  }

  // (7 - NUOVO) Funzione Helper per costruire le checkbox
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
