import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/display_format.dart';
import '../data/laundry_order.dart';
import 'app_widgets.dart';

class OrderReceipt extends StatelessWidget {
  const OrderReceipt({super.key, required this.order});
  final LaundryOrder order;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: const BoxDecoration(
              color: AppColors.lightTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_laundry_service_rounded,
                color: AppColors.teal, size: 30),
          ),
          const SizedBox(height: 10),
          const Text('CAITLYN LAUNDRY SHOP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                color: AppColors.navy,
              )),
          const SizedBox(height: 4),
          const Text('Laundry order receipt',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 18),
          const Divider(),
          LabeledValue(label: 'Receipt no.', value: order.receiptId),
          LabeledValue(label: 'Registered', value: readableDateTime(order.registeredAt)),
          LabeledValue(label: 'Customer', value: order.fullName),
          LabeledValue(label: 'Phone', value: order.phoneNumber),
          LabeledValue(label: 'SMS reminders',
            value: order.smsOptIn ? 'Customer consent confirmed' : 'Not authorized'),
          const Divider(),
          LabeledValue(label: 'Laundry category', value: order.category),
          LabeledValue(label: 'Weight', value: '${shortWeight(order.weightKg)} kg'),
          LabeledValue(label: 'Rate', value: '${peso(order.pricePerKg)} / kg'),
          LabeledValue(label: 'Claim date', value: readableDate(order.claimDate)),
          LabeledValue(label: 'Pickup status', value: order.claimed ? 'Claimed' : 'Awaiting pickup'),
          if (order.itemQuantities.values.any((quantity) => quantity > 0))
            LabeledValue(label: 'Items', value: order.itemSummary),
          if (order.notes.isNotEmpty)
            LabeledValue(label: 'Notes', value: order.notes),
          const Divider(height: 24),
          LabeledValue(label: 'TOTAL AMOUNT', value: peso(order.total), emphasized: true),
          const SizedBox(height: 8),
          const Text(
            'Thank you for trusting Caitlyn Laundry Shop!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      );
}

Future<void> showSavedReceipt(BuildContext context, LaundryOrder order) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 490,
        height: MediaQuery.sizeOf(dialogContext).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: OrderReceipt(order: order))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
