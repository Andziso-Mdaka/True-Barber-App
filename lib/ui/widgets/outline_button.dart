import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CustomOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool loading;
  
  const CustomOutlineButton({
    super.key, 
    required this.label, 
    required this.onTap, 
    this.color = AppColors.text, 
    this.loading = false
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color == AppColors.text ? AppColors.line : color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}