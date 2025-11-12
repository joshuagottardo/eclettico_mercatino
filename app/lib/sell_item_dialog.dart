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

  Future<void> _submitSale() async {
    // 1. Validazione preliminare
    if (!_formKey.currentState!.validate()) {
      _sliderController.reset();
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
        HapticFeedback.heavyImpact();
        try {
          await _audioPlayer.play(AssetSource('sounds/cash.mp3'));
        } catch (_) {}

        _sliderController.success();
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) Navigator.pop(context, true);
      } else {
        _sliderController.reset();
        HapticFeedback.vibrate();
        final error = jsonDecode(response.body);
        _showError(error['error'] ?? 'Errore server: ${response.statusCode}');
      }
    } catch (e) {
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    // MODIFICA 1: Controllo se siamo su uno schermo largo (Desktop/Dialog)
    // Se la larghezza è > 600, presumiamo sia un Dialog, quindi arrotondiamo tutto.
    final bool isDesktopDialog = MediaQuery.of(context).size.width > 600;

    // MODIFICA 2: Avvolgiamo tutto in Material per evitare il crash su Desktop
    return Material(
      type: MaterialType.transparency, // Mantiene i bordi arrotondati del Container figlio
      child: Center( // Center assicura che su Desktop il dialog stia al centro
        child: Container(
          // Se siamo su desktop, limitiamo la larghezza, altrimenti usa tutto lo spazio (BottomSheet)
          width: isDesktopDialog ? 500 : double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            // MODIFICA 3: Bordi adattivi (Tutti arrotondati su Desktop, solo sopra su Mobile)
            borderRadius: isDesktopDialog 
                ? BorderRadius.circular(24.0)
                : const BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Maniglia (Solo su mobile/bottom sheet ha senso visivo, ma la lasciamo per coerenza o la nascondiamo)
              if (!isDesktopDialog)
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
              
              // Spazio extra su desktop se togliamo la maniglia
              if (isDesktopDialog) const SizedBox(height: 8),

              Text(
                'Registra Vendita',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Piattaforma',
                          ),
                          items:
                              _platforms.map<DropdownMenuItem<int>>((platform) {
                                return DropdownMenuItem<int>(
                                  value: platform['platform_id'],
                                  child: Text(platform['name']),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  setState(() => _selectedPlatformId = value),
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

                        if (widget.hasVariants)
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Variante',
                            ),
                            items:
                                widget.variants
                                    .cast<Map<String, dynamic>>()
                                    .where((v) {
                                      final q = v['quantity'];
                                      final qty =
                                          q is num
                                              ? q.toInt()
                                              : int.tryParse(q?.toString() ?? '') ??
                                                  0;
                                      return qty > 0;
                                    })
                                    .map<DropdownMenuItem<int>>((variant) {
                                      return DropdownMenuItem<int>(
                                        value: variant['variant_id'],
                                        child: Text(
                                          '${variant['variant_name']} (Pz: ${variant['quantity']})',
                                        ),
                                      );
                                    })
                                    .toList(),
                            onChanged: (value) {
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
                                _formKey.currentState?.validate();
                              });
                            },
                            validator:
                                (value) => value == null ? 'Obbligatorio' : null,
                          ),

                        if (widget.hasVariants) const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: InputDecoration(labelText: 'Quantità'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Obbl.';
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
                                keyboardType: const TextInputType.numberWithOptions(
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

                        ActionSlider.standard(
                          controller: _sliderController,
                          height: 50.0,
                          backgroundColor: const Color(0xFF333333),
                          toggleColor: Colors.green[600],
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}