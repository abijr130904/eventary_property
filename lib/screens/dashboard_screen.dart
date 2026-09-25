import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';

/// Ringkasan padat seluruh aset — KPI, daftar butuh perhatian, dan
/// distribusi status/kondisi/tipe dalam satu layar tanpa scroll berlebih.
/// Terpisah dari tabel detail Eventaris (lihat AdminDashboardScreen).
/// Read-only: tidak ada aksi tambah/edit/hapus di sini.
class DashboardScreen extends StatelessWidget {
  final List<Property> properties;

  const DashboardScreen({super.key, required this.properties});

  static const double _panelHeight = 230;

  int get _occupied =>
      properties.where((p) => p.status == 'Booking' || p.status == 'Disewa/Terjual').length;

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
        return (severity[a.condition] ?? 2).compareTo(severity[b.condition] ?? 2);
      });
    final noMaintenance = properties
        .where((p) => p.condition == 'Baik' && p.lastMaintenanceDate == null)
        .toList();
    return [...damaged, ...noMaintenance];
  }

  String _formatCompactRupiah(double value) {
    if (value >= 1e9) return 'Rp ${(value / 1e9).toStringAsFixed(1)} M';
    if (value >= 1e6) return 'Rp ${(value / 1e6).toStringAsFixed(0)} Jt';
    return 'Rp ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const Center(
        child: Text('Belum ada data aset.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final attention = _attentionNeeded;
    final occupancyPct = ((_occupied / properties.length) * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
          ),
          const SizedBox(height: 14),
          _buildKpiRow(occupancyPct, attention.length),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth > 1000;
              final attentionPanel = SizedBox(
                height: _panelHeight,
                child: _AttentionCard(properties: attention),
              );
              final statusPanel = SizedBox(
                height: _panelHeight,
                child: _ChartCard(title: 'Distribusi Status', child: _buildPieChart(_countByStatus, _statusColor)),
              );
              final conditionPanel = SizedBox(
                height: _panelHeight,
                child: _ChartCard(title: 'Distribusi Kondisi', child: _buildPieChart(_countByCondition, _conditionColor)),
              );

              if (!wide) {
                return Column(
                  children: [
                    attentionPanel,
                    const SizedBox(height: 14),
                    statusPanel,
                    const SizedBox(height: 14),
                    conditionPanel,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: attentionPanel),
                  const SizedBox(width: 14),
                  Expanded(child: statusPanel),
                  const SizedBox(width: 14),
                  Expanded(child: conditionPanel),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: _ChartCard(title: 'Aset per Tipe', child: _buildTypeBarChart()),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(int occupancyPct, int attentionCount) {
    final cards = [
      _KpiCard(icon: Icons.apartment_rounded, label: 'Total Aset', value: '${properties.length}', color: AppColors.accent),
      _KpiCard(icon: Icons.event_available_rounded, label: 'Okupansi', value: '$occupancyPct%', color: AppColors.accentSecondary),
      _KpiCard(
        icon: attentionCount > 0 ? Icons.report_problem_rounded : Icons.check_circle_rounded,
        label: 'Butuh Perhatian',
        value: '$attentionCount aset',
        color: attentionCount > 0 ? AppColors.danger : AppColors.success,
      ),
      _KpiCard(icon: Icons.payments_rounded, label: 'Total Nilai Aset', value: _formatCompactRupiah(_totalAcquisitionValue), color: AppColors.warning),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth > 700;
        if (!wide) {
          return Column(
            children: [
              for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
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

    final maxY = entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();

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
                  width: 24,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[index].key,
                    style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
                  centerSpaceRadius: 30,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: colorOf(e.key),
                        title: '${(e.value / total * 100).round()}%',
                        radius: 38,
                        titleStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                  ],
                ),
              ),
              Text('$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(width: 10),
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
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colorOf(e.key), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Daftar padat aset yang butuh tindakan: kondisi rusak diutamakan, lalu
/// aset yang belum pernah dicatat perawatannya. Tinggi tetap, scroll
/// internal kalau daftarnya panjang — tidak ada teks "+N lainnya" lagi.
class _AttentionCard extends StatelessWidget {
  final List<Property> properties;

  const _AttentionCard({required this.properties});

  @override
  Widget build(BuildContext context) {
    final isEmpty = properties.isEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: isEmpty ? AppColors.border : AppColors.danger.withOpacity(0.35)),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEmpty ? Icons.check_circle_rounded : Icons.report_problem_rounded,
                color: isEmpty ? AppColors.success : AppColors.danger,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text('Perlu Perhatian', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isEmpty
                ? const Center(
                    child: Text(
                      'Semua aset kondisi baik &\ntercatat rutin dirawat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: properties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) => _AttentionRow(property: properties[index]),
                  ),
          ),
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
    final bool noRecord = property.condition == 'Baik' && property.lastMaintenanceDate == null;
    final String reason = noRecord ? 'Belum dirawat' : property.condition;
    final Color color =
        noRecord ? AppColors.textSecondary : (property.condition == 'Rusak Berat' ? AppColors.danger : AppColors.warning);

    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            property.name,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
          child: Text(reason, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Belum ada data.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}