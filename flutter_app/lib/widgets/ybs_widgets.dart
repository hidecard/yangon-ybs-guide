import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../design_system.dart';
import 'route_badge.dart';
export 'route_badge.dart';

// ---------------------------------------------------------------------------
// ONE-HANDED LAYOUT
// ---------------------------------------------------------------------------
class OneHandedLayout extends StatelessWidget {
  final Widget body;
  final List<Widget>? floatingActions;

  const OneHandedLayout({
    super.key,
    required this.body,
    this.floatingActions,
  });

  @override
  Widget build(BuildContext context) {
    if (floatingActions == null || floatingActions!.isEmpty) return body;

    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: floatingActions!
                  .map((w) => ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 120),
                        child: w,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SWIPE-DOWN DISMISS SHEET
// ---------------------------------------------------------------------------
class SwipeDismissSheet extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDismissed;

  const SwipeDismissSheet({super.key, required this.child, this.onDismissed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! > YBSDesignSystem.dismissVelocity) {
          onDismissed?.call();
          if (Navigator.canPop(context)) Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}

class YBSBottomSheet extends StatelessWidget {
  final Widget child;
  final double? height;
  final bool draggable;

  const YBSBottomSheet({
    super.key,
    required this.child,
    this.height,
    this.draggable = true,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = height ?? MediaQuery.of(context).size.height * 0.65;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draggable)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

Future<T?> showYBSSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? height,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SwipeDismissSheet(
        onDismissed: isDismissible ? () => Navigator.pop(context) : null,
        child: YBSBottomSheet(
          height: height,
          draggable: isDismissible,
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// PROGRESS LINE — journey completion indicator
// ---------------------------------------------------------------------------
class RouteProgressLine extends StatelessWidget {
  final double progress;
  final double? height;

  const RouteProgressLine({super.key, required this.progress, this.height});

  @override
  Widget build(BuildContext context) {
    final h = height ?? 6;
    final p = progress.clamp(0.0, 1.0);
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: YBSDesignSystem.darkBorder,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: p,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [YBSDesignSystem.brand, YBSDesignSystem.accentEmerald],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OFFLINE SHIELD — transparent reassurance
// ---------------------------------------------------------------------------
class OfflineShield extends StatelessWidget {
  final bool isOffline;
  final String message;

  const OfflineShield({
    super.key,
    required this.isOffline,
    this.message =
        'Offline စနစ်ဖြင့် အလုပ်လုပ်နေပါသည် (မြေပုံနှင့် လမ်းကြောင်းရှာဖွေမှုကို အင်တာနက်မလိုဘဲ သုံးနိုင်သည်)',
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: YBSDesignSystem.accentEmerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YBSDesignSystem.accentEmerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 20, color: YBSDesignSystem.accentEmerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: YBSDesignSystem.accentEmerald),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VISUAL ROUTE FLOW BLOCKS — stop → badge → transfer → badge → stop
// ---------------------------------------------------------------------------
class RouteFlowBlock extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isLast;

  const RouteFlowBlock({
    super.key,
    required this.label,
    this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? YBSDesignSystem.brand;
    return Row(
      children: [
        RouteBadge(routeId: label, color: c, small: true),
        if (!isLast)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                height: 2,
                color: YBSDesignSystem.darkBorder,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AI PREDICTION CARD — floating home screen card
// ---------------------------------------------------------------------------
class AIPredictionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData? icon;

  const AIPredictionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [YBSDesignSystem.brand.withValues(alpha: 0.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YBSDesignSystem.brand.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icon != null)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: YBSDesignSystem.brandLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: YBSDesignSystem.brand),
                ),
              if (icon != null) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QUICK QUERY CHIPS — assistant quick actions
// ---------------------------------------------------------------------------
class QuickQueryChips extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String> onChipTap;
  final bool isDark;

  const QuickQueryChips({
    super.key,
    required this.chips,
    required this.onChipTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          return ActionChip(
            label: Text(chip, style: const TextStyle(fontSize: 12)),
            backgroundColor: isDark
                ? YBSDesignSystem.darkSurfaceRaised
                : YBSDesignSystem.brandLight,
            labelStyle: TextStyle(
              color: isDark ? YBSDesignSystem.darkText : YBSDesignSystem.brandHover,
            ),
            side: BorderSide(
              color: isDark
                  ? YBSDesignSystem.darkBorder
                  : YBSDesignSystem.brand.withValues(alpha: 0.3),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              onChipTap(chip);
            },
          );
        },
      ),
    );
  }
}
