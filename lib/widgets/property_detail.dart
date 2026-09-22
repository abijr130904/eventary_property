import 'package:flutter/material.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';
import 'model_3d_viewer.dart';

/// Bottom/side detail panel shown once a property has been selected
/// via "View Details" on its marker popup.
class PropertyDetail extends StatelessWidget {
  final Property property;
  final VoidCallback? onClose;
  final bool horizontal;

  const PropertyDetail({
    super.key,
    required this.property,
    this.onClose,
    this.horizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    final infoColumn = _buildInfoColumn(context);
    final modelArea = _buildModelArea(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: horizontal
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: infoColumn),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: modelArea),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoColumn,
                const SizedBox(height: 18),
                modelArea,
              ],
            ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                property.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onClose != null)
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              property.location,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _StatChip(label: 'Capacity', value: property.capacityLabel, icon: Icons.people_alt_outlined),
            const SizedBox(width: 12),
            _StatChip(label: 'Type', value: property.type, icon: Icons.category_outlined),
            const SizedBox(width: 12),
            _StatChip(label: 'Area', value: property.areaLabel, icon: Icons.square_foot),
          ],
        ),
        const SizedBox(height: 18),
        if (property.description.isNotEmpty)
          Text(
            property.description,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => showModelFullscreen(context, property),
              icon: const Icon(Icons.view_in_ar_outlined, size: 17),
              label: const Text('View 3D'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.info_outline, size: 17),
              label: const Text('Property Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelArea(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Model3DViewer(property: property),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
