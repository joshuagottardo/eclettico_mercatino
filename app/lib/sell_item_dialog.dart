// lib/sell_item_dialog.dart - AGGIORNATO CON VALIDAZIONE STOCK

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SellItemDialog extends StatefulWidget {
  final int itemId;
  final bool hasVariants;
  final List variants;
  // (1 - NUOVO) Riceviamo la quantità per gli articoli singoli
  final int? itemQuantity;

  const SellItemDialog({
    super.key,
    required this.itemId,
    required this.hasVariants,
    required this.variants,
    this.itemQuantity, // Aggiunto al costruttore
  });

  @override
  State<SellItemDialog> createState() => _SellItemDialogState();
}

class _SellItemDialogState extends State<SellItemDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  List _platforms = [];
  bool _platformsLoading = true;

  int? _selectedPlatformId;
  int? _selectedVariantId;
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _userController = TextEditingController();

  // (2 - NUOVO) Variabile per lo stock massimo
  int? _maxAvailableQuantity;

  @override
  void initState() {
    super.initState();
    _fetchPlatforms();

    // (3 - NUOVO) Imposta lo stock massimo se è un articolo singolo
    if (!widget.hasVariants) {
      _maxAvailableQuantity = widget.itemQuantity;
    }
  }

  Future<void> _fetchPlatforms() async {
    // ... (codice invariato) ...
    try {
      const url = 'http://trentin-nas.synology.me:4000/api/platforms';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _platforms = jsonDecode(response.body);
            _platformsLoading = false;
          });
        }
      } else {
        throw Exception('Errore caricamento piattaforme');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Navigator.pop(context);
        _showError('Errore caricamento piattaforme');
      }
    }
  }

  Future<void> _submitSale() async {
    // (4 - MODIFICA) Il validatore ora fa il controllo
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPlatformId == null) {
      _showError('Seleziona una piattaforma');
      return;
    }
    if (widget.hasVariants && _selectedVariantId == null) {
      _showError('Seleziona la variante venduta');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final body = {
      "item_id": widget.itemId,
      "variant_id": _selectedVariantId,
      "platform_id": _selectedPlatformId,
      "sale_date": DateFormat('yyyy-MM-dd').format(DateTime.now()),
      "quantity_sold": int.tryParse(_quantityController.text),
      "total_price": double.tryParse(_priceController.text),
      "sold_by_user":
          _userController.text.isNotEmpty ? _userController.text : null,
    };

    try {
      // ... (chiamata API invariata) ...
      const url = 'http://trentin-nas.synology.me:4000/api/sales';
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
    _quantityController.dispose();
    _priceController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Registra Vendita'),
      content:
          _platformsLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Piattaforme ---
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Piattaforma',
                        ),
                        value: _selectedPlatformId,
                        items:
                            _platforms.map<DropdownMenuItem<int>>((platform) {
                              return DropdownMenuItem<int>(
                                value: platform['platform_id'],
                                child: Text(platform['name']),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPlatformId = value;
                          });
                        },
                        validator:
                            (value) => value == null ? 'Obbligatorio' : null,
                      ),
                      const SizedBox(height: 16),

                      // --- Varianti (Condizionale) ---
                      if (widget.hasVariants)
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Variante',
                          ),
                          value: _selectedVariantId,
                          items:
                              widget.variants.map<DropdownMenuItem<int>>((
                                variant,
                              ) {
                                return DropdownMenuItem<int>(
                                  value: variant['variant_id'],
                                  // Mostra lo stock disponibile nel menu
                                  child: Text(
                                    '${variant['variant_name']} (Pz: ${variant['quantity']})',
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            // (5 - NUOVO) Aggiorna lo stock max
                            setState(() {
                              _selectedVariantId = value;
                              if (value != null) {
                                final selectedVariant = widget.variants
                                    .firstWhere(
                                      (v) => v['variant_id'] == value,
                                      orElse: () => null,
                                    );
                                if (selectedVariant != null) {
                                  _maxAvailableQuantity =
                                      selectedVariant['quantity'];
                                }
                              } else {
                                _maxAvailableQuantity = null;
                              }
                              _formKey.currentState
                                  ?.validate(); // Riconvalida il form
                            });
                          },
                          validator:
                              (value) => value == null ? 'Obbligatorio' : null,
                        ),

                      if (widget.hasVariants) const SizedBox(height: 16),

                      // --- Quantità e Prezzo ---
                      Row(
                        children: [
                          Expanded(
                            // (6 - MODIFICA) Campo Quantità
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantità',
                                // (7 - NUOVO) Mostra lo stock disponibile
                                helperText:
                                    _maxAvailableQuantity != null
                                        ? 'Disponibili: $_maxAvailableQuantity'
                                        : null,
                                helperStyle: TextStyle(color: Colors.grey[400]),
                              ),
                              keyboardType: TextInputType.number,
                              // (8 - NUOVO) Validatore
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Obbl.';
                                final int? enteredQuantity = int.tryParse(
                                  value,
                                );
                                if (enteredQuantity == null) return 'Num.';
                                if (enteredQuantity <= 0) return '> 0';

                                // Il controllo chiave!
                                if (_maxAvailableQuantity != null &&
                                    enteredQuantity > _maxAvailableQuantity!) {
                                  return 'Max: $_maxAvailableQuantity';
                                }
                                return null; // Va bene
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Prezzo Totale (€)',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Obbl.' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- Utente ---
                      TextFormField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          labelText: 'Utente (opzionale)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      actions: [
        // ... (bottoni invariati) ...
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitSale,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Registra'),
        ),
      ],
    );
  }
}
