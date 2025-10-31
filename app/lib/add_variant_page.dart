// lib/add_variant_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddVariantPage extends StatefulWidget {
  // (1) Riceviamo l'ID dell'articolo "padre"
  final int itemId;

  const AddVariantPage({super.key, required this.itemId});

  @override
  State<AddVariantPage> createState() => _AddVariantPageState();
}

class _AddVariantPageState extends State<AddVariantPage> {
  final _formKey = GlobalKey<FormState>();
  
  // (2) Controller per i campi specifici della variante
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  // (3) Funzione per salvare la variante
  Future<void> _saveVariant() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form non valido
    }

    setState(() { _isLoading = true; });

    // (4) Prepariamo il corpo JSON
    final body = {
      "variant_name": _nameController.text,
      "purchase_price": double.tryParse(_purchasePriceController.text),
      "quantity": int.tryParse(_quantityController.text),
      "description": _descriptionController.text,
      "platforms": [] // TODO: Aggiungeremo la selezione piattaforme qui
    };

    try {
      // (5) Chiamiamo la rotta API specifica per l'articolo
      final url = 'http://trentin-nas.synology.me:4000/api/items/${widget.itemId}/variants';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        // (6) Successo! Chiudiamo la pagina e passiamo 'true'
        // per dire alla pagina Dettaglio di ricaricare le varianti
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
    _nameController.dispose();
    _purchasePriceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // (7) Costruiamo l'interfaccia
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi Variante'),
        actions: [
          // Bottone Salva
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveVariant,
            tooltip: 'Salva',
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Campo Nome Variante ---
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome Variante (es. Rosso, XL)'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Per favore, inserisci un nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- Quantità e Prezzo Acquisto (affiancati) ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'N. Pezzi'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obbligatorio';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    decoration: const InputDecoration(labelText: 'Prezzo Acquisto (€)'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obbligatorio';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Campo Descrizione Variante ---
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrizione (opzionale)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}