import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';

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
  final Color _estimatedProfitColor = Colors.blue[400]!;

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

  String _formatCurrency(dynamic value) {
    if (value == null) return '€ 0.00';
    final double? amount = double.tryParse(value.toString());
    if (amount == null) return '€ N/D';

    return '€ ${amount.toStringAsFixed(2)}';
  }

  int _parseCount(dynamic countValue) {
    if (countValue == null) return 0;

    // Se è già un intero, usalo
    if (countValue is int) return countValue;

    // Se è una stringa, prova a convertirla
    if (countValue is String) {
      return int.tryParse(countValue) ?? 0;
    }

    // Se è un altro tipo di numero (es. double), convertilo
    if (countValue is num) {
      return countValue.toInt();
    }

    // Fallback
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _isLoading ? null : _fetchStatistics,
            tooltip: 'Aggiorna Statistiche',
          ),
        ],
      ),
      body:
          _isLoading
              ? _buildSkeletonLoader()
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                onRefresh: _fetchStatistics,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildResponsiveStatBoxes(),

                    const SizedBox(height: 32),

                    _buildResponsiveTopPerformers(),
                  ],
                ),
              ),
    );
  }

  // WIDGET REATTIVO PER I BOX STATISTICI
  Widget _buildResponsiveStatBoxes() {
    final totals = _statsData['totals'] ?? {};
    final grossProfit = totals['gross_profit_total'];
    final netProfit = totals['net_profit_total'];
    final totalSpent = totals['total_spent'];
    final estimatedProfit = totals['estimated_profit'];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double desktopBreakpoint = 900.0;

        if (constraints.maxWidth >= desktopBreakpoint) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatCard(
                  'VALORE MAGAZZINO',
                  _formatCurrency(estimatedProfit),
                  Iconsax.box,
                  _estimatedProfitColor,
                  estimatedProfit,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'MARGINE DI PROFITTO',
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
                const SizedBox(width: 16),
                _buildStatCard(
                  'SPESA TOTALE',
                  _formatCurrency(totalSpent),
                  Iconsax.card_slash,
                  _spentColor,
                  totalSpent,
                ),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  _buildStatCard(
                    'VALORE MAGAZZINO',
                    _formatCurrency(estimatedProfit),
                    Iconsax.box,
                    _estimatedProfitColor,
                    estimatedProfit,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              IntrinsicHeight(
                child: Row(
                  children: [
                    _buildStatCard(
                      'MARGINE DI PROFITTO',
                      _formatCurrency(netProfit),
                      Iconsax.money_send,
                      _netProfitColor,
                      netProfit,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'SPESA TOTALE',
                      _formatCurrency(totalSpent),
                      Iconsax.card_slash,
                      _spentColor,
                      totalSpent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  _buildStatCard(
                    'GUADAGNO LORDO',
                    _formatCurrency(grossProfit),
                    Iconsax.archive_add,
                    _grossProfitColor,
                    grossProfit,
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSkeletonLoader() {
    final Color baseColor = Colors.grey[850]!;
    final Color highlightColor = Colors.grey[700]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 24,
            width: 200,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    dynamic rawValue,
  ) {
    final bool isNegative = (rawValue is num) && rawValue < 0;

    return Expanded(
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
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

  Widget _buildTopPerformerCard({
    required String title,
    required String name,
    required int count,
    required IconData icon,
  }) {
    return Card(
      color: const Color(0xFF161616),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
    );
  }

  Widget _buildTopCategoryCard() {
    final topCategory = _statsData['topCategory'];
    return _buildTopPerformerCard(
      title: 'CATEGORIA PIÙ VENDUTA',
      name: topCategory?['category_name'] ?? 'N/D',
      count: _parseCount(topCategory?['sales_count']), // <-- FIX
      icon: Iconsax.category,
    );
  }

  Widget _buildTopBrandCard() {
    final topBrand = _statsData['topBrand'];
    return _buildTopPerformerCard(
      title: 'BRAND PIÙ VENDUTO',
      name: topBrand?['brand'] ?? 'N/D',
      count: _parseCount(topBrand?['sales_count']), // <-- FIX
      icon: Iconsax.tag,
    );
  }

  Widget _buildResponsiveTopPerformers() {
    return LayoutBuilder(
      builder: (context, constraints) {
        
        const double desktopBreakpoint = 900.0;

        if (constraints.maxWidth >= desktopBreakpoint) {
          
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTopCategoryCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildTopBrandCard()),
              ],
            ),
          );
        } else {
          
          return Column(
            children: [
              _buildTopCategoryCard(),
              const SizedBox(height: 16),
              _buildTopBrandCard(),
            ],
          );
        }
      },
    );
  }
}
