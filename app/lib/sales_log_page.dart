import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/edit_sale_dialog.dart';
import 'package:eclettico/empty_state_widget.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:eclettico/snackbar_helper.dart';
import 'package:intl/intl.dart';

class SalesLogPage extends StatefulWidget {
  final List salesLog;
  final List allPlatforms;
  final List variants;
  final Map<String, dynamic> item;

  const SalesLogPage({
    super.key,
    required this.salesLog,
    required this.allPlatforms,
    required this.variants,
    required this.item,
  });

  @override
  State<SalesLogPage> createState() => _SalesLogPageState();
}

class _SalesLogPageState extends State<SalesLogPage> {
  late List _currentSalesLog;
  late List _currentVariants;
  late Map<String, dynamic> _currentItem;
  bool _dataDidChange = false;

  @override
  void initState() {
    super.initState();
    _currentSalesLog = List.from(widget.salesLog);
    _currentVariants = List.from(widget.variants);
    _currentItem = Map.from(widget.item);
  }

  Future<void> _refreshData() async {
    _dataDidChange = true;
    Navigator.pop(context, _dataDidChange);
  }

  void _showError(String message) {
    if (mounted) {
      showFloatingSnackBar(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definiamo un colore per il prezzo (verde soldi o il primario dell'app)
    final priceColor = Colors.greenAccent[400];

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Storico Vendite')),
        body: _currentSalesLog.isEmpty
            ? const EmptyStateWidget(
                icon: Iconsax.receipt_1,
                title: 'Nessuna Vendita',
                subtitle:
                    'Non hai ancora registrato nessuna vendita per questo articolo.',
              )
            : AnimationLimiter(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _currentSalesLog.length,
                  itemBuilder: (context, index) {
                    final sale = _currentSalesLog[index];
                    
                    // --- DATI ---
                    final String platformName = sale['platform_name'] ?? 'Piattaforma sconosciuta';
                    final String? variantName = sale['variant_name'];
                    final String? userName = sale['sold_by_user'];
                    final int quantity = sale['quantity_sold'] ?? 0;
                    final double totalPrice = double.tryParse(sale['total_price'].toString()) ?? 0.0;
                    
                    // Formattazione Data estesa (es. 12/10/2024)
                    // Se vuoi "12 Ottobre 2024", usa DateFormat('dd MMMM yyyy', 'it_IT') (richiede locale inizializzato)
                    // Per ora usiamo un formato chiaro numerico o standard
                    String formattedDate = 'Data sconosciuta';
                    if (sale['sale_date'] != null) {
                       final dateObj = DateTime.parse(sale['sale_date']);
                       formattedDate = DateFormat('dd/MM/yyyy').format(dateObj);
                    }

                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Card(
                            elevation: 4, // Un po' più di ombra per staccare
                            margin: const EdgeInsets.only(bottom: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                // --- LOGICA CLICK (Copiata dal tuo codice originale) ---
                                int? currentStock;
                                final int? saleVariantId = (sale['variant_id'] as num?)?.toInt();

                                if (saleVariantId != null) {
                                  final matchingVariant = _currentVariants.firstWhere(
                                    (v) => (v['variant_id'] as num?)?.toInt() == saleVariantId,
                                    orElse: () => null,
                                  );
                                  if (matchingVariant != null) {
                                    currentStock = (matchingVariant['quantity'] as num?)?.toInt();
                                  }
                                } else {
                                  if (_currentItem['has_variants'] == 0) {
                                    currentStock = (_currentItem['quantity'] as num?)?.toInt();
                                  } else {
                                    currentStock = null;
                                  }
                                }

                                if (currentStock == null) {
                                  _showError('Errore: Stock non trovato (articolo/variante inesistente?).');
                                  return;
                                }

                                final bool? dataChanged = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context).viewInsets.bottom,
                                    ),
                                    child: EditSaleDialog(
                                      sale: sale,
                                      allPlatforms: widget.allPlatforms,
                                      currentStock: currentStock!,
                                    ),
                                  ),
                                );

                                if (dataChanged == true) {
                                  _refreshData();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20.0), // SPAZIOSO
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // --- COLONNA SX: Piattaforma, Variante, Data ---
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Riga Piattaforma con Icona
                                          Row(
                                            children: [
                                              Icon(Iconsax.shop, size: 18, color: Colors.grey[400]),
                                              const SizedBox(width: 8),
                                              Text(
                                                platformName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (variantName != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Variante: $variantName',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            'Venduto il $formattedDate',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // --- COLONNA CENTRALE: Dettagli Quantità e Utente ---
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Quantità venduta',
                                            style: TextStyle(
                                              fontSize: 12, 
                                              color: Colors.grey[500]
                                            ),
                                          ),
                                          Text(
                                            '$quantity ${quantity == 1 ? "pezzo" : "pezzi"}',
                                            style: const TextStyle(fontSize: 15),
                                          ),
                                          if (userName != null && userName.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Venditore',
                                              style: TextStyle(
                                                fontSize: 12, 
                                                color: Colors.grey[500]
                                              ),
                                            ),
                                            Text(
                                              userName,
                                              style: const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                    // --- COLONNA DX: PREZZO (HERO) ---
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'TOTALE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '€ ${totalPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 22, // Molto grande
                                            fontWeight: FontWeight.bold,
                                            color: priceColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Icona edit piccola e discreta sotto il prezzo
                                        Icon(
                                          Iconsax.edit_2,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
