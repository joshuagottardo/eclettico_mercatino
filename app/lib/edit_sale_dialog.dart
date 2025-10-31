// lib/edit_sale_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class EditSaleDialog extends StatefulWidget {
  // (1) Riceviamo i dati della vendita e la lista delle piattaforme
  final Map<String, dynamic> sale;
  final List allPlatforms;

  const EditSaleDialog({
    super.key,
    required this.sale,
    required this.allPlatforms,
  });

  @override
  State<EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends State<EditSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // (2) Controller e valori
  int? _selectedPlatformId;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _userController = TextEditingController();
  // Per la data, è più complesso, usiamo DateTime
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // (3) Popoliamo i campi con i dati esistenti
    _selectedPlatformId = widget.sale['platform_id'];
    _quantityController.text = widget.sale['quantity_sold']?.toString() ?? '1';
    _priceController.text = widget.sale['total_price']?.toString() ?? '0';
    _userController.text = widget.sale['sold_by_user'] ?? '';
    _selectedDate = DateTime.parse(widget.sale['sale_date']);
  }

  // (4) Funzione per MODIFICARE la vendita
  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlatformId == null) return;

    setState(() { _isLoading = true; });

    final body = {
      "platform_id": _selectedPlatformId,
      "sale_date": DateFormat('yyyy-MM-dd').format(_selectedDate),
      "quantity_sold": int.tryParse(_quantityController.text),
      "total_price": double.tryParse(_priceController.text),
      "sold_by_user": _userController.text.isNotEmpty ? _userController.text : null,
    };

    try {
      final url = 'http://trentin-nas.synology.me:4000/api/sales/${widget.sale['sale_id']}';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true); // Successo!
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // (5) Funzione per ELIMINARE la vendita
  Future<void> _deleteSale() async {
    // Chiedi conferma
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Sei sicuro?'),
        content: const Text('Vuoi eliminare questa vendita? L\'articolo tornerà disponibile in magazzino.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sì, elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _isLoading = true; });
    try {
      final url = 'http://trentin-nas.synology.me:4000/api/sales/${widget.sale['sale_id']}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true); // Successo!
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
  
  // (6) Helper per mostrare il selettore data
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
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
      title: const Text('Modifica Vendita'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Piattaforma ---
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Piattaforma'),
                value: _selectedPlatformId,
                items: widget.allPlatforms.map<DropdownMenuItem<int>>((platform) {
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
              
              // --- Data ---
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Data Vendita',
                  suffixIcon: Icon(Icons.calendar_today)
                ),
                controller: TextEditingController(
                  text: DateFormat('dd/MM/yyyy').format(_selectedDate)
                ),
                readOnly: true, // Impedisce di scriverci
                onTap: () => _selectDate(context), // Apre il calendario al tocco
              ),
              const SizedBox(height: 16),

              // --- Quantità e Prezzo ---
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

              // --- Utente ---
              TextFormField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'Utente (opzionale)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // (7) Bottone Elimina
        IconButton(
          onPressed: _isLoading ? null : _deleteSale,
          icon: Icon(Icons.delete_outline, color: _isLoading ? Colors.grey : Colors.red),
          tooltip: 'Elimina Vendita',
        ),
        const Spacer(), // Spinge i bottoni ai lati
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitUpdate,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Salva Modifiche'),
        ),
      ],
    );
  }
}