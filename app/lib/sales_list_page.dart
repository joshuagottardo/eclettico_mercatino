import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eclettico/api_config.dart';
import 'package:eclettico/icon_helper.dart';
import 'package:eclettico/item_detail_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum SortType { date, amount }

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  List _sales = [];
  bool _isLoading = true;
  SortType _currentSort = SortType.date;

  @override
  void initState() {
    super.initState();
    _fetchAllSales();
  }

  Future<void> _fetchAllSales() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$kBaseUrl/api/sales'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _sales = jsonDecode(response.body);
            _sortList(); // Applica l'ordinamento iniziale
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortList() {
    if (_currentSort == SortType.date) {
      _sales.sort((a, b) {
        DateTime dateA = DateTime.parse(a['sale_date']);
        DateTime dateB = DateTime.parse(b['sale_date']);
        return dateB.compareTo(dateA); // Dal più recente
      });
    } else {
      _sales.sort((a, b) {
        double priceA = double.tryParse(a['total_price'].toString()) ?? 0;
        double priceB = double.tryParse(b['total_price'].toString()) ?? 0;
        return priceB.compareTo(priceA); // Dal più alto
      });
    }
  }

  // --- FOGLIO DI STILE PER ORDINAMENTO ---
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), // Stesso colore scuro
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- MANIGLIA ---
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

                  // --- INTESTAZIONE ---
                  Text(
                    'Ordina per',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),

                  // --- OPZIONI ---
                  _buildRadioOption(
                    title: 'Data (Più recenti)',
                    icon: Iconsax.calendar_1,
                    value: SortType.date,
                    groupValue: _currentSort,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setSheetState(() => _currentSort = val!);
                      setState(() {
                        _currentSort = val!;
                        _sortList();
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildRadioOption(
                    title: 'Importo (Decrescente)',
                    icon: Iconsax.money_4,
                    value: SortType.amount,
                    groupValue: _currentSort,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setSheetState(() => _currentSort = val!);
                      setState(() {
                        _currentSort = val!;
                        _sortList();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioOption({
    required String title,
    required IconData icon,
    required SortType value,
    required SortType groupValue,
    required ValueChanged<SortType?> onChanged,
  }) {
    final isSelected = value == groupValue;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.white,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _goToItemDetail(int itemId) async {
    try {
      final url = '$kBaseUrl/api/items/$itemId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        final itemData = jsonDecode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailPage(item: itemData),
          ),
        );
      }
    } catch (e) {
      // Gestione silenziosa
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendite'),
        actions: [
          IconButton(
            icon: Icon(
              Iconsax.sort,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Ordina',
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _sales.isEmpty
              ? const Center(child: Text("Nessuna vendita registrata."))
              : AnimationLimiter(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];

                    // --- ESTRAZIONE DATI ---
                    final String itemName = sale['item_name'] ?? 'Articolo';
                    final String? variantName = sale['variant_name'];
                    final String? userName = sale['sold_by_user'];
                    final int quantity = sale['quantity_sold'] ?? 0;
                    final double totalPrice =
                        double.tryParse(sale['total_price'].toString()) ?? 0.0;

                    final String iconAsset = IconHelper.getPlatformIconPath(
                      sale['platform_id'],
                    );

                    String formattedDate = '';
                    if (sale['sale_date'] != null) {
                      final dateObj = DateTime.parse(sale['sale_date']);
                      formattedDate = DateFormat('dd/MM/yyyy').format(dateObj);
                    }

                    // Costruzione stringa "Data • Utente"
                    String dateUserMeta = formattedDate;
                    if (userName != null && userName.isNotEmpty) {
                      dateUserMeta = '$dateUserMeta • $userName';
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
                              onTap: () {
                                if (sale['item_id'] != null) {
                                  _goToItemDetail(sale['item_id']);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // 1. ICONA PIATTAFORMA (Senza sfondo)
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      // Rimosso il padding se l'SVG ha già i suoi spazi,
                                      // oppure lascialo se serve (padding: const EdgeInsets.all(8))
                                      child: SvgPicture.asset(
                                        iconAsset,
                                        fit: BoxFit.contain,
                                        // placeholderBuilder sostituisce errorBuilder per gli SVG
                                        placeholderBuilder: (
                                          BuildContext context,
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
                                    const SizedBox(width: 16),

                                    // 2. TESTI (Strutturati su righe diverse)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // RIGA 1: Nome Articolo
                                          Text(
                                            itemName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                          // RIGA 2: Variante (se esiste)
                                          if (variantName != null &&
                                              variantName.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2.0,
                                              ),
                                              child: Text(
                                                variantName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[400],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),

                                          // RIGA 3: Data e Utente
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Text(
                                              dateUserMeta,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
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
                                          style: GoogleFonts.inconsolata(
                                            // Font Inconsolata
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.greenAccent[400],
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
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white.withOpacity(
                                                      0.1,
                                                    )
                                                    : Colors.black.withOpacity(
                                                      0.05,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            quantity.toString(), // Solo numero
                                            style: const TextStyle(
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
    );
  }
}
