import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:app/api_config.dart';

class SellItemDialog extends StatefulWidget {
  final int itemId;
  final List variants;
  final List allPlatforms;
  final bool hasVariants;
  final int mainItemQuantity;

  const SellItemDialog({
    super.key,
    required this.itemId,
    required this.variants,
    required this.allPlatforms,
    required this.hasVariants,
    required this.mainItemQuantity,
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

  final TextEditingController _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  int? _maxAvailableQuantity;

  @override
  void initState() {
    super.initState();
    _fetchPlatforms();

    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

    if (!widget.hasVariants) {
      _maxAvailableQuantity = widget.mainItemQuantity;
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

  Future<void> _fetchPlatforms() async {
    try {
      const url = '$kBaseUrl/api/platforms';
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
      "sale_date": DateFormat('yyyy-MM-dd').format(_selectedDate),
      "quantity_sold": int.tryParse(_quantityController.text),
      "total_price": double.tryParse(_priceController.text),
      "sold_by_user":
          _userController.text.isNotEmpty ? _userController.text : null,
    };

    try {
      const url = '$kBaseUrl/api/sales';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
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
      title: const Text('Registra Vendita'),
      content: SizedBox(
        width: dialogWidth,
        child:
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

                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Data Vendita',
                          ),
                          onTap: () => _selectDate(context),
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
                                widget.variants
                                    // 1. Assicura che la lista sia di tipo Mappa
                                    .cast<Map<String, dynamic>>()
                                    // 2. Dichiara ESPLICITAMENTE il tipo di 'v'
                                    .where((Map<String, dynamic> v) {
                                      final q = v['quantity'];
                                      final qty =
                                          q is num
                                              ? q.toInt()
                                              : int.tryParse(
                                                    q?.toString() ?? '',
                                                  ) ??
                                                  0;
                                      return qty > 0;
                                    })
                                    // 3. Dichiara esplicitamente anche qui per coerenza
                                    .map<DropdownMenuItem<int>>((
                                      Map<String, dynamic> variant,
                                    ) {
                                      return DropdownMenuItem<int>(
                                        value: variant['variant_id'],
                                        // Mostra lo stock disponibile nel menu
                                        child: Text(
                                          '${variant['variant_name']} (Pz: ${variant['quantity']})',
                                        ),
                                      );
                                    })
                                    .toList(),
                            onChanged: (value) {
                              //  Aggiorna lo stock max
                              setState(() {
                                _selectedVariantId = value;
                                if (value != null) {
                                  final selectedVariant = widget.variants
                                      .firstWhere(
                                        (v) => v['variant_id'] == value,
                                        orElse: () => null,
                                      );
                                  _maxAvailableQuantity =
                                      (selectedVariant?['quantity'] as num?)
                                          ?.toInt();
                                } else {
                                  _maxAvailableQuantity = null;
                                }
                                _formKey.currentState
                                    ?.validate(); // Riconvalida il form
                              });
                            },
                            validator:
                                (value) =>
                                    value == null ? 'Obbligatorio' : null,
                          ),

                        if (widget.hasVariants) const SizedBox(height: 16),

                        // --- Quantità e Prezzo ---
                        Row(
                          children: [
                            Expanded(
                              //  Campo Quantità
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: InputDecoration(
                                  labelText: 'Quantità',
                                ),
                                keyboardType: TextInputType.number,

                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Obbl.';
                                  }
                                  final int? enteredQuantity = int.tryParse(
                                    value,
                                  );
                                  if (enteredQuantity == null) return 'Num.';
                                  if (enteredQuantity <= 0) return '> 0';

                                  if (_maxAvailableQuantity != null &&
                                      enteredQuantity >
                                          _maxAvailableQuantity!) {
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
                          controller: _userController,
                          decoration: const InputDecoration(
                            labelText: 'Utente (opzionale)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
      actions: [
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
