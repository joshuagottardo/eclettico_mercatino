import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eclettico/api_config.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:eclettico/icon_helper.dart';

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
    if (countValue is int) return countValue;
    if (countValue is String) return int.tryParse(countValue) ?? 0;
    if (countValue is num) return countValue.toInt();
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
                    // --- UNICO BLOCCO DI CONTROLLO LAYOUT ---
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Breakpoints
                        const double wideDesktop = 1300.0;
                        const double tablet = 700.0;

                        if (constraints.maxWidth >= wideDesktop) {
                          return _buildWideDesktopLayout();
                        } else if (constraints.maxWidth >= tablet) {
                          return _buildTabletLayout();
                        } else {
                          return _buildMobileLayout();
                        }
                      },
                    ),
                    // ... altri widget sopra ...
                    const SizedBox(height: 32),

                    // --- GRAFICO (SEMPRE SOTTO) ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ANDAMENTO VENDITE (30 GIORNI)',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          color: const Color(0xFF1A1A1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _SalesTrendChart(
                              trendData: _statsData['salesTrend'] ?? [],
                              isLoaded: !_isLoading,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  // ---------------------------------------------------------------------------
  // LAYOUT BUILDERS
  // ---------------------------------------------------------------------------

  // 1. DESKTOP LARGO: Tutto su una riga, font GRANDI
  Widget _buildWideDesktopLayout() {
    // Passiamo fontSize: 32 per rendere le cifre grandi su desktop
    final finStats = _buildFinancialStatsList(valueFontSize: 32.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistiche Finanziarie
        ...finStats.map((w) => Expanded(child: w)),

        // Spaziatore visivo
        Container(
          width: 1,
          height: 80,
          color: Colors.grey[800],
          margin: const EdgeInsets.symmetric(horizontal: 24),
        ),

        // Top Performers (senza spazio tra loro)
        ..._buildTopPerformersList().map((w) => Expanded(child: w)),
      ],
    );
  }

  // 2. TABLET: Finanza sopra, Top Performers sotto
  Widget _buildTabletLayout() {
    final finStats = _buildFinancialStatsList(
      valueFontSize: 24.0,
    ); // Font medio
    return Column(
      children: [
        Row(children: finStats.map((w) => Expanded(child: w)).toList()),
        const SizedBox(height: 16),
        Row(
          children:
              _buildTopPerformersList().map((w) => Expanded(child: w)).toList(),
        ),
      ],
    );
  }

  // 3. MOBILE: Griglia riordinata e compattata
  Widget _buildMobileLayout() {
    // Indici originali della lista _buildFinancialStatsList:
    // 0: Valore Magazzino
    // 1: Margine Profitto
    // 2: Guadagno Lordo
    // 3: Spesa Totale
    final finStats = _buildFinancialStatsList(valueFontSize: 20.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Riga 1: Margine Profitto (1) + Guadagno Lordo (2)
        Row(
          children: [
            Expanded(child: finStats[1]),
            Expanded(child: finStats[2]),
          ],
        ),

        // Riga 2: Spesa Totale (3) + Valore Magazzino (0)
        Row(
          children: [
            Expanded(child: finStats[3]),
            Expanded(child: finStats[0]),
          ],
        ),

        const SizedBox(height: 16), // Spazio normale prima dei Top Performers
        // Top Performers: Rimosso padding eccessivo
        // Usiamo il map index per non mettere spazio sotto l'ultimo elemento se necessario,
        // ma qui semplicemente mettiamo un piccolo margine.
        ..._buildTopPerformersList().map(
          (w) => Padding(
            padding: const EdgeInsets.only(
              bottom: 4.0,
            ), // Ridotto da 16 a 4 per avvicinarli
            child: w,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LISTE DI WIDGET GENERATE
  // ---------------------------------------------------------------------------

  // Aggiunto parametro opzionale per la grandezza del font
  List<Widget> _buildFinancialStatsList({double valueFontSize = 20.0}) {
    final totals = _statsData['totals'] ?? {};
    // L'ordine qui è importante per gli indici usati nel layout mobile
    return [
      // Index 0
      _buildStatCard(
        'VALORE MAGAZZINO',
        _formatCurrency(totals['estimated_profit']),
        Iconsax.box,
        _estimatedProfitColor,
        totals['estimated_profit'],
        valueFontSize,
      ),
      // Index 1
      _buildStatCard(
        'MARGINE PROFITTO',
        _formatCurrency(totals['net_profit_total']),
        Iconsax.money_send,
        _netProfitColor,
        totals['net_profit_total'],
        valueFontSize,
      ),
      // Index 2
      _buildStatCard(
        'GUADAGNO LORDO',
        _formatCurrency(totals['gross_profit_total']),
        Iconsax.archive_add,
        _grossProfitColor,
        totals['gross_profit_total'],
        valueFontSize,
      ),
      // Index 3
      _buildStatCard(
        'SPESA TOTALE',
        _formatCurrency(totals['total_spent']),
        Iconsax.card_slash,
        _spentColor,
        totals['total_spent'],
        valueFontSize,
      ),
    ];
  }

  List<Widget> _buildTopPerformersList() {
    final topCategory = _statsData['topCategory'];
    final topBrand = _statsData['topBrand'];
    final String? categoryName = topCategory?['category_name'];

    return [
      _buildTopPerformerCard(
        title: 'CATEGORIA PIÙ VENDUTA',
        name: topCategory?['category_name'] ?? 'N/D',
        count: _parseCount(topCategory?['sales_count']),
        icon: getIconForCategory(categoryName),
      ),
      // Rimosso SizedBox(width: 8) per unire i widget come richiesto
      _buildTopPerformerCard(
        title: 'BRAND PIÙ VENDUTO',
        name: topBrand?['brand'] ?? 'N/D',
        count: _parseCount(topBrand?['sales_count']),
        icon: Iconsax.tag,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // SINGOLI WIDGET (CARD)
  // ---------------------------------------------------------------------------

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    dynamic rawValue,
    double fontSize,
  ) {
    final double? numericValue = double.tryParse(rawValue.toString());
    final bool isNegative = numericValue != null && numericValue < 0;

    return Card(
      margin: const EdgeInsets.all(4),
      color: Theme.of(context).cardColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (numericValue != null)
              _AnimatedCount(
                endValue: numericValue,
                style: GoogleFonts.inconsolata(
                  fontSize: fontSize, // Usa la dimensione passata dinamicamente
                  color: isNegative ? Colors.red[700] : color,
                  fontWeight: FontWeight.bold,
                ),
                formatter: (val) => '€ ${val.toStringAsFixed(2)}',
              )
            else
              Text(
                value,
                style: GoogleFonts.inconsolata(
                  fontSize: fontSize, // Usa la dimensione passata dinamicamente
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
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
      margin: const EdgeInsets.all(4),
      color: const Color(0xFF161616),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Transform.rotate(
              angle: -0.2,
              child: Icon(
                icon,
                size: 100,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _AnimatedCount(
                    endValue: count,
                    style: GoogleFonts.inconsolata(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    formatter: (val) => '${val.toInt()} VENDUTI',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 100, color: baseColor)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 100, color: baseColor)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Container(height: 100, color: baseColor)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 100, color: baseColor)),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

// --- UTILS: ANIMATED COUNT & CHART ---

class _AnimatedCount extends StatefulWidget {
  final num endValue;
  final TextStyle? style;
  final String Function(num) formatter;
  const _AnimatedCount({
    required this.endValue,
    required this.formatter,
    this.style,
  });

  @override
  State<_AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<_AnimatedCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.endValue.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endValue != widget.endValue) {
      _animation = Tween<double>(
        begin: oldWidget.endValue.toDouble(),
        end: widget.endValue.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder:
          (context, child) =>
              Text(widget.formatter(_animation.value), style: widget.style),
    );
  }
}

class _SalesTrendChart extends StatefulWidget {
  final List<dynamic> trendData;
  final bool isLoaded;
  const _SalesTrendChart({required this.trendData, required this.isLoaded});
  @override
  State<_SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<_SalesTrendChart> {
  List<Color> gradientColors = [
    const Color(0xFF23b6e6),
    const Color(0xFF02d39a),
  ];

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoaded) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.trendData.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text("Nessun dato", style: TextStyle(color: Colors.grey[600])),
      );
    }
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;
    final bool isDesktop = width >= 1000;

    double myAspectRatio;
    if (isMobile) {
      myAspectRatio = 2.0; // Mobile: Alto
    } else if (isDesktop) {
      myAspectRatio = 5.0; // Desktop: Molto schiacciato (panoramico)
    } else {
      myAspectRatio = 3.0; // Tablet: Medio
    }

    return Stack(
      children: [
        AspectRatio(
          // Su mobile abbassiamo l'aspect ratio (più alto) per dare respiro,
          // su desktop lo teniamo schiacciato (2.5) come richiesto prima.
          aspectRatio: myAspectRatio,
          child: Padding(
            // MODIFICA 3: Rimosso padding a sinistra/sotto (gestito da fl_chart), ridotto destra/sopra
            // Old: right: 18, left: 12, top: 24, bottom: 12
            padding: const EdgeInsets.only(
              right: 12,
              left: 0,
              top: 12,
              bottom: 4,
            ),
            child: LineChart(mainData()),
          ),
        ),
      ],
    );
  }

  LineChartData mainData() {
    List<FlSpot> spots = [];
    double maxY = 0;
    for (int i = 0; i < widget.trendData.length; i++) {
      final val =
          double.tryParse(widget.trendData[i]['daily_total'].toString()) ?? 0.0;
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }
    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine:
            (value) => FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: (widget.trendData.length / 5).ceilToDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < widget.trendData.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat(
                      'dd/MM',
                    ).format(DateTime.parse(widget.trendData[index]['date'])),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: maxY / 5,
            getTitlesWidget:
                (value, meta) =>
                    value == 0
                        ? const Text('')
                        : Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xff67727d),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
            reservedSize: 40,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (widget.trendData.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(colors: gradientColors),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors:
                  gradientColors
                      .map((color) => color.withOpacity(0.3))
                      .toList(),
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
