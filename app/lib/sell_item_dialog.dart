// lib/sell_item_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // (1) Pacchetto per formattare la data

class SellItemDialog extends StatefulWidget {
  final int itemId;
  final bool hasVariants;
  final List variants; // (2) Riceviamo l'elenco delle varianti dalla pagina precedente

  const SellItemDialog({
    super.key,
    required this.itemId,
    required this.hasVariants,
    required this.variants,
  });

  @override
  State<SellItemDialog> createState() => _SellItemDialogState();
}

class _SellItemDialogState extends State<SellItemDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // (3) Liste per i menu a tendina
  List _platforms = []; // Per "Vinted", "Subito", ecc.
  bool _platformsLoading = true;

  // (4) Controller e valori per il form
  int? _selectedPlatformId;
  int? _selectedVariantId;
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // (5) Appena il pop-up si carica, scarichiamo la lista delle piattaforme
    _fetchPlatforms();
  }

  // (6) Funzione per caricare le piattaforme dall'API
  Future<void> _fetchPlatforms() async {
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
        throw Exception('Errore nel caricare le piattaforme');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Navigator.pop(context); // Chiudi il dialog se non riusciamo a caricare
        _showError('Errore caricamento piattaforme');
      }
    }
  }

  // (7) Funzione per registrare la vendita
  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form non valido
    }

    // Ulteriore validazione per i menu a tendina
    if (_selectedPlatformId == null) {
      _showError('Seleziona una piattaforma di vendita');
      return;
    }
    if (widget.hasVariants && _selectedVariantId == null) {
      _showError('Seleziona la variante venduta');
      return;
    }

    setState(() { _isLoading = true; });

    // (8) Prepariamo il corpo JSON
    final body = {
      "item_id": widget.itemId,
      "variant_id": _selectedVariantId, // Sarà null se non ci sono varianti
      "platform_id": _selectedPlatformId,
      "sale_date": DateFormat('yyyy-MM-dd').format(DateTime.now()), // Data odierna
      "quantity_sold": int.tryParse(_quantityController.text),
      "total_price": double.tryParse(_priceController.text),
      "sold_by_user": _userController.text.isNotEmpty ? _userController.text : null,
    };

    try {
      // (9) Chiamiamo l'API POST /api/sales
      const url = 'http://trentin-nas.synology.me:4000/api/sales';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        // (10) Successo! Chiudiamo il pop-up passando 'true'
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
        setState(() { _isLoading = false; });
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
    _quantityController.dispose();
    _priceController.dispose();
    _userController.dispose();
    super.dispose();
  }

  // (11) Costruiamo l'interfaccia del pop-up
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // (12) Usiamo un tema scuro anche per il pop-up
      backgroundColor: const Color(0xFF1E1E1E), 
      title: const Text('Registra Vendita'),
      content: _platformsLoading
          ? const Center(child: CircularProgressIndicator()) // Mostra loader se carica piattaforme
          : Form(
              key: _formKey,
              child: SingleChildScrollView( // Permette di scorrere se i campi sono troppi
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- (13) Menu a tendina Piattaforme ---
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Piattaforma'),
                      value: _selectedPlatformId,
                      items: _platforms.map<DropdownMenuItem<int>>((platform) {
                        return DropdownMenuItem<int>(
                          value: platform['platform_id'],
                          child: Text(platform['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() { _selectedPlatformId = value; });
                      },
                      validator: (value) => value == null ? 'Obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- (14) Menu a tendina Varianti (CONDIZIONALE) ---
                    if (widget.hasVariants)
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Variante'),
                        value: _selectedVariantId,
                        items: widget.variants.map<DropdownMenuItem<int>>((variant) {
                          return DropdownMenuItem<int>(
                            value: variant['variant_id'],
                            child: Text(variant['variant_name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() { _selectedVariantId = value; });
                        },
                        validator: (value) => value == null ? 'Obbligatorio' : null,
                      ),
                    
                    if (widget.hasVariants) const SizedBox(height: 16),
                    
                    // --- (15) Campi Quantità e Prezzo ---
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(labelText: 'Quantità'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Obbl.' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(labelText: 'Prezzo Totale (€)'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Obbl.' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- (16) Campo Utente ---
                    TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(labelText: 'Utente (opzionale)'),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        // Bottoni "Annulla" e "Registra"
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitSale,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Registra'),
        ),
      ],
    );
  }
}