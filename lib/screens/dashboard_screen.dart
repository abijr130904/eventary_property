import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';

/// Ringkasan/statistik seluruh aset — dashboard "pada umumnya" (KPI card +
/// daftar aset yang butuh perhatian + grafik), terpisah dari tabel detail
/// Eventaris (lihat AdminDashboardScreen). Read-only: tidak ada aksi
/// tambah/edit/hapus di sini.
class DashboardScreen extends StatelessWidget {
  final List<Property> properties;

  const DashboardScreen({super.key, required this.properties});

  int get _totalCapacity => properties.fold(0, (sum, p) => sum + p.capacity);
  double get _totalArea => properties.fold(0.0, (sum, p) => sum + p.area);
  double get _totalAcquisitionValue =>
      properties.fold(0.0, (sum, p) => sum + (p.acquisitionValue ?? 0));

  Map<String, int> get _countByType {
    final map = <String, int>{};
    for (final p in properties) {
      map[p.type] = (map[p.type] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _countByStatus {
    final map = <String, int>{for (final s in kPropertyStatuses) s: 0};
    for (final p in properties) {
      map[p.status] = (map[p.status] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _countByCondition {
    final map = <String, int>{for (final c in kAssetConditions) c: 0};
    for (final p in properties) {
      map[p.condition] = (map[p.condition] ?? 0) + 1;
    }
    return map;
  }

  /// Aset yang butuh perhatian: kondisi rusak (Rusak Berat lebih dulu),
  /// lalu aset kondisi baik tapi belum pernah punya catatan perawatan.
  List<Property> get _attentionNeeded {
    final damaged = properties.where((p) => p.condition != 'Baik').toList()
      ..sort((a, b) {
        const severity = {'Rusak Berat': 0, 'Rusak Ringan': 1};
        return (severity[a.condition] ?? 2)
            .compareTo(severity[b.condition] ?? 2);
      });
    final noMaintenance = properties
        .where((p) => p.condition == 'Baik' && p.lastMaintenanceDate == null)
        .toList();
    return [...damaged, ...noMaintenance];
  }

  String _formatRupiah(double value) {
    final s = value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $s';
  }

  @override
  Widget build(BuildContext context) {
    final attention = _attentionNeeded;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Ringkasan kondisi & performa seluruh aset',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildKpiRow(),
          const SizedBox(height: 20),
          _AttentionCard(properties: attention, totalCount: properties.length),
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.insights_rounded, title: 'Analitik Aset'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth > 900;
              final typeChart = _ChartCard(
                  title: 'Aset per Tipe', child: _buildTypeBarChart());
              final statusChart = _ChartCard(
                  title: 'Distribusi Status', child: _buildStatusPieChart());
              final conditionChart = _ChartCard(
                  title: 'Distribusi Kondisi',
                  child: _buildConditionPieChart());

              if (!wide) {
                return Column(
                  children: [
                    typeChart,
                    const SizedBox(height: 16),
                    statusChart,
                    const SizedBox(height: 16),
                    conditionChart,
                  ],
                );
              }
              return Column(
                children: [
                  typeChart,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: statusChart),
                      const SizedBox(width: 16),
                      Expanded(child: conditionChart),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final cards = [
      _KpiCard(
          icon: Icons.apartment_rounded,
          label: 'Total Aset',
          value: '${properties.length}',
          color: AppColors.accent),
      _KpiCard(
          icon: Icons.people_alt_rounded,
          label: 'Total Kapasitas',
          value: '$_totalCapacity orang',
          color: AppColors.accentSecondary),
      _KpiCard(
          icon: Icons.square_foot_rounded,
          label: 'Total Luas',
          value: '${_totalArea.toStringAsFixed(0)} m²',
          color: AppColors.success),
      _KpiCard(
          icon: Icons.payments_rounded,
          label: 'Total Nilai Perolehan',
          value: _formatRupiah(_totalAcquisitionValue),
          color: AppColors.warning),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth > 700;
        if (!wide) {
          return Column(
            children: [
              for (final c in cards)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTypeBarChart() {
    final entries = _countByType.entries.toList();
    if (entries.isEmpty) return const _EmptyChartPlaceholder();

    final maxY =
        entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        barTouchData: BarTouchData(enabled: false),
        barGroups: [
          for (int i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: AppColors.accentGradient,
                  ),
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[index].key,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPieChart() => _buildPieChart(_countByStatus, _statusColor);

  Widget _buildConditionPieChart() =>
      _buildPieChart(_countByCondition, _conditionColor);

  Color _statusColor(String status) {
    switch (status) {
      case 'Tersedia':
        return AppColors.success;
      case 'Booking':
        return AppColors.warning;
      case 'Disewa/Terjual':
        return AppColors.accentSecondary;
      case 'Konstruksi':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case 'Baik':
        return AppColors.success;
      case 'Rusak Ringan':
        return AppColors.warning;
      case 'Rusak Berat':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildPieChart(Map<String, int> data, Color Function(String) colorOf) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const _EmptyChartPlaceholder();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 34,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: colorOf(e.key),
                        title: '${(e.value / total * 100).round()}%',
                        radius: 44,
                        titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                  ],
                ),
              ),
              Text('$total',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: colorOf(e.key), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${e.key} (${e.value})',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Kartu "Perlu Perhatian" — aset dengan kondisi rusak diutamakan, lalu
/// aset yang belum pernah dicatat perawatannya. Bagian paling "urgen" dari
/// dashboard, ditaruh tepat di bawah KPI, sebelum grafik.
class _AttentionCard extends StatelessWidget {
  final List<Property> properties;
  final int totalCount;

  const _AttentionCard({required this.properties, required this.totalCount});

  static const int _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final visible = properties.take(_maxVisible).toList();
    final remaining = properties.length - visible.length;
    final isEmpty = properties.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: isEmpty
                ? AppColors.border
                : AppColors.danger.withOpacity(0.35)),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (isEmpty ? AppColors.success : AppColors.danger)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.report_problem_rounded,
                  color: isEmpty ? AppColors.success : AppColors.danger,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Perlu Perhatian',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const Spacer(),
              if (!isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${properties.length} dari $totalCount aset',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEmpty)
            const Text(
              'Semua aset dalam kondisi baik dan tercatat rutin dirawat.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            )
          else ...[
            for (final p in visible) _AttentionRow(property: p),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$remaining aset lainnya butuh pengecekan',
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final Property property;

  const _AttentionRow({required this.property});

  @override
  Widget build(BuildContext context) {
    final bool noRecord =
        property.condition == 'Baik' && property.lastMaintenanceDate == null;
    final String reason =
        noRecord ? 'Belum ada catatan perawatan' : property.condition;
    final Color color = noRecord
        ? AppColors.textSecondary
        : (property.condition == 'Rusak Berat'
            ? AppColors.danger
            : AppColors.warning);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              property.name,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999)),
            child: Text(reason,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Belum ada data.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}
