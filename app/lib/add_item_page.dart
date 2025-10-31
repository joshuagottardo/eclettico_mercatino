// lib/add_item_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  // (1) Chiave per il nostro Form: tiene traccia dello stato e della validazione
  final _formKey = GlobalKey<FormState>();

  // (2) Controller per recuperare il testo dai campi
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _valueController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();

  // (3) Variabili di stato
  bool _hasVariants = false;
  bool _isLoading = false;

  // (4) La funzione principale che salva il nuovo articolo
  Future<void> _saveItem() async {
    // (A) Prima, controlliamo se il form è valido (es. campi obbligatori compilati)
    if (!_formKey.currentState!.validate()) {
      return; // Non valido, non fare nulla
    }

    // (B) Impostiamo lo stato di caricamento
    setState(() {
      _isLoading = true;
    });

    // (C) Prepariamo il "corpo" (body) JSON da inviare alla nostra API
    final body = {
      "name": _nameController.text,
      "category": _categoryController.text,
      "description": _descriptionController.text,
      "brand": _brandController.text,
      "value": double.tryParse(_valueController.text),
      "sale_price": double.tryParse(_salePriceController.text),
      "has_variants": _hasVariants,
      
      // Inviamo i campi solo se NON ci sono varianti
      "quantity": _hasVariants ? null : int.tryParse(_quantityController.text),
      "purchase_price": _hasVariants ? null : double.tryParse(_purchasePriceController.text),
      
      // Per ora inviamo un array vuoto di piattaforme. Le aggiungeremo dopo.
      "platforms": [] 
    };

    try {
      // (D) Chiamiamo la nostra API (stessa rotta della home, ma con POST)
      const url = 'http://trentin-nas.synology.me:4000/api/items';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body), // Codifichiamo la nostra mappa in una stringa JSON
      );

      // (E) Controlliamo la risposta
      if (response.statusCode == 201) { // 201 = "Created" (Creato con successo)
        // Se tutto va bene, chiudiamo la pagina e torniamo alla home
        // Passiamo 'true' per dire alla HomePage "Ehi, ricarica la lista!"
        if (mounted) {
           Navigator.pop(context, true);
        }
      } else {
        // Mostra un errore se il server risponde male
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      // Mostra un errore se c'è un problema di rete
      _showError('Errore di rete: $e');
    } finally {
      // (F) In ogni caso, togliamo lo stato di caricamento
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Funzione di utilità per mostrare un messaggio di errore
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // (5) Puliamo i controller quando la pagina viene "distrutta"
  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _valueController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  // (6) Costruiamo l'interfaccia
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi Nuovo Articolo'),
        actions: [
          // Bottone "Salva"
          IconButton(
            icon: _isLoading 
                ? const SizedBox( // Se sta caricando, mostra un mini-loader
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  ) 
                : const Icon(Icons.save), // Altrimenti, l'icona "salva"
            onPressed: _isLoading ? null : _saveItem, // Disabilita il bottone durante il caricamento
            tooltip: 'Salva',
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView( // Usiamo ListView per evitare che la tastiera copra i campi
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Campo Nome ---
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome Articolo'),
              validator: (value) { // Validazione: non può essere vuoto
                if (value == null || value.isEmpty) {
                  return 'Per favore, inserisci un nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16), // Spaziatore

            // --- Campo Categoria ---
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            const SizedBox(height: 16),

            // --- Campo Brand ---
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            const SizedBox(height: 16),

            // --- Campo Descrizione ---
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // --- Campo Valore e Prezzo Vendita (affiancati) ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _valueController,
                    decoration: const InputDecoration(labelText: 'Valore (€)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceController,
                    decoration: const InputDecoration(labelText: 'Prezzo Vendita (€)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Switch per le Varianti ---
            SwitchListTile.adaptive(
              title: const Text('L\'articolo ha varianti?'),
              subtitle: const Text('Se sì, quantità e prezzi saranno gestiti per ogni variante'),
              value: _hasVariants,
              onChanged: (bool value) {
                setState(() {
                  _hasVariants = value;
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            
            // --- CAMPI CONDIZIONALI ---
            // Mostriamo questi campi solo se _hasVariants è FALSO
            if (!_hasVariants) ...[
              const Divider(),
              const SizedBox(height: 16),
              // --- Campo Quantità e Prezzo Acquisto (affiancati) ---
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'N. Pezzi'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceController,
                      decoration: const InputDecoration(labelText: 'Prezzo Acquisto (€)'),
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