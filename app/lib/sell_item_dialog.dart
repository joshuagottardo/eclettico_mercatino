import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:eclettico/api_config.dart';
import 'package:flutter/services.dart';
import 'package:action_slider/action_slider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/snackbar_helper.dart';

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

  List _platforms = [];

  int? _selectedPlatformId;
  int? _selectedVariantId;
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _userController = TextEditingController();
  final _sliderController = ActionSliderController();
  final _audioPlayer = AudioPlayer();

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

  // Modifichiamo la funzione per accettare il controller dello slider
  Future<void> _submitSale() async {
    // 1. Validazione preliminare
    if (!_formKey.currentState!.validate()) {
      _sliderController.reset(); // Resetta lo slider se il form non è valido
      return;
    }
    if (_selectedPlatformId == null) {
      _sliderController.reset();
      _showError('Seleziona una piattaforma');
      return;
    }
    if (widget.hasVariants && _selectedVariantId == null) {
      _sliderController.reset();
      _showError('Seleziona la variante venduta');
      return;
    }

    // 2. Avvia stato di caricamento sullo slider
    _sliderController.loading();

    final body = {
      "item_id": widget.itemId,
      "variant_id": _selectedVariantId,
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
      const url = '$kBaseUrl/api/sales';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        // --- SUCCESSO! ---

        // 1. Feedback Aptico Pesante
        HapticFeedback.heavyImpact();

        // 2. Suono di Cassa (opzionale, se il file esiste)
        try {
          await _audioPlayer.play(AssetSource('sounds/cash.mp3'));
        } catch (_) {
          // Ignora errori audio se il file non c'è
        }

        // 3. Mostra stato successo sullo slider
        _sliderController.success();

        // 4. Aspetta un attimo per far godere l'animazione all'utente
        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) Navigator.pop(context, true);
      } else {
        // Errore Server
        _sliderController.reset(); // Torna indietro
        HapticFeedback.vibrate();
        final error = jsonDecode(response.body);
        _showError(error['error'] ?? 'Errore server: ${response.statusCode}');
      }
    } catch (e) {
      // Errore Rete
      _sliderController.reset();
      HapticFeedback.vibrate();
      _showError('Errore di rete: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      showFloatingSnackBar(context, message, isError: true);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _userController.dispose();
    _dateController.dispose();
    _sliderController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = (MediaQuery.of(context).size.width * 0.9).clamp(
      0.0,
      500.0,
    );

    return AlertDialog(
      backgroundColor: const Color(
        0xFF1E1E1E,
      ), // O Colors.transparent se usi GlassDialog
      title: const Text('Registra Vendita'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          // Rimosso il controllo _isLoading, ora lo slider gestisce il loading
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Piattaforme ---
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Piattaforma'),

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

                // --- Varianti (Condizionale) ---
                if (widget.hasVariants)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Variante'),

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
                                      : int.tryParse(q?.toString() ?? '') ?? 0;
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
                          final selectedVariant = widget.variants.firstWhere(
                            (v) => v['variant_id'] == value,
                            orElse: () => null,
                          );
                          _maxAvailableQuantity =
                              (selectedVariant?['quantity'] as num?)?.toInt();
                        } else {
                          _maxAvailableQuantity = null;
                        }
                        _formKey.currentState
                            ?.validate(); // Riconvalida il form
                      });
                    },
                    validator: (value) => value == null ? 'Obbligatorio' : null,
                  ),

                if (widget.hasVariants) const SizedBox(height: 16),

                // --- Quantità e Prezzo ---
                Row(
                  children: [
                    Expanded(
                      //  Campo Quantità
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(labelText: 'Quantità'),
                        keyboardType: TextInputType.number,

                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Obbl.';
                          }
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

                const SizedBox(height: 24),

                ActionSlider.standard(
                  controller: _sliderController,
                  width: dialogWidth - 32,
                  height: 50.0, // <-- 1. PIÙ BASSO (Default era ~70)
                  backgroundColor: const Color(0xFF333333),

                  // 2. COLORE VERDE (Toggle/Cursore)
                  toggleColor: Colors.green[600],

                  // 3. Icona bianca (per contrasto col verde)
                  icon: const Icon(Iconsax.money_send, color: Colors.white),

                  loadingIcon: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  successIcon: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                  ),
                  action: (controller) async {
                    await _submitSale();
                  },
                  child: Text(
                    'Scorri per vendere',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        // Manteniamo solo "Annulla", il tasto "Registra" è sostituito dallo slider
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
