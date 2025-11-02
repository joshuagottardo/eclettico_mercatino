// lib/add_item_page.dart - AGGIORNATO CON NAVIGAZIONE AL DETTAGLIO

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// Importiamo le pagine necessarie
import 'package:app/item_detail_page.dart';
import 'package:app/api_config.dart';
import 'package:shimmer/shimmer.dart';

class AddItemPage extends StatefulWidget {
  final int? itemId;
  const AddItemPage({super.key, this.itemId});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  static bool _globalHasWarmedUp = false;
  final _formKey = GlobalKey<FormState>();

  // Controller
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _valueController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();

  // Dati per Categorie
  List _categories = [];
  int? _selectedCategoryId;
  bool _categoriesLoading = true;

  // Dati per Piattaforme
  List _platforms = [];
  bool _platformsLoading = true;
  final Set<int> _selectedPlatformIds = {};

  // Variabili di stato
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isPageLoading = false;
  bool _hasVariants = false;

  int _variantCount = 0;
  bool _isCheckingVariants = false;
  bool _isWarmingUp = !_globalHasWarmedUp;

  @override
  void initState() {
    super.initState();
    _nameController.text = '';
    _fetchInitialData();
    if (widget.itemId != null) {
      _isEditMode = true;
      _isPageLoading = true;
      _loadItemData();
    }

    if (_isWarmingUp) {
      _startWarmUp();
    }
  }

  void _startWarmUp() async {
    // Aspettiamo 500ms.
    // I  log dicono "timeout: 0.250000", quindi 500ms
    // dovrebbero bastare per coprire quel lag.
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isWarmingUp = false;
      });
      _globalHasWarmedUp = true;
    }
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchCategories(), _fetchPlatforms()]);
  }

  Future<void> _fetchCategories() async {
    try {
      const url = '$kBaseUrl/api/categories';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _categories = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      _showError('Errore caricamento categorie');
    } finally {
      if (mounted) {
        setState(() {
          _categoriesLoading = false;
        });
      }
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

  Future<void> _loadItemData() async {
    // (FIX) Imposta il flag di controllo varianti se siamo in Edit Mode
    if (_isEditMode) {
      setState(() {
        _isCheckingVariants = true;
      });
    }

    try {
      final url = '$kBaseUrl/api/items/${widget.itemId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final item = jsonDecode(response.body);

        _nameController.text = item['name'] ?? '';
        _selectedCategoryId = item['category_id'];
        _descriptionController.text = item['description'] ?? '';
        _brandController.text = item['brand'] ?? '';
        _valueController.text = item['value']?.toString() ?? '';
        _salePriceController.text = item['sale_price']?.toString() ?? '';
        _hasVariants = item['has_variants'] == 1;

        if (item['platforms'] != null) {
          _selectedPlatformIds.clear();
          _selectedPlatformIds.addAll(List<int>.from(item['platforms']));
        }

        // --- (FIX) NUOVA LOGICA: Carica il conteggio varianti ---
        if (_hasVariants) {
          try {
            // Chiamiamo l'endpoint che già usiamo nella pagina di dettaglio
            final variantsUrl = '$kBaseUrl/api/items/${widget.itemId}/variants';
            final variantsResponse = await http.get(Uri.parse(variantsUrl));

            if (variantsResponse.statusCode == 200) {
              final variants = jsonDecode(variantsResponse.body);
              if (mounted) {
                _variantCount = variants.length; // Salviamo il conteggio
              }
            }
          } catch (e) {
            _variantCount = -1; // Usiamo -1 come flag di errore
          }
        } else {
          _variantCount = 0; // Se non ha varianti, il conteggio è 0
        }
        // --- FINE FIX ---

        if (!_hasVariants) {
          _quantityController.text = item['quantity']?.toString() ?? '';
          _purchasePriceController.text =
              item['purchase_price']?.toString() ?? '';
        }
      } else {
        _showError('Errore nel caricare i dati dell\'articolo');
      }
    } catch (e) {
      _showError('Errore di rete: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
          _isCheckingVariants = false; // (FIX) Resetta il flag
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showError('Per favore, seleziona una categoria');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final body = {
      "name": _nameController.text,
      "category_id": _selectedCategoryId,
      "description": _descriptionController.text,
      "brand": _brandController.text,
      "value": double.tryParse(_valueController.text),
      "sale_price": double.tryParse(_salePriceController.text),
      "has_variants": _hasVariants,
      "quantity": _hasVariants ? null : int.tryParse(_quantityController.text),
      "purchase_price":
          _hasVariants ? null : double.tryParse(_purchasePriceController.text),
      "platforms": _selectedPlatformIds.toList(),
    };

    try {
      http.Response response;
      if (_isEditMode) {
        final url = '$kBaseUrl/api/items/${widget.itemId}';
        response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      } else {
        // --- LOGICA DI CREAZIONE ---
        const url = '$kBaseUrl/api/items';
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // (1 - NUOVA LOGICA) Se l'articolo è stato creato, naviga alla sua pagina
          if (!_isEditMode && response.statusCode == 201) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            final int newItemId = responseData['newItemId'];

            // Reperiamo l'articolo appena creato per avere tutti i dati
            _navigateToNewItemDetail(newItemId);
          } else {
            // Se è una MODIFICA, torniamo alla pagina precedente (dettaglio)
            Navigator.pop(context, true);
          }
        }
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

  // (2 - NUOVA FUNZIONE) Prende il nuovo ID e naviga al dettaglio
  void _navigateToNewItemDetail(int itemId) async {
    // Prima, chiudi la pagina di aggiunta
    Navigator.pop(context, true);

    // Poi, naviga al dettaglio dell'articolo appena creato
    // Usiamo una rotta 'GET /api/items/:id' per prelevare i dati completi
    try {
      final url = '$kBaseUrl/api/items/$itemId';
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final itemData = jsonDecode(response.body);

        // Naviga alla pagina di dettaglio
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailPage(item: itemData),
          ),
        );
      } else {
        _showError('Articolo creato, ma errore nel caricare i dettagli.');
      }
    } catch (e) {
      _showError('Errore di rete dopo la creazione.');
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
    _descriptionController.dispose();
    _brandController.dispose();
    _valueController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Modifica Articolo' : 'Aggiungi Nuovo Articolo',
        ),
        actions: [
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
                    : const Icon(Icons.save),
            onPressed: _isLoading ? null : _submitForm,
            tooltip: 'Salva',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child:
            _isPageLoading ||
                    _categoriesLoading ||
                    _platformsLoading ||
                    _isCheckingVariants ||
                    _isWarmingUp
                ? _buildFormSkeleton()
                // (FIX) Avvolgi la lista in un Form e assegna la chiave
                : Form(
                  key: _formKey, // <-- Assegna la chiave qui
                  child: _buildFormList(),
                ),
      ),
    );
  }

  Widget _buildFormList() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      cacheExtent: 600, // pre-render di un po’ di contenuto
      children: [
        // ... (Campi modulo invariati, solo la logica di navigazione è cambiata)
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome'),
          validator: (v) => v!.isEmpty ? 'Obbligatorio' : null,
          textInputAction: TextInputAction.next,
          autofocus: true,
          enableSuggestions: false,
          autocorrect: false,
        ),

        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Categoria'),
          value: _selectedCategoryId,
          items:
              _categories.map<DropdownMenuItem<int>>((category) {
                return DropdownMenuItem<int>(
                  value: category['category_id'],
                  child: Text(category['name']),
                );
              }).toList(),
          onChanged:
              (value) => setState(() {
                _selectedCategoryId = value;
              }),
          validator: (value) => value == null ? 'Obbligatoria' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _brandController,
          decoration: const InputDecoration(labelText: 'Brand'),
          textInputAction: TextInputAction.next,
          autofocus: false,
          enableSuggestions: true,
          autocorrect: true,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Descrizione'),
          textInputAction: TextInputAction.next,
          autofocus: false,
          enableSuggestions: true,
          autocorrect: true,
          maxLines: 5,
        ),
        const SizedBox(height: 16),
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
                decoration: const InputDecoration(labelText: 'Vendita (€)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SwitchListTile.adaptive(
          title: const Text('L\'articolo ha varianti?'),
          subtitle: const Text(
            'Se sì, quantità e prezzi saranno gestiti per ogni variante',
          ),
          value: _hasVariants,
          onChanged: (bool value) {
            // (FIX) Logica aggiornata
            if (_isEditMode && !value) {
              // Se sto provando a DISATTIVARE

              if (_variantCount > 0) {
                _showError(
                  'Non puoi disattivare le varianti. Ci sono $_variantCount varianti collegate.',
                );
                return; // Blocca l'azione
              }

              if (_variantCount == -1) {
                // Flag di errore dal caricamento
                _showError(
                  'Errore nel verificare le varianti. Impossibile modificare.',
                );
                return; // Blocca l'azione
              }

              // Se _variantCount == 0, l'esecuzione prosegue
            }

            setState(() {
              _hasVariants = value;
            });
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),

        // --- CAMPI CONDIZIONALI (Quantità, Prezzo e Piattaforme) ---
        if (!_hasVariants) ...[
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'N° Pezzi'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(labelText: 'Acquisto (€)'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // (8 - NUOVO) Sezione Checkbox Piattaforme
          Text('Piattaforme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _PlatformsSection(
            platforms: _platforms,
            selectedIds: _selectedPlatformIds,
            onToggle: (platformId) {
              setState(() {
                if (_selectedPlatformIds.contains(platformId)) {
                  _selectedPlatformIds.remove(platformId);
                } else {
                  _selectedPlatformIds.add(platformId);
                }
              });
            },
          ),
        ],
      ],
    );
  }

  // (9 - NUOVO) Funzione Helper per costruire le checkbox
}

Widget _buildFormSkeleton() {
  final Color baseColor = Colors.grey[850]!; // Colore base scuro
  final Color highlightColor =
      Colors.grey[700]!; // Colore chiaro dell'animazione

  // Un widget helper per creare i box
  Widget buildSkeletonBox({
    double height = 58, // Altezza di un TextFormField
    double vPadding = 8.0,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: vPadding),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
    );
  }

  // Usiamo Shimmer.fromColors per applicare l'effetto
  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    period: const Duration(milliseconds: 1200), // Durata dell'animazione
    child: ListView(
      padding: const EdgeInsets.all(16.0),
      physics: const NeverScrollableScrollPhysics(), // Disabilita lo scroll
      children: [
        buildSkeletonBox(vPadding: 0), // Simula campo "Nome"
        buildSkeletonBox(), // Simula campo "Categoria"
        buildSkeletonBox(), // Simula campo "Brand"
        buildSkeletonBox(height: 120), // Simula "Descrizione" (maxLines: 5)
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: buildSkeletonBox(vPadding: 0)), // Simula "Valore"
            const SizedBox(width: 16),
            Expanded(child: buildSkeletonBox(vPadding: 0)), // Simula "Vendita"
          ],
        ),
        const SizedBox(height: 16),
        buildSkeletonBox(height: 70), // Simula lo Switch "Varianti"
      ],
    ),
  );
}

class _PlatformsSection extends StatefulWidget {
  final List platforms;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;

  const _PlatformsSection({
    required this.platforms,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  State<_PlatformsSection> createState() => _PlatformsSectionState();
}

class _PlatformsSectionState extends State<_PlatformsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.platforms.length,
        itemBuilder: (context, i) {
          final platform = widget.platforms[i];
          final platformId = platform['platform_id'] as int;
          final checked = widget.selectedIds.contains(platformId);
          return CheckboxListTile(
            title: Text(platform['name'].toString()),
            value: checked,
            onChanged: (bool? v) => widget.onToggle(platformId),
            activeColor: Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}
