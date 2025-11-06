// lib/edit_sale_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:app/api_config.dart';

class EditSaleDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final List allPlatforms;
  final int currentStock;

  const EditSaleDialog({
    super.key,
    required this.sale,
    required this.allPlatforms,
    required this.currentStock,
  });

  @override
  State<EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends State<EditSaleDialog> {
  final TextEditingController _dateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  int? _selectedPlatformId;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _userController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int? _maxAvailableQuantity;

  @override
  void initState() {
    super.initState();
    _selectedPlatformId = widget.sale['platform_id'];
    _quantityController.text = widget.sale['quantity_sold']?.toString() ?? '1';
    _priceController.text = widget.sale['total_price']?.toString() ?? '0';
    _userController.text = widget.sale['sold_by_user'] ?? '';
    _selectedDate = DateTime.parse(widget.sale['sale_date']);
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

    // Calcola lo stock massimo
    // Stock attuale + Quantità già inclusa in questa vendita = Totale
    _maxAvailableQuantity =
        (widget.currentStock +
                (num.tryParse(widget.sale['quantity_sold'].toString()) ?? 0))
            .toInt();
  }

  // Funzione per MODIFICARE la vendita
  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlatformId == null) return;

    setState(() {
      _isLoading = true;
    });

    final body = {
      "platform_id": _selectedPlatformId,
      "sale_date": DateFormat('yyyy-MM-dd').format(_selectedDate),
      "quantity_sold": int.tryParse(_quantityController.text),
      "total_price": double.tryParse(_priceController.text),
      "sold_by_user":
          _userController.text.isNotEmpty ? _userController.text : null,
    };

    try {
      final url = '$kBaseUrl/api/sales/${widget.sale['sale_id']}';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (context.mounted) Navigator.pop(context, true);
      } else {
        // Mostra l'errore del server (es. "Quantità non valida")
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

  // Funzione per ELIMINARE la vendita
  Future<void> _deleteSale() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Sei sicuro?'),
            content: const Text(
              'Vuoi eliminare questa vendita? L\'articolo tornerà disponibile in magazzino.',
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
    if (confirmed != true) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final url = '$kBaseUrl/api/sales/${widget.sale['sale_id']}';
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 200) {
        if (context.mounted) Navigator.pop(context, true);
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
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _userController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = (MediaQuery.of(context).size.width * 0.9).clamp(
      0.0,
      500.0,
    );

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      title: const Text('Modifica Vendita'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Piattaforma'),
                value: _selectedPlatformId,
                items:
                    widget.allPlatforms.map<DropdownMenuItem<int>>((platform) {
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
                validator: (value) => value == null ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Data Vendita'),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              // --- Quantità e Prezzo ---
              Row(
                children: [
                  Expanded(
                    //  Campo Quantità
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantità',
                        //  Mostra lo stock
                        helperText:
                            _maxAvailableQuantity != null
                                ? 'Disponibili: $_maxAvailableQuantity'
                                : null,
                        helperStyle: TextStyle(color: Colors.grey[400]),
                      ),
                      keyboardType: TextInputType.number,
                      // Validatore
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Obbl.';
                        final int? enteredQuantity = int.tryParse(value);
                        if (enteredQuantity == null) return 'Num.';
                        if (enteredQuantity <= 0) return '> 0';

                        if (_maxAvailableQuantity != null &&
                            enteredQuantity > _maxAvailableQuantity!) {
                          return 'Max: $_maxAvailableQuantity';
                        }
                        return null;
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
        IconButton(
          onPressed: _isLoading ? null : _deleteSale,
          icon: Icon(
            Icons.delete_outline,
            color: _isLoading ? Colors.grey : Colors.red,
          ),
          tooltip: 'Elimina Vendita',
        ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitUpdate,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Salva Modifiche'),
        ),
      ],
    );
  }
}
