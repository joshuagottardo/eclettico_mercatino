import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/snackbar_helper.dart';

class AddVariantPage extends StatefulWidget {
  final int itemId;

  final int? variantId;

  const AddVariantPage({super.key, required this.itemId, this.variantId});

  @override
  State<AddVariantPage> createState() => _AddVariantPageState();
}

class _AddVariantPageState extends State<AddVariantPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Dati per Piattaforme
  List _platforms = [];
  bool _platformsLoading = true;
  final Set<int> _selectedPlatformIds = {};
  bool _isLoading = false; // Per il salvataggio
  bool _isPageLoading = false; // Per il caricamento iniziale
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _fetchPlatforms();

    if (widget.variantId != null) {
      _isEditMode = true;
      _isPageLoading = true;
      _loadVariantData();
    }
  }

  //  Funzione per caricare i dati della variante
  Future<void> _loadVariantData() async {
    try {
      final url = '$kBaseUrl/api/variants/${widget.variantId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final variant = jsonDecode(response.body);
        if (mounted) {
          // Popoliamo i controller
          _nameController.text = variant['variant_name'] ?? '';

          _purchasePriceController.text =
              variant['purchase_price']?.toString() ?? '';
          _quantityController.text = variant['quantity']?.toString() ?? '';
          _descriptionController.text = variant['description'] ?? '';

          // Popoliamo le piattaforme
          if (variant['platforms'] != null) {
            _selectedPlatformIds.clear();
            _selectedPlatformIds.addAll(List<int>.from(variant['platforms']));
          }
        }
      } else {
        _showError('Errore nel caricare i dati della variante');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    }
  }

  // Funzione per caricare le piattaforme
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
      }
    } catch (e) {
      _showError('Errore caricamento piattaforme');
    } finally {
      if (mounted) {
        setState(() {
          _platformsLoading = false;
        });
      }
    }
  }

  // (Rinominata in _submitForm
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final body = {
      "variant_name": _nameController.text,
      "purchase_price": double.tryParse(
        _purchasePriceController.text.replaceAll(',', '.'),
      ),
      "quantity": int.tryParse(_quantityController.text),
      "description": _descriptionController.text,
      "platforms": _selectedPlatformIds.toList(),
    };

    try {
      http.Response response;

      // Logica per POST (Crea) o PUT (Modifica)
      if (_isEditMode) {
        // --- MODALITÀ MODIFICA ---
        final url = '$kBaseUrl/api/variants/${widget.variantId}';
        response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      } else {
        // --- MODALITÀ CREAZIONE ---
        final url = '$kBaseUrl/api/items/${widget.itemId}/variants';
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
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

  // Funzione per eliminare la variante
  Future<void> _deleteVariant() async {
    // Chiedi conferma
    final bool? confirmed = await _showDeleteConfirmation();
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    }); // Usiamo lo stesso loader
    try {
      final url = '$kBaseUrl/api/variants/${widget.variantId}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
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

  //  Dialog di conferma eliminazione
  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Sei sicuro?'),
            content: const Text(
              'Vuoi davvero eliminare questa variante? L\'azione non è reversibile.',
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
  }

  void _showError(String message) {
    if (mounted) {
      showFloatingSnackBar(context, message, isError: true);
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

  @override
  Widget build(BuildContext context) {
    // Padding per la tastiera
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      // Rimuoviamo constraints di altezza fissa/massima forzata qui,
      // lasciamo che sia il contenuto a decidere.
      padding: EdgeInsets.only(
        bottom: bottomPadding + 16,
      ), // +16 per un po' di respiro sotto
      child: Column(
        mainAxisSize:
            MainAxisSize.min, // Fondamentale: occupa il minimo spazio verticale
        children: [
          // --- 1. INTESTAZIONE ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Maniglia
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Riga Titolo e Bottoni
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Titolo
                    Text(
                      _isEditMode ? 'Modifica' : 'Aggiungi Variante',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // Azioni
                    Row(
                      children: [
                        if (_isEditMode)
                          IconButton(
                            icon: const Icon(Iconsax.trash, color: Colors.red),
                            onPressed: _isLoading ? null : _deleteVariant,
                            tooltip: 'Elimina',
                          ),
                        // --- MODIFICA BOTTONE SALVA ---
                        IconButton(
                          icon:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Icon(
                                    Iconsax.save_2,
                                    // Usa il colore primario (o bianco) senza sfondo
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                          onPressed: _isLoading ? null : _submitForm,
                          tooltip: 'Salva',
                          // RIMOSSO: style: IconButton.styleFrom(...)
                        ),
                        // --- FINE MODIFICA ---
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // --- 2. CONTENUTO ---
          if (_isPageLoading || _platformsLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            // --- MODIFICA QUI: Flexible invece di Expanded ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) => v!.isEmpty ? 'Obbligatorio' : null,
                        textInputAction: TextInputAction.next,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: const InputDecoration(
                                labelText: 'N° Pezzi',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Obbl.' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              decoration: const InputDecoration(
                                labelText: 'Acquisto (€)',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) => v!.isEmpty ? 'Obbl.' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                        ),
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Piattaforme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._buildPlatformChips(),

                      // Spazio extra in fondo per staccare dai bordi
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // MODIFICA: Sostituito CheckboxListTile con FilterChip
  List<Widget> _buildPlatformChips() {
    if (_platforms.isEmpty) return [const SizedBox.shrink()];

    return [
      Wrap(
        spacing: 8.0, // Spazio orizzontale
        runSpacing: 4.0, // Spazio verticale
        children:
            _platforms.map((platform) {
              final platformId = platform['platform_id'] as int;
              final isSelected = _selectedPlatformIds.contains(platformId);

              return FilterChip(
                label: Text(platform['name'].toString()),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedPlatformIds.add(platformId);
                    } else {
                      _selectedPlatformIds.remove(platformId);
                    }
                  });
                },
                // Stile
                selectedColor: Theme.of(
                  context,
                ).colorScheme.primary.withAlpha(77),
                checkmarkColor: Theme.of(context).colorScheme.primary,
                showCheckmark: true,
                side:
                    isSelected
                        ? BorderSide.none
                        : BorderSide(color: Colors.grey[700]!),
              );
            }).toList(),
      ),
    ];
  }
}
