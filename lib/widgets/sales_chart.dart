import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
/// Widget Grafik Penjualan & Profit untuk Dashboard.
///
/// Menampilkan BarChart interaktif dengan filter per Hari/Bulan/Tahun,
/// dan tab untuk beralih antara data Penjualan dan Profit.
class SalesChartCard extends StatefulWidget {
  const SalesChartCard({super.key});

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _FilterBottomSheet extends StatefulWidget {
  final String initialType;
  final String initialValue;
  final Function(String type, String value) onApply;

  const _FilterBottomSheet({
    required this.initialType,
    required this.initialValue,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String type;
  late int selectedMonth;
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
    final now = DateTime.now();
    if (widget.initialValue.isNotEmpty) {
      if (type == 'hari') {
        final parts = widget.initialValue.split('-');
        selectedYear = int.tryParse(parts[0]) ?? now.year;
        selectedMonth = int.tryParse(parts[1]) ?? now.month;
      } else if (type == 'bulan') {
        selectedYear = int.tryParse(widget.initialValue) ?? now.year;
        selectedMonth = now.month;
      } else {
        selectedYear = now.year;
        selectedMonth = now.month;
      }
    } else {
      selectedYear = now.year;
      selectedMonth = now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Grafik',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            const Text('Tipe Grafik', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeChip('hari', 'Harian'),
                const SizedBox(width: 8),
                _buildTypeChip('bulan', 'Bulanan'),
                const SizedBox(width: 8),
                _buildTypeChip('tahun', 'Tahunan'),
              ],
            ),
            const SizedBox(height: 16),
            if (type != 'tahun') ...[
              Text(
                type == 'hari' ? 'Pilih Bulan & Tahun' : 'Pilih Tahun',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (type == 'hari') ...[
                    Expanded(
                      flex: 2,
                      child: _buildDropdownContainer(
                        DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          items: List.generate(12, (index) {
                            final m = index + 1;
                            const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                            return DropdownMenuItem(value: m, child: Text(names[index]));
                          }),
                          onChanged: (v) {
                            if (v != null) setState(() => selectedMonth = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 1,
                    child: _buildDropdownContainer(
                      DropdownButton<int>(
                        value: selectedYear,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardColor,
                        items: List.generate(10, (index) {
                          final y = DateTime.now().year - 5 + index;
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }),
                        onChanged: (v) {
                          if (v != null) setState(() => selectedYear = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  String val = '';
                  if (type == 'hari') {
                    val = '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';
                  } else if (type == 'bulan') {
                    val = '$selectedYear';
                  } else if (type == 'tahun') {
                    val = '';
                  }
                  widget.onApply(type, val);
                },
                child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String chipType, String label) {
    final isSelected = type == chipType;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => type = chipType),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }
}

class _SalesChartCardState extends State<SalesChartCard>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;

  late TabController _tabController;

  String _filterType = 'bulan'; // 'hari' | 'bulan' | 'tahun'
  String _filterValue = '';

  Future<_ChartData>? _futureJual;
  Future<_ChartData>? _futureProfit;

  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadDefault();
  }

  void _loadDefault() {
    final now = DateTime.now();
    if (_filterType == 'hari') {
      _filterValue = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    } else if (_filterType == 'bulan') {
      _filterValue = now.year.toString();
    } else {
      _filterValue = '';
    }
    _reload();
  }

  void _reload() {
    final p = {'type': _filterType, 'value': _filterValue};
    setState(() {
      _futureJual = _api.callRaw('getDashboardChartData', p).then(_parse);
      _futureProfit =
          _api.callRaw('getDashboardProfitChartData', p).then(_parse);
    });
  }

  _ChartData _parse(Map<String, dynamic> raw) {
    final labels = List<String>.from(raw['labels'] ?? []);
    final data = (raw['data'] as List? ?? [])
        .map((v) => (v is num ? v.toDouble() : 0.0))
        .toList();
    return _ChartData(labels: labels, values: data);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Grafik Penjualan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Penjualan / Profit
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: theme.textTheme.bodySmall?.color,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 12.5),
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'Penjualan'),
                  Tab(text: 'Profit'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: _FilterBottomSheet(
                      initialType: _filterType,
                      initialValue: _filterValue,
                      onApply: (type, val) {
                        setState(() {
                          _filterType = type;
                          _filterValue = val;
                          _loadData();
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _filterType == 'hari'
                          ? 'Filter: Harian'
                          : (_filterType == 'bulan' ? 'Filter: Bulanan' : 'Filter: Tahunan'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Chart area
          SizedBox(
            height: 220,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildChartView(
                    _futureJual, AppColors.primary, AppColors.sidebarAccent2),
                _buildChartView(
                    _futureProfit, AppColors.accent, const Color(0xFF86EFAC)),
              ],
            ),
          ),

        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // CHART VIEW
  // -----------------------------------------------------------------------

  Widget _buildChartView(
      Future<_ChartData>? future, Color barColor, Color gradientEnd) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return FutureBuilder<_ChartData>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Text('Gagal memuat grafik',
                style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.7),
                    fontSize: 13)),
          );
        }
        final data = snap.data!;
        if (data.labels.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 40,
                    color: AppColors.muted.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Text('Belum ada data transaksi',
                    style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.7),
                        fontSize: 13)),
              ],
            ),
          );
        }
        return _BarChartWidget(
          data: data,
          barColor: barColor,
          gradientEnd: gradientEnd,
          touchedIndex: _touchedIndex,
          onTouch: (i) => setState(() => _touchedIndex = i),
        );
      },
    );
  }

  void _loadData() {
    _reload();
  }
}

// ---------------------------------------------------------------------------
// BarChart Widget
// ---------------------------------------------------------------------------

class _BarChartWidget extends StatelessWidget {
  final _ChartData data;
  final Color barColor;
  final Color gradientEnd;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _BarChartWidget({
    required this.data,
    required this.barColor,
    required this.gradientEnd,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0.0, (a, b) => a > b ? a : b);
    final topY = maxVal <= 0 ? 1000.0 : maxVal * 1.6; // Memberi ruang kosong ekstra 60% di atas agar tooltip tidak terpotong

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.values.length; i++) {
      final isTouched = i == touchedIndex;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: data.values[i],
            width: _barWidth(data.values.length),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
            gradient: LinearGradient(
              colors: isTouched
                  ? [barColor, barColor]
                  : [
                      gradientEnd.withValues(alpha: 0.85),
                      barColor,
                    ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
        showingTooltipIndicators: isTouched ? [0] : [],
      ));
    }

    final minChartWidth = data.labels.length * 50.0;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 16, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isScrollable = minChartWidth > constraints.maxWidth;
          Widget chart = BarChart(
            BarChartData(
              maxY: topY,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) =>
                      AppColors.text.withValues(alpha: 0.9),
                  tooltipRoundedRadius: 8,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = data.labels[group.x];
                    final val = rod.toY;
                    return BarTooltipItem(
                      '$label\n${_compactRupiahText(val)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent || event is FlLongPressEnd) {
                    if (response == null || response.spot == null) {
                      onTouch(-1);
                    } else {
                      onTouch(response.spot!.touchedBarGroupIndex);
                    }
                  } else if (event is FlPointerExitEvent) {
                    onTouch(-1);
                  }
                },
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 85,
                    getTitlesWidget: (val, meta) {
                      if (val == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          _compactRupiahText(val),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (val, meta) {
                      final i = val.toInt();
                      if (i < 0 || i >= data.labels.length) {
                        return const SizedBox.shrink();
                      }
                      final step = _labelStep(data.labels.length);
                      if (i % step != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _shortLabel(data.labels[i]),
                          style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );

          if (isScrollable) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: minChartWidth,
                child: chart,
              ),
            );
          }
          return chart;
        },
      ),
    );
  }

  double _barWidth(int count) {
    if (count <= 7) return 22;
    if (count <= 12) return 16;
    if (count <= 18) return 12;
    return 8;
  }

  int _labelStep(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 24) return 3;
    return 4;
  }

  String _shortLabel(String label) {
    final parts = label.split(' ');
    if (parts.length == 2) {
      final bulan =
          parts[0].length > 3 ? parts[0].substring(0, 3) : parts[0];
      final year =
          parts[1].length == 4 ? parts[1].substring(2) : parts[1];
      return '$bulan\n$year';
    }
    return label;
  }

  String _compactRupiahText(double value) {
    if (value >= 1000000) return 'Rp ${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    if (value >= 1000) return 'Rp ${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}rb';
    return 'Rp ${value.toInt()}';
  }
}

// ---------------------------------------------------------------------------
// Data holder
// ---------------------------------------------------------------------------

class _ChartData {
  final List<String> labels;
  final List<double> values;
  const _ChartData({required this.labels, required this.values});
}
