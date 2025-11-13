import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/snackbar_helper.dart';

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

    // 1. GESTIONE PIATTAFORMA
    // Recuperiamo l'ID grezzo e assicuriamo che sia un int pulito
    final rawSalePlatformId = widget.sale['platform_id'];
    if (rawSalePlatformId != null) {
      _selectedPlatformId = int.tryParse(rawSalePlatformId.toString());

      // DEBUG (Opzionale): Controlla se l'ID esiste nella lista delle piattaforme
      // Se questo ID non esiste in widget.allPlatforms, il dropdown apparirà vuoto.
      // bool exists = widget.allPlatforms.any((p) => int.parse(p['platform_id'].toString()) == _selectedPlatformId);
      // if (!exists) _selectedPlatformId = null;
    }

    // 2. GESTIONE QUANTITÀ E STOCK
    // Inizializziamo il controller della quantità
    String currentSoldStr = widget.sale['quantity_sold']?.toString() ?? '1';
    _quantityController.text = currentSoldStr;

    // Calcoliamo il massimo disponibile:
    // È lo stock attuale in magazzino (currentStock) + quello che "liberiamo" modificando questa vendita (quantity_sold attuale)
    int currentSoldQty = int.tryParse(currentSoldStr) ?? 0;
    _maxAvailableQuantity = widget.currentStock + currentSoldQty;

    // 3. GESTIONE PREZZO E UTENTE
    _priceController.text = widget.sale['total_price']?.toString() ?? '0';
    _userController.text = widget.sale['sold_by_user'] ?? '';

    // 4. GESTIONE DATA (Fix Principale)
    if (widget.sale['sale_date'] != null) {
      _selectedDate = DateTime.parse(widget.sale['sale_date']);
    } else {
      _selectedDate = DateTime.now();
    }
    // AGGIUNTA FONDAMENTALE: Aggiorna il testo visibile nel campo input
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
  }

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
      "total_price": double.tryParse(
        _priceController.text.replaceAll(',', '.'),
      ),
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
      showFloatingSnackBar(context, message, isError: true);
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
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    // --- COSTRUZIONE DEL CONTENUTO (STILE MODALE) ---
    Widget content = GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        width: isDesktop ? 500 : double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Maniglia
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Intestazione
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Modifica Vendita',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _deleteSale,
                  icon: Icon(
                    Iconsax.trash,
                    color: _isLoading ? Colors.grey : Colors.red,
                  ),
                  tooltip: 'Elimina Vendita',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Piattaforma',
                        ),
                        value:
                            _selectedPlatformId, // Qui ora il valore è sicuro
                        items:
                            widget.allPlatforms.map<DropdownMenuItem<int>>((
                              platform,
                            ) {
                              // Assicuriamo conversione pulita in int
                              final int pId = int.parse(
                                platform['platform_id'].toString(),
                              );
                              return DropdownMenuItem<int>(
                                value: pId,
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

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantità',
                                suffixText: '/ $_maxAvailableQuantity',
                                suffixStyle: TextStyle(color: Colors.grey),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Obbl.';
                                final int? enteredQuantity = int.tryParse(
                                  value,
                                );
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
                                labelText: 'Totale (€)',
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
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
                      const SizedBox(height: 32),

                      // Bottone Salva Modale
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitUpdate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                          ),
                          icon:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                  : const Icon(Iconsax.save_2),
                          label: const Text(
                            'Salva Modifiche',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // --- CHIUSURA SU CLICK ESTERNO ---
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(type: MaterialType.transparency, child: content),
      ),
    );
  }
}
