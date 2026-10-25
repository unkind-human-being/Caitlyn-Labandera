import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../core/app_theme.dart';
import '../core/display_format.dart';
import '../data/app_store.dart';
import '../data/laundry_order.dart';
import '../services/report_pdf.dart';
import '../services/report_period.dart';
import '../widgets/app_widgets.dart';
import '../widgets/order_receipt.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.store, required this.period});
  final AppStore store;
  final ReportPeriod period;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  static const _pageSize = 10;
  int _page = 0;
  bool _busy = false;

  Future<void> _printOrExport(List<LaundryOrder> orders,
      ReportWindow window, {required bool print}) async {
    if (_busy) return;
    final confirmed = await askYesNo(
      context,
      title: print ? 'Print this report?' : 'Create PDF document?',
      message: '${print ? 'Print' : 'Export'} all ${orders.length} record(s) '
          'for ${widget.period.label.toLowerCase()}? The complete period will be included, '
          'not just the 10 records on this screen.',
      yesText: print ? 'Yes, print' : 'Yes, create PDF',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await buildReportPdf(
        period: widget.period, window: window, orders: orders);
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        final filename = 'Caitlyn_${widget.period.name}_'
            '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (_) {
      if (mounted) showAppMessage(context,
          'Could not generate/open the report. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.period.label} Report')),
    body: ValueListenableBuilder<Box<dynamic>>(
      valueListenable: widget.store.ordersBox.listenable(),
      builder: (context, box, _) {
        final window = widget.period.windowAt(DateTime.now());
        final orders = widget.store.orders
            .where((order) => window.contains(order.registeredAt)).toList();
        final lastPage = orders.isEmpty ? 0 : (orders.length - 1) ~/ _pageSize;
        final currentPage = _page.clamp(0, lastPage).toInt();
        final startIndex = currentPage * _pageSize;
        final shown = orders.skip(startIndex).take(_pageSize).toList();
        final from = orders.isEmpty ? 0 : startIndex + 1;
        final to = startIndex + shown.length;
        final total = orders.fold<double>(0, (sum, order) => sum + order.total);
        final compact = MediaQuery.sizeOf(context).width < 730;
        final date = DateFormat('MMM d, yyyy');
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: EdgeInsets.fromLTRB(compact ? 16 : 27, 22,
                  compact ? 16 : 27, 32),
              children: [
                PageHeading(
                  title: widget.period.label,
                  subtitle: '${date.format(window.start)} – '
                      '${date.format(window.end.subtract(const Duration(days: 1)))}'),
                const SizedBox(height: 17),
                SurfaceCard(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 14,
                    children: [
                      _stat('Registered orders', '${orders.length}'),
                      _stat('Total order value', peso(total)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Wrap(spacing: 9, runSpacing: 9, children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _printOrExport(orders, window, print: true),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print report'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _printOrExport(orders, window, print: false),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Save / share PDF'),
                  ),
                ]),
                const SizedBox(height: 20),
                Text('Records ($from–$to of ${orders.length})',
                  style: const TextStyle(color: AppColors.navy,
                      fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 11),
                if (orders.isEmpty)
                  const SurfaceCard(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 23),
                    child: Center(child: Text('No laundry registrations during this period.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted))),
                  )),
                if (orders.isNotEmpty && compact)
                  for (final order in shown) _mobileRow(order),
                if (orders.isNotEmpty && !compact) _wideTable(shown),
                if (orders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [
                      Expanded(child: Text('Showing $from–$to of ${orders.length}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12))),
                      IconButton(
                        tooltip: 'Previous 10 records',
                        onPressed: currentPage == 0 ? null
                            : () => setState(() => _page = currentPage - 1),
                        icon: const Icon(Icons.chevron_left)),
                      Text('${currentPage + 1}/${lastPage + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: 'Next 10 records',
                        onPressed: currentPage >= lastPage ? null
                            : () => setState(() => _page = currentPage + 1),
                        icon: const Icon(Icons.chevron_right)),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('These amounts are registered order values; no payment status is tracked yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 22,
          fontWeight: FontWeight.w900, color: AppColors.navy)),
    ],
  );

  Widget _mobileRow(LaundryOrder order) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.fullName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(peso(order.total), style: const TextStyle(
            color: AppColors.navy, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        Text('${order.receiptId} • ${order.category} • ${shortWeight(order.weightKg)} kg',
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text('Claim: ${readableDate(order.claimDate)}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: () => showSavedReceipt(context, order),
          icon: const Icon(Icons.receipt_long_outlined, size: 17),
          label: const Text('Receipt'))),
      ]),
    ),
  );

  Widget _wideTable(List<LaundryOrder> orders) => SurfaceCard(
    padding: const EdgeInsets.all(8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(columns: const [
        DataColumn(label: Text('Receipt')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('Kg')),
        DataColumn(label: Text('Claim')),
        DataColumn(label: Text('Total')),
      ], rows: [
        for (final order in orders)
          DataRow(cells: [
            DataCell(Text(order.receiptId), onTap: () => showSavedReceipt(context, order)),
            DataCell(Text(order.fullName)),
            DataCell(Text(order.phoneNumber)),
            DataCell(Text(order.category)),
            DataCell(Text(shortWeight(order.weightKg))),
            DataCell(Text(readableDate(order.claimDate))),
            DataCell(Text(peso(order.total))),
          ]),
      ]),
    ),
  );
}
