// lib/sales_log_page.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:eclettico/edit_sale_dialog.dart';
import 'package:eclettico/api_config.dart'; // Ci serve per kBaseUrl

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
  // Teniamo traccia dei dati qui
  late List _currentSalesLog;
  late List _currentVariants;
  late Map<String, dynamic> _currentItem;
  bool _dataDidChange = false; // Flag per notificare la pagina precedente

  @override
  void initState() {
    super.initState();
    _currentSalesLog = List.from(widget.salesLog);
    _currentVariants = List.from(widget.variants);
    _currentItem = Map.from(widget.item);
  }

  // Funzione per ricaricare TUTTO (chiamata dopo una modifica)
  Future<void> _refreshData() async {
    // Per ora ricarichiamo i dati simulando le chiamate
    // (In futuro potremmo voler passare le funzioni di refresh)
    // NOTA: Questa è una simulazione, l'ideale sarebbe avere un provider
    // o passare la funzione di refresh da item_detail_content.
    
    // Dato che non possiamo ricaricare i dati dall'API qui,
    // impostiamo solo il flag e chiudiamo la pagina.
    _dataDidChange = true;
    Navigator.pop(context, _dataDidChange);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color availableColor = Colors.green[500]!;

    return PopScope(
      // Notifica la pagina precedente se i dati sono cambiati
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _dataDidChange);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Storico Vendite'),
        ),
        body: _currentSalesLog.isEmpty
            ? const Center(
                child: Text('Nessuna vendita registrata.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _currentSalesLog.length,
                itemBuilder: (context, index) {
                  final sale = _currentSalesLog[index];
                  String title = sale['platform_name'] ?? 'N/D';
                  if (sale['variant_name'] != null) {
                    title = '${sale['variant_name']} / $title';
                  }
                  String date =
                      sale['sale_date']?.split('T')[0] ?? 'Data sconosciuta';

                  return Card(
                    color: Theme.of(context).cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: Icon(Iconsax.coin, color: availableColor),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Data: $date | Q.tà: ${sale['quantity_sold']} | Totale: € ${sale['total_price']}',
                      ),
                      trailing: Icon(
                        Iconsax.edit,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () async {
                        // --- Logica per trovare lo stock (presa da item_detail_content) ---
                        int? currentStock;
                        final int? saleVariantId =
                            (sale['variant_id'] as num?)?.toInt();

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
                        // --- Fine logica stock ---

                        final bool? dataChanged = await showDialog(
                          context: context,
                          builder: (context) => ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: EditSaleDialog(
                              sale: sale,
                              allPlatforms: widget.allPlatforms,
                              currentStock: currentStock!,
                            ),
                          ),
                        );
                        if (dataChanged == true) {
                          // Se una vendita è stata modificata o eliminata,
                          // forza l'aggiornamento.
                          _refreshData();
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}