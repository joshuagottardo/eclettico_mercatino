// lib/statistics_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/api_config.dart';
import 'package:iconsax/iconsax.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _statsData = {};

  final Color _netProfitColor = Colors.green[500]!;
  final Color _spentColor = Colors.red[500]!;
  final Color _grossProfitColor = Colors.orange[400]!;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = '$kBaseUrl/api/statistics/summary';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _statsData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Errore di rete o API: $e';
        });
      }
      print('Errore caricamento statistiche: $e');
    }
  }

  // Formatta i numeri come valuta (es. 1234.56 -> € 1.234,56)
  String _formatCurrency(dynamic value) {
    if (value == null) return '€ 0.00';
    final double? amount = double.tryParse(value.toString());
    if (amount == null) return '€ N/D';
    
    // Un semplice formato con due decimali per il contesto (può essere migliorato con intl)
    return '€ ${amount.toStringAsFixed(2)}';
  }

  // FUNZIONE AGGIORNATA: Restituisce List<Widget> per l'uso nel ListView
  List<Widget> _buildProfitAndSpentBoxesWidgets() {
    final totals = _statsData['totals'] ?? {};
    final grossProfit = totals['gross_profit_total'];
    final netProfit = totals['net_profit_total'];
    final totalSpent = totals['total_spent'];

    return [
        // Riga 1: Netto e Lordo (Usa Row con Expanded all'interno)
        Row(
          children: [
            _buildStatCard(
              'GUADAGNO NETTO',
              _formatCurrency(netProfit),
              Iconsax.money_send,
              _netProfitColor,
              netProfit,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'GUADAGNO LORDO',
              _formatCurrency(grossProfit),
              Iconsax.archive_add,
              _grossProfitColor,
              grossProfit,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Riga 2: Spesa Totale (Card singola, usa Expanded all'interno per riempire la Row)
        Row(
            children: [
                _buildStatCard( // <-- NOTA: Ora è dentro una Row singola
                    'SPESA TOTALE (Costo)',
                    _formatCurrency(totalSpent),
                    Iconsax.card_slash,
                    _spentColor,
                    totalSpent,
                ),
            ],
        ),
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche Totali'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStatistics,
            tooltip: 'Aggiorna Statistiche',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _fetchStatistics,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Performance Finanziaria Totale',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // --- 1. BOX PRINCIPALI (Guadagni e Spesa) ---
                      // USA LO SPREAD OPERATOR per inserire i widget direttamente nel ListView
                      ..._buildProfitAndSpentBoxesWidgets(),
                      
                      const SizedBox(height: 32),

                      // --- 2. TOP PERFORMER (Brand e Categoria) ---
                      const Text(
                        'Articoli Più Venduti',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Questa funzione restituisce un Row che non ha Expanded al suo interno, quindi va bene
                      _buildTopPerformerSection(), 
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, dynamic rawValue) {
    final bool isNegative = (rawValue is num) && rawValue < 0;
    
    return Expanded( // Necessario per la Row genitore
      child: Card(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 24, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: isNegative ? Colors.red[700] : color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopPerformerSection() {
    final topCategory = _statsData['topCategory'];
    final topBrand = _statsData['topBrand'];

    return Row(
      children: [
        _buildTopCard(
          title: 'CATEGORIA PIÙ VENDUTA',
          name: topCategory?['category_name'] ?? 'N/D',
          count: topCategory?['sales_count'] ?? 0,
          icon: Iconsax.category,
        ),
        const SizedBox(width: 16),
        _buildTopCard(
          title: 'BRAND PIÙ VENDUTO',
          name: topBrand?['brand'] ?? 'N/D',
          count: topBrand?['sales_count'] ?? 0,
          icon: Iconsax.tag,
        ),
      ],
    );
  }

  Widget _buildTopCard({
    required String title,
    required String name,
    required int count,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        color: const Color(0xFF161616), // Sfondo scuro per risaltare
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$count pezzi venduti',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}