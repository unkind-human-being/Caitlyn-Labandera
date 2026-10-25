import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_theme.dart';
import '../core/display_format.dart';
import '../data/app_store.dart';
import '../data/laundry_order.dart';
import '../widgets/app_widgets.dart';
import '../widgets/order_receipt.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final Map<String, int> _items = {
    for (final name in AppStore.clothingItems) name: 0,
  };

  String _category = 'Random';
  DateTime? _claimDate;
  bool _saving = false;
  bool _smsOptIn = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _normalizedPhone =>
      _phoneController.text.trim().replaceAll(RegExp(r'[\s-]'), '');

  double get _weight => double.tryParse(_weightController.text.trim()) ?? 0;

  double get _price => widget.store.prices[_category] ?? 0;

  double get _total => (_weight * _price * 100).round() / 100;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _claimDate ?? start,
      firstDate: start,
      lastDate: DateTime(today.year + 10, today.month, today.day),
      helpText: 'When will the laundry be claimed?',
    );
    if (picked != null && mounted) setState(() => _claimDate = picked);
  }

  void _reset() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _phoneController.clear();
    _weightController.clear();
    _notesController.clear();
    setState(() {
      _category = 'Random';
      _claimDate = null;
      _smsOptIn = false;
      for (final item in _items.keys) {
        _items[item] = 0;
      }
    });
  }

  Future<void> _reviewOrder() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_claimDate == null) {
      showAppMessage(context, 'Please select the claim date.', error: true);
      return;
    }
    final order = LaundryOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fullName: _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' '),
      phoneNumber: _normalizedPhone,
      category: _category,
      weightKg: _weight,
      pricePerKg: _price,
      registeredAt: DateTime.now(),
      claimDate: _claimDate!,
      itemQuantities: Map<String, int>.from(_items),
      notes: _notesController.text.trim(),
      smsOptIn: _smsOptIn,
    );

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final height = MediaQuery.sizeOf(dialogContext).height;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: SizedBox(
            width: 490,
            height: height * 0.82,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fact_check_outlined, color: AppColors.teal),
                      SizedBox(width: 9),
                      Text('Review before saving',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: OrderReceipt(order: order),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Are you sure these details are correct?',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('No, edit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Yes, save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (approved != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveOrder(order);
      if (!mounted) return;
      _reset();
      showAppMessage(context,
          '${order.fullName} saved successfully. View the receipt from Dashboard.');
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'Could not save this order. Try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: widget.store.settingsBox.listenable(keys: ['prices']),
      builder: (context, _, __) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: ListView(
              padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 26, narrow ? 16 : 28, 32),
              children: [
                const PageHeading(
                  title: 'Register customer',
                  subtitle: 'Create a new laundry order. Review the receipt before saving.',
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('01', 'Customer information'),
                            const SizedBox(height: 18),
                            LayoutBuilder(builder: (context, limits) {
                              final fields = [
                                TextFormField(
                                  controller: _nameController,
                                  maxLength: 100,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name *',
                                    hintText: 'e.g. Maria Dela Cruz',
                                    prefixIcon: Icon(Icons.person_outline),
                                    counterText: '',
                                  ),
                                  validator: (value) {
                                    final name = value?.trim() ?? '';
                                    if (name.length < 2) return 'Enter a valid full name.';
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 18,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Phone number *',
                                    hintText: '09XXXXXXXXX',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                    counterText: '',
                                  ),
                                  validator: (_) {
                                    if (!RegExp(r'^(09\d{9}|\+639\d{9})$')
                                        .hasMatch(_normalizedPhone)) {
                                      return 'Enter 09XXXXXXXXX or +639XXXXXXXXX.';
                                    }
                                    return null;
                                  },
                                ),
                              ];
                              if (limits.maxWidth < 560) {
                                return Column(children: [
                                  fields[0],
                                  const SizedBox(height: 16),
                                  fields[1],
                                ]);
                              }
                              return Row(children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 14),
                                Expanded(child: fields[1]),
                              ]);
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('02', 'Laundry details'),
                            const SizedBox(height: 8),
                            const Text('Choose a laundry category',
                                style: TextStyle(color: AppColors.muted, fontSize: 13)),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final name in AppStore.categories)
                                  ChoiceChip(
                                    selected: _category == name,
                                    label: Text('$name • ${peso(widget.store.prices[name]!)} / kg'),
                                    selectedColor: AppColors.lightTeal,
                                    onSelected: (_) => setState(() => _category = name),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(builder: (context, limits) {
                              final weightField = TextFormField(
                                controller: _weightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Laundry weight (kg) *',
                                  hintText: 'e.g. 2.5',
                                  prefixIcon: Icon(Icons.scale_outlined),
                                  suffixText: 'kg',
                                ),
                                validator: (value) {
                                  final number = double.tryParse(value?.trim() ?? '');
                                  if (number == null || !number.isFinite || number <= 0) {
                                    return 'Enter a weight greater than zero.';
                                  }
                                  if (number > 10000) return 'Maximum weight is 10,000 kg.';
                                  return null;
                                },
                              );
                              final priceDisplay = Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.lightTeal,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Calculated amount',
                                        style: TextStyle(color: AppColors.navySoft, fontSize: 12)),
                                    const SizedBox(height: 5),
                                    Text(peso(_total),
                                        style: const TextStyle(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 26)),
                                    const SizedBox(height: 3),
                                    Text('${peso(_price)} / kg',
                                        style: const TextStyle(
                                            color: AppColors.navySoft, fontSize: 12)),
                                  ],
                                ),
                              );
                              if (limits.maxWidth < 560) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    weightField,
                                    const SizedBox(height: 14),
                                    priceDisplay,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: weightField),
                                  const SizedBox(width: 16),
                                  Expanded(child: priceDisplay),
                                ],
                              );
                            }),
                            const SizedBox(height: 20),
                            const Divider(),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              title: const Text('Item breakdown (optional)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              subtitle: const Text('Add quantities for pants, shirts, blankets, etc.',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              children: [
                                for (final item in AppStore.clothingItems)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(item)),
                                        IconButton(
                                          tooltip: 'Remove $item',
                                          onPressed: _items[item] == 0
                                              ? null
                                              : () => setState(() => _items[item] = _items[item]! - 1),
                                          icon: const Icon(Icons.remove_circle_outline),
                                        ),
                                        SizedBox(
                                          width: 30,
                                          child: Text('${_items[item]}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontWeight: FontWeight.w800)),
                                        ),
                                        IconButton(
                                          tooltip: 'Add $item',
                                          onPressed: _items[item]! >= 999
                                              ? null
                                              : () => setState(() => _items[item] = _items[item]! + 1),
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.teal),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesController,
                              maxLength: 250,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Special instructions (optional)',
                                hintText: 'e.g. Use mild detergent, handle with care',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('03', 'Pickup schedule'),
                            const SizedBox(height: 16),
                            const Text('When should the customer claim their laundry?',
                                style: TextStyle(fontSize: 13, color: AppColors.muted)),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(_claimDate == null
                                  ? 'Select claim date *'
                                  : readableDate(_claimDate!)),
                            ),
                            if (_claimDate == null) ...[
                              const SizedBox(height: 9),
                              const Text('A claim date is required before saving.',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                            const SizedBox(height: 14),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _smsOptIn,
                              onChanged: (value) => setState(() => _smsOptIn = value ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text('Customer agreed to SMS pickup reminders'),
                              subtitle: const Text('Ask the customer first. Without consent, '
                                  'automatic SMS will not be scheduled for this order.'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _reviewOrder,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(_saving ? 'Saving...' : 'Review receipt & save',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text('Nothing is saved until you review the receipt and tap "Yes, save".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String number, String title) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(number,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: AppColors.teal, fontSize: 12)),
          ),
          const SizedBox(width: 11),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.ink, fontWeight: FontWeight.w800)),
        ],
      );
}
