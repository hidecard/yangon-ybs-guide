import 'package:flutter/material.dart';
import '../config.dart';

class RouteBadge extends StatelessWidget {
  final String routeId;
  final Color color;
  final VoidCallback? onTap;
  final bool small;
  const RouteBadge({
    super.key,
    required this.routeId,
    required this.color,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: small ? 36 : 52),
        height: small ? 28 : 40,
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))
          ],
        ),
        child: Text(
          routeId,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: small ? 12 : 14,
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? fg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.bg, this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? AppColors.borderLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg ?? AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
