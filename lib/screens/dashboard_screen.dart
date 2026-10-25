import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_theme.dart';
import '../core/display_format.dart';
import '../data/app_store.dart';
import '../data/auth_service.dart';
import '../data/laundry_order.dart';
import '../services/excel_exporter.dart';
import '../widgets/app_widgets.dart';
import '../widgets/order_receipt.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int pageSize = 10;
  String _search = '';
  int _page = 0;
  bool _exporting = false;
  bool _deleteInProgress = false;

  List<LaundryOrder> _filter(List<LaundryOrder> records) {
    final term = _search.trim().toLowerCase();
    if (term.isEmpty) return records;
    return records.where((order) {
      return order.fullName.toLowerCase().contains(term) ||
          order.phoneNumber.toLowerCase().contains(term) ||
          order.category.toLowerCase().contains(term) ||
          order.receiptId.toLowerCase().contains(term);
    }).toList();
  }

  Future<void> _delete(LaundryOrder order) async {
    // Protects against overlapping deletion attempts.
    if (_deleteInProgress) return;
    _deleteInProgress = true;

    try {
      final confirmed = await askYesNo(
        context,
        title: 'Delete customer record?',
        message:
            'Are you sure you want to permanently delete ${order.fullName} '
            '(${order.receiptId})? This cannot be undone.',
        yesText: 'Yes, continue',
        noText: 'No, keep',
        destructive: true,
      );
      if (!confirmed || !mounted) return;

      // Verify using the SAME credentials used for login and edited in Settings.
      // Never compare with a hardcoded default password.
      final passwordVerified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DeletePasswordDialog(
          auth: widget.store.auth,
          order: order,
        ),
      ) ?? false;
      if (!passwordVerified || !mounted) return;

      // A second existence check avoids reporting a stale record as deleted.
      if (!widget.store.ordersBox.containsKey(order.id)) {
        showAppMessage(context, 'This record has already been removed.', error: true);
        return;
      }
      await widget.store.deleteOrder(order.id);
      if (!mounted) return;
      showAppMessage(context, 'Record deleted successfully.');
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'Could not delete record.', error: true);
      }
    } finally {
      _deleteInProgress = false;
    }
  }

  Future<void> _export(List<LaundryOrder> records) async {
    if (_exporting || records.isEmpty) return;
    final confirmed = await askYesNo(
      context,
      title: 'Export records to Excel?',
      message: 'Export ${records.length} record(s) to an .xlsx file? '
          'The Android share sheet will let you choose where to save it.',
      yesText: 'Yes, export',
      noText: 'No, cancel',
    );
    if (!confirmed || !mounted) return;
    setState(() => _exporting = true);
    try {
      await exportOrdersToExcel(
        records,
        statusForOrder: (order) => widget.store.smsStatusFor(order.id),
      );
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'Export failed. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: widget.store.ordersBox.listenable(),
      builder: (context, box, _) {
        final all = widget.store.orders;
        final filtered = _filter(all);
        final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ pageSize;
        final currentPage = _page.clamp(0, lastPage).toInt();
        final firstIndex = currentPage * pageSize;
        final pageRecords = filtered.skip(firstIndex).take(pageSize).toList();
        final start = filtered.isEmpty ? 0 : firstIndex + 1;
        final end = firstIndex + pageRecords.length;
        final narrow = MediaQuery.sizeOf(context).width < 720;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: ListView(
              padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 26, narrow ? 16 : 28, 32),
              children: [
                const PageHeading(
                  title: 'Customer records',
                  subtitle: 'Search, view, manage and export saved laundry orders.',
                ),
                const SizedBox(height: 22),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_outlined, color: AppColors.teal),
                          const SizedBox(width: 10),
                          Text('${all.length} total registered orders',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        final vertical = constraints.maxWidth < 570;
                        final search = TextField(
                          onChanged: (value) => setState(() {
                            _search = value;
                            _page = 0;
                          }),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search name, phone, ID or category',
                          ),
                        );
                        final export = FilledButton.icon(
                          onPressed: filtered.isEmpty || _exporting
                              ? null
                              : () => _export(filtered),
                          icon: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.file_download_outlined),
                          label: Text(_exporting ? 'Exporting...' : 'Export Excel'),
                        );
                        return vertical
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  search,
                                  const SizedBox(height: 12),
                                  export,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: search),
                                  const SizedBox(width: 12),
                                  export,
                                ],
                              );
                      }),
                      const SizedBox(height: 8),
                      const Text('Excel exports include all matching search results, not just the current page.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (filtered.isEmpty)
                  const SurfaceCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 34),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 52, color: AppColors.muted),
                          SizedBox(height: 12),
                          Text('No records found',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          SizedBox(height: 5),
                          Text('Register a customer or try a different search.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  )
                else if (narrow)
                  ...pageRecords.map(_mobileRecord)
                else
                  _desktopTable(pageRecords),
                if (filtered.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Showing $start–$end of ${filtered.length}',
                              style: const TextStyle(
                                  color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          tooltip: 'Previous 10',
                          onPressed: currentPage == 0
                              ? null
                              : () => setState(() => _page = currentPage - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${currentPage + 1} / ${lastPage + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Next 10',
                          onPressed: currentPage >= lastPage
                              ? null
                              : () => setState(() => _page = currentPage + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileRecord(LaundryOrder order) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.local_laundry_service_outlined,
                        color: AppColors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 3),
                        Text('${order.receiptId} • ${order.phoneNumber}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _softTag(order.category),
                  _softTag('${shortWeight(order.weightKg)} kg'),
                  _softTag('Claim: ${readableDate(order.claimDate)}'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(peso(order.total),
                        style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900)),
                  ),
                  OutlinedButton(
                    onPressed: () => showSavedReceipt(context, order),
                    child: const Text('View'),
                  ),
                  IconButton(
                    tooltip: 'Delete record',
                    color: AppColors.danger,
                    onPressed: () => _delete(order),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _softTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.navySoft,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _desktopTable(List<LaundryOrder> orders) => SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(
                color: AppColors.navy, fontWeight: FontWeight.w800),
            columns: const [
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Kg')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Claim date')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final order in orders)
                DataRow(cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(order.receiptId,
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                    onTap: () => showSavedReceipt(context, order),
                  ),
                  DataCell(Text(order.phoneNumber)),
                  DataCell(Text(order.category)),
                  DataCell(Text(shortWeight(order.weightKg))),
                  DataCell(Text(peso(order.total))),
                  DataCell(Text(readableDate(order.claimDate))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View receipt',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => showSavedReceipt(context, order),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        color: AppColors.danger,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(order),
                      ),
                    ],
                  )),
                ]),
            ],
          ),
        ),
      );
}

/// Requests the CURRENT administrator password before deleting a record.
/// The hashed password is verified by AuthService, not stored in this widget.
class _DeletePasswordDialog extends StatefulWidget {
  const _DeletePasswordDialog({required this.auth, required this.order});

  final AuthService auth;
  final LaundryOrder order;

  @override
  State<_DeletePasswordDialog> createState() => _DeletePasswordDialogState();
}

class _DeletePasswordDialogState extends State<_DeletePasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (_verifying) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your administrator password.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final correct = await widget.auth.authenticate(
        widget.auth.username,
        password,
      );
      if (!mounted) return;

      if (correct) {
        Navigator.of(context).pop(true);
      } else {
        _passwordController.clear();
        setState(() => _error = 'Incorrect password. Record not deleted.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not verify password. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_verifying,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Flexible(child: Text('Administrator password required')),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your current app login password to delete '
                  '${widget.order.fullName} (${widget.order.receiptId}).',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  autofocus: true,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyPassword(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Administrator password',
                    prefixIcon: const Icon(Icons.password_rounded),
                    errorText: _error,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _verifying
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('No, cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _verifying ? null : _verifyPassword,
            icon: _verifying
                ? const SizedBox(
                    height: 17,
                    width: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: const Text('Verify & delete'),
          ),
        ],
      ),
    );
  }
}
