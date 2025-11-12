import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/item_detail_page.dart';
import 'package:eclettico/api_config.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:eclettico/snackbar_helper.dart';

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
  bool _isUsed = false; // MODIFICA: Default impostato a 'false' (Nuovo)

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
        _isUsed = item['is_used'] == 1 || item['is_used'] == true;
        _valueController.text = item['value']?.toString() ?? '';
        _salePriceController.text = item['sale_price']?.toString() ?? '';
        _hasVariants = item['has_variants'] == 1;

        if (item['platforms'] != null) {
          _selectedPlatformIds.clear();
          _selectedPlatformIds.addAll(List<int>.from(item['platforms']));
        }

        if (_hasVariants) {
          try {
            // Chiamiamo l'endpoint che già usiamo nella pagina di dettaglio
            final variantsUrl = '$kBaseUrl/api/items/${widget.itemId}/variants';
            final variantsResponse = await http.get(Uri.parse(variantsUrl));

            if (variantsResponse.statusCode == 200) {
              final variants = jsonDecode(variantsResponse.body);
              if (mounted) {
                _variantCount = variants.length;
              }
            }
          } catch (e) {
            _variantCount = -1; // Usiamo -1 come flag di errore
          }
        } else {
          _variantCount = 0; // Se non ha varianti, il conteggio è 0
        }

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
          _isCheckingVariants = false;
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

    final String cleanName = _nameController.text.toUpperCase();

    final String cleanBrand = _brandController.text.trim().toUpperCase();

    final body = {
      "name": cleanName,
      "category_id": _selectedCategoryId,
      "description": _descriptionController.text,
      "is_used": _isUsed,
      "brand": cleanBrand,
      "value": double.tryParse(_valueController.text.replaceAll(',', '.')),
      "sale_price": double.tryParse(
        _salePriceController.text.replaceAll(',', '.'),
      ),
      "has_variants": _hasVariants,
      "quantity": _hasVariants ? null : int.tryParse(_quantityController.text),
      "purchase_price":
          _hasVariants
              ? null
              : double.tryParse(
                _purchasePriceController.text.replaceAll(',', '.'),
              ),
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
        const url = '$kBaseUrl/api/items';
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          if (!_isEditMode && response.statusCode == 201) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            final int newItemId = responseData['newItemId'];

            _navigateToNewItemDetail(newItemId);
          } else {
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

  void _navigateToNewItemDetail(int itemId) async {
    Navigator.pop(context, true);

    try {
      final url = '$kBaseUrl/api/items/$itemId';
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final itemData = jsonDecode(response.body);

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
      showFloatingSnackBar(context, message, isError: true);
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
          _isEditMode ? 'Modifica' : 'Aggiungi Articolo',
        ),
        centerTitle: true,
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
                    : const Icon(Iconsax.save_2),
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
                : Form(key: _formKey, child: _buildFormList()),
      ),
    );
  }

  Widget _buildFormList() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      cacheExtent: 600,
      children: [
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
        SwitchListTile.adaptive(
          title: const Text('L\'articolo è USATO?'),
          value: _isUsed,
          onChanged: (bool value) {
            HapticFeedback.lightImpact();
            setState(() {
              _isUsed = value;
            });
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Descrizione'),
          textInputAction: TextInputAction.newline,
          autofocus: false,
          enableSuggestions: true,
          autocorrect: true,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(labelText: 'Valore (€)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _salePriceController,
                decoration: const InputDecoration(labelText: 'Vendita (€)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // MODIFICA: Spostato il Divider qui (da sotto)
        const Divider(),
        const SizedBox(height: 16),

        SwitchListTile.adaptive(
          title: const Text('L\'articolo ha varianti?'),
          value: _hasVariants,
          onChanged: (bool value) {
            
            if (_isEditMode && !value) {
              if (_variantCount > 0) {
                _showError(
                  'Non puoi disattivare le varianti. Ci sono $_variantCount varianti collegate.',
                );
                return;
              }

              if (_variantCount == -1) {
                _showError(
                  'Errore nel verificare le varianti. Impossibile modificare.',
                );
                return;
              }
            }

            HapticFeedback.lightImpact();

            setState(() {
              _hasVariants = value;
            });
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),

        if (!_hasVariants) ...[
          // MODIFICA: Divider rimosso da qui
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('Piattaforme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // MODIFICA: Sostituito il vecchio widget con i nuovi Chip
          _buildPlatformChips(),
        ],
      ],
    );
  }

  // MODIFICA: Nuovo widget per le Piattaforme (sostituisce _PlatformsSection)
  Widget _buildPlatformChips() {
    if (_platforms.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8.0, // Spazio orizzontale tra i chip
      runSpacing: 4.0, // Spazio verticale tra le righe
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
              // Stile per farlo sembrare più "moderno"
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.3),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              showCheckmark: true,
              side:
                  isSelected
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey[700]!),
            );
          }).toList(),
    );
  }
}

Widget _buildFormSkeleton() {
  final Color baseColor = Colors.grey[850]!;
  final Color highlightColor = Colors.grey[700]!;

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

  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    period: const Duration(milliseconds: 1200),
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
