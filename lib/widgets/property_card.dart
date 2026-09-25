import 'package:flutter/material.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';

/// Small floating card that appears next to a selected marker,
/// showing a quick summary before the user opens the full detail
/// panel.
class PropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onViewDetails;
  final VoidCallback? onClose;
  final VoidCallback? onEditLocation;

  const PropertyCard({
    super.key,
    required this.property,
    required this.onViewDetails,
    this.onClose,
    this.onEditLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.floating,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  property.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onClose != null)
                InkWell(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  property.location,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onEditLocation != null)
                Tooltip(
                  message: 'Ubah Koordinat',
                  child: InkWell(
                    onTap: onEditLocation,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.edit_location_alt_outlined, size: 14, color: AppColors.accent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(icon: Icons.people_alt_outlined, label: property.capacityLabel),
              const SizedBox(width: 14),
              _MiniStat(icon: Icons.category_outlined, label: property.type),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
