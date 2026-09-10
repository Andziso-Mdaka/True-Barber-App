import 'package:flutter/material.dart';
import '../../core/theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  
  const MetricCard({
    super.key, 
    required this.label, 
    required this.value, 
    this.accent = false
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: accent ? AppColors.brass : AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}