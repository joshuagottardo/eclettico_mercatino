import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/edit_sale_dialog.dart';
import 'package:eclettico/empty_state_widget.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:eclettico/snackbar_helper.dart';
import 'package:intl/intl.dart';
import 'package:eclettico/icon_helper.dart';

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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Storico Vendite')),
        body:
            _currentSalesLog.isEmpty
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
                      final String? variantName = sale['variant_name'];
                      final String? userName = sale['sold_by_user'];
                      final int quantity = sale['quantity_sold'] ?? 0;
                      final double totalPrice =
                          double.tryParse(sale['total_price'].toString()) ??
                          0.0;

                      // Icona
                      final String iconAsset = IconHelper.getPlatformIconPath(
                        sale['platform_id'],
                      );

                      // Formattazione Data
                      String formattedDate = '';
                      if (sale['sale_date'] != null) {
                        final dateObj = DateTime.parse(sale['sale_date']);
                        formattedDate = DateFormat(
                          'dd/MM/yyyy',
                        ).format(dateObj);
                      }

                      // Meta (Utente • Data)
                      final List<String> metaParts = [];
                      if (userName != null && userName.isNotEmpty)
                        metaParts.add(userName);
                      metaParts.add(formattedDate);
                      final String metaText = metaParts.join(' • ');

                      // --- LOGICA TITOLO/SOTTOTITOLO ---
                      String mainTitle;
                      String subTitle;

                      if (variantName != null && variantName.isNotEmpty) {
                        // CASO 1: C'è una variante
                        mainTitle = variantName; // Es: "Maglia Rossa XL"
                        subTitle = metaText; // Es: "Mario • 12/10/2024"
                      } else {
                        // CASO 2: Nessuna variante
                        mainTitle = metaText; // Es: "Mario • 12/10/2024"
                        subTitle =
                            ''; // Nessun sottotitolo (rimosso il nome piattaforma)
                      }

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: Card(
                              elevation: 0,
                              color: Theme.of(context).cardColor,
                              margin: const EdgeInsets.only(bottom: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: Colors.grey.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () async {
                                  // ... (TUA LOGICA ONTAP ORIGINALE) ...
                                  int? currentStock;
                                  final int? saleVariantId =
                                      (sale['variant_id'] as num?)?.toInt();

                                  if (saleVariantId != null) {
                                    final matchingVariant = _currentVariants
                                        .firstWhere(
                                          (v) =>
                                              (v['variant_id'] as num?)
                                                  ?.toInt() ==
                                              saleVariantId,
                                          orElse: () => null,
                                        );
                                    if (matchingVariant != null) {
                                      currentStock =
                                          (matchingVariant['quantity'] as num?)
                                              ?.toInt();
                                    }
                                  } else {
                                    if (_currentItem['has_variants'] == 0) {
                                      currentStock =
                                          (_currentItem['quantity'] as num?)
                                              ?.toInt();
                                    } else {
                                      currentStock = null;
                                    }
                                  }

                                  if (currentStock == null) {
                                    _showError('Errore: Stock non trovato.');
                                    return;
                                  }

                                  final bool? dataChanged =
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder:
                                            (context) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom:
                                                    MediaQuery.of(
                                                      context,
                                                    ).viewInsets.bottom,
                                              ),
                                              child: EditSaleDialog(
                                                sale: sale,
                                                allPlatforms:
                                                    widget.allPlatforms,
                                                currentStock: currentStock!,
                                              ),
                                            ),
                                      );

                                  if (dataChanged == true) {
                                    _refreshData();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // 1. ICONA PIATTAFORMA
                                      Container(
                                        width: 48,
                                        height: 48,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white.withOpacity(
                                                    0.05,
                                                  )
                                                  : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Image.asset(
                                          iconAsset,
                                          fit: BoxFit.contain,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Icon(
                                              Iconsax.shop,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      // 2. TESTI (Senza nome piattaforma)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .center, // Centra se c'è solo 1 riga
                                          children: [
                                            Text(
                                              mainTitle,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            // Mostriamo il sottotitolo SOLO se non è vuoto
                                            if (subTitle.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                subTitle,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // 3. PREZZO E QUANTITÀ
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '€ ${totalPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent[400],
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                          .withOpacity(0.1)
                                                      : Colors.black
                                                          .withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'x$quantity',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
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
