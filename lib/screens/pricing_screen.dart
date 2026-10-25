import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/display_format.dart';
import '../data/app_store.dart';
import '../widgets/app_widgets.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prices = widget.store.prices;
    _controllers = {
      for (final category in AppStore.categories)
        category: TextEditingController(text: prices[category]!.toStringAsFixed(2)),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;
    final next = {
      for (final category in AppStore.categories)
        category: double.parse(_controllers[category]!.text.trim()),
    };
    final summary = AppStore.categories
        .map((category) => '$category: ${peso(next[category]!)} / kg')
        .join('\n');
    final confirmed = await askYesNo(
      context,
      title: 'Save new laundry prices?',
      message: 'Are you sure you want to update these prices?\n\n$summary\n\n'
          'Previous orders will keep their original prices.',
      yesText: 'Yes, update',
      noText: 'No, edit',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.store.updatePrices(next);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showAppMessage(context, 'Failed to update prices.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pricing settings')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const PageHeading(
                  title: 'Laundry pricing',
                  subtitle: 'Update the price per kilogram for each category.',
                ),
                const SizedBox(height: 22),
                SurfaceCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final category in AppStore.categories) ...[
                          Row(children: [
                            Icon(_iconFor(category), color: AppColors.teal),
                            const SizedBox(width: 8),
                            Text(category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                          ]),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: _controllers[category],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Price per 1 kg',
                              prefixText: '₱ ',
                            ),
                            validator: (value) {
                              final price = double.tryParse(value?.trim() ?? '');
                              if (price == null ||
                                  !price.isFinite ||
                                  price <= 0 ||
                                  price > 1000000) {
                                return 'Enter a price from ₱0.01 to ₱1,000,000.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 21),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SurfaceCard(
                  color: AppColors.lightTeal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.navy),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'New prices apply only to future registrations. Existing receipts and reports keep the rates used when each order was saved.',
                          style: TextStyle(color: AppColors.navySoft, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Review & save prices'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  IconData _iconFor(String category) {
    switch (category) {
      case 'White':
        return Icons.checkroom_outlined;
      case 'Blanket':
        return Icons.bed_outlined;
      default:
        return Icons.local_laundry_service_outlined;
    }
  }
}
