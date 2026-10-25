import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ],
      );
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: emphasized ? 19 : 14,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

Future<bool> askYesNo(
  BuildContext context, {
  required String title,
  required String message,
  String yesText = 'Yes, confirm',
  String noText = 'No, cancel',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(noText),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(yesText),
            ),
          ],
        ),
      ) ??
      false;
}

void showAppMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.danger : AppColors.navySoft,
    ),
  );
}
