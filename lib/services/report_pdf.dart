import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/laundry_order.dart';
import 'report_period.dart';

/// Entire selected report period, regardless of on-screen 10-record pagination.
Future<Uint8List> buildReportPdf({
  required ReportPeriod period,
  required ReportWindow window,
  required List<LaundryOrder> orders,
}) async {
  final document = pw.Document();
  final date = DateFormat('MMM d, yyyy');
  final value = NumberFormat('#,##0.00');
  final sum = orders.fold<double>(0, (total, order) => total + order.total);
  final headingStyle = pw.TextStyle(
    fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
  final cellStyle = pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey800);
  final headers = ['Receipt', 'Customer', 'Phone', 'Category', 'Kg', 'Claim date', 'Total (PHP)'];

  pw.Widget cell(String text, {bool heading = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
    child: pw.Text(text, maxLines: 3, style: heading ? headingStyle : cellStyle),
  );

  document.addPage(pw.MultiPage(
    maxPages: 300,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(25, 28, 25, 28),
    header: (context) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('CAITLYN LAUNDRY SHOP',
            style: pw.TextStyle(color: PdfColors.indigo900,
                fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.Text('Laundry order report',
            style: const pw.TextStyle(color: PdfColors.blueGrey500, fontSize: 9)),
        ],
      ),
    ),
    footer: (context) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.blueGrey500, fontSize: 8)),
    ),
    build: (context) => [
      pw.Text(period.label,
        style: pw.TextStyle(fontSize: 23, color: PdfColors.indigo900,
            fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 5),
      pw.Text('${date.format(window.start)} – ${date.format(window.end.subtract(const Duration(days: 1)))}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600)),
      pw.SizedBox(height: 14),
      pw.Row(children: [
        pw.Expanded(child: pw.Text('Total orders: ${orders.length}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Text('Order value: PHP ${value.format(sum)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ]),
      pw.SizedBox(height: 12),
      if (orders.isEmpty)
        pw.Text('No orders were registered during this period.'),
      if (orders.isNotEmpty)
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.0),
            1: pw.FlexColumnWidth(1.65),
            2: pw.FlexColumnWidth(1.35),
            3: pw.FlexColumnWidth(0.95),
            4: pw.FlexColumnWidth(0.55),
            5: pw.FlexColumnWidth(1.15),
            6: pw.FlexColumnWidth(1.1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              children: headers.map((text) => cell(text, heading: true)).toList(),
            ),
            for (var i = 0; i < orders.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.white : PdfColors.grey100),
                children: [
                  cell(orders[i].receiptId),
                  cell(orders[i].fullName),
                  cell(orders[i].phoneNumber),
                  cell(orders[i].category),
                  cell(orders[i].weightKg.toStringAsFixed(2)),
                  cell(date.format(orders[i].claimDate)),
                  cell(value.format(orders[i].total)),
                ],
              ),
          ],
        ),
      pw.SizedBox(height: 12),
      pw.Text('Amounts represent registered laundry order value, not confirmed cash payments.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
      pw.SizedBox(height: 7),
      pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
    ],
  ));

  return document.save();
}
