import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

class YbsLoadingView extends StatelessWidget {
  final String message;
  const YbsLoadingView({super.key, this.message = 'ဖတ်နေပါသည်...'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YbsEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const YbsEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.slate400),
            const SizedBox(height: 14),
            Text(title, style: UI.sectionTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              YbsActionButton(label: actionLabel!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class YbsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const YbsErrorView({
    super.key,
    this.message =
        'အချက်အလက် ရယူ၍မရပါ။ Internet connection ကို စစ်ပြီး ထပ်ကြိုးစားပါ။',
    required this.onRetry,
    this.retryLabel = 'ထပ်ကြိုးစားမည်',
  });

  @override
  Widget build(BuildContext context) {
    return YbsEmptyView(
      icon: Icons.cloud_off_outlined,
      title: 'အချက်အလက် မရရှိပါ',
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}

class YbsActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const YbsActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: icon == null
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}
