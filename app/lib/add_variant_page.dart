// lib/add_variant_page.dart - AGGIORNATO PER MODIFICA E DELETE

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/api_config.dart';

class AddVariantPage extends StatefulWidget {
  final int itemId;
  // (1 - MODIFICA) Aggiungiamo variantId opzionale
  final int? variantId;

  const AddVariantPage({super.key, required this.itemId, this.variantId});

  @override
  State<AddVariantPage> createState() => _AddVariantPageState();
}

class _AddVariantPageState extends State<AddVariantPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller (invariati)
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Dati per Piattaforme (invariati)
  List _platforms = [];
  bool _platformsLoading = true;
  final Set<int> _selectedPlatformIds = {};

  // (2 - NUOVO) Stati per la logica di pagina
  bool _isLoading = false; // Per il salvataggio
  bool _isPageLoading = false; // Per il caricamento iniziale
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _fetchPlatforms();

    // (3 - NUOVO) Logica per la modalità Modifica
    if (widget.variantId != null) {
      _isEditMode = true;
      _isPageLoading = true;
      _loadVariantData();
    }
  }

  // (4 - NUOVO) Funzione per caricare i dati della variante
  Future<void> _loadVariantData() async {
    try {
      final url = '$kBaseUrl/api/variants/${widget.variantId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final variant = jsonDecode(response.body);
        if (mounted) {
          // Popoliamo i controller
          _nameController.text = variant['variant_name'] ?? '';
          _purchasePriceController.text =
              variant['purchase_price']?.toString() ?? '';
          _quantityController.text = variant['quantity']?.toString() ?? '';
          _descriptionController.text = variant['description'] ?? '';

          // Popoliamo le piattaforme
          if (variant['platforms'] != null) {
            _selectedPlatformIds.clear();
            _selectedPlatformIds.addAll(List<int>.from(variant['platforms']));
          }
        }
      } else {
        _showError('Errore nel caricare i dati della variante');
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

  // Funzione per caricare le piattaforme (invariata)
  Future<void> _fetchPlatforms() async {
    try {
      const url = '$kBaseUrl/api/platforms';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _platforms = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      _showError('Errore caricamento piattaforme');
    } finally {
      if (mounted) {
        setState(() {
          _platformsLoading = false;
        });
      }
    }
  }

  // (5 - MODIFICA) Rinominata in _submitForm
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final body = {
      "variant_name": _nameController.text,
      "purchase_price": double.tryParse(_purchasePriceController.text),
      "quantity": int.tryParse(_quantityController.text),
      "description": _descriptionController.text,
      "platforms": _selectedPlatformIds.toList(),
    };

    try {
      http.Response response;

      // (6 - NUOVO) Logica per POST (Crea) o PUT (Modifica)
      if (_isEditMode) {
        // --- MODALITÀ MODIFICA ---
        final url = '$kBaseUrl/api/variants/${widget.variantId}';
        response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      } else {
        // --- MODALITÀ CREAZIONE ---
        final url = '$kBaseUrl/api/items/${widget.itemId}/variants';
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true); // Successo!
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

  // (7 - NUOVO) Funzione per eliminare la variante
  Future<void> _deleteVariant() async {
    // Chiedi conferma
    final bool? confirmed = await _showDeleteConfirmation();
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    }); // Usiamo lo stesso loader
    try {
      final url = '$kBaseUrl/api/variants/${widget.variantId}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true); // Successo!
      } else {
        // Mostra l'errore specifico (es. "ha vendite associate")
        final error = jsonDecode(response.body);
        _showError(error['error'] ?? 'Errore server: ${response.statusCode}');
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

  // (8 - NUOVO) Dialog di conferma eliminazione
  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Sei sicuro?'),
            content: const Text(
              'Vuoi davvero eliminare questa variante? L\'azione non è reversibile.',
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
        // (9 - MODIFICA) Titolo e Azioni dinamiche
        title: Text(_isEditMode ? 'Modifica Variante' : 'Aggiungi Variante'),
        actions: [
          // (10 - NUOVO) Bottone Elimina (solo in Modifica)
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isLoading ? null : _deleteVariant,
              tooltip: 'Elimina Variante',
            ),
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
            onPressed: _isLoading ? null : _submitForm, // (11 - MODIFICA)
            tooltip: 'Salva',
          ),
        ],
      ),
      // (12 - MODIFICA) Mostra loader
      body: GestureDetector(
        onTap: () {
          // Chiude la tastiera forzando la rimozione del focus da qualsiasi campo
          FocusScope.of(context).unfocus();
        },
        child:
            _isPageLoading || _platformsLoading
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
                      // ... (Campi modulo invariati) ...
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) => v!.isEmpty ? 'Obbligatorio' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: const InputDecoration(
                                labelText: 'N° Pezzi',
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
                                labelText: 'Acquisto (€)',
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
                          labelText: 'Descrizione',
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Piattaforme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._buildPlatformCheckboxes(),
                    ],
                  ),
                ),
      ),
    );
  }

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
