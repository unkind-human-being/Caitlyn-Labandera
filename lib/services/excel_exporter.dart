import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/laundry_order.dart';

/// Generates a real XLSX workbook, then opens Android's Share/Save chooser.
/// This does not request broad file storage permissions.
Future<void> exportOrdersToExcel(
  List<LaundryOrder> orders, {
  String Function(LaundryOrder)? statusForOrder,
}) async {
  final workbook = Excel.createExcel();
  final sheet = workbook['Customers'];
  workbook.delete('Sheet1');
  workbook.setDefaultSheet('Customers');

  const headers = <String>[
    'Receipt ID',
    'Customer name',
    'Phone number',
    'Category',
    'Weight (kg)',
    'Price per kg (PHP)',
    'Total (PHP)',
    'Registered at',
    'Claim date',
    'Item details',
    'Notes',
    'Pickup status',
    'SMS consent',
    'SMS status',
  ];
  sheet.appendRow(headers.map((title) => TextCellValue(title)).toList());

  for (var column = 0; column < headers.length; column++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0)).cellStyle =
        CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#0A1744'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );
  }
  for (var column = 0; column < headers.length; column++) {
    sheet.setColumnWidth(column, column == 9 || column == 10 ? 32 : 20);
  }

  for (final order in orders) {
    sheet.appendRow(<CellValue>[
      TextCellValue(order.receiptId),
      TextCellValue(order.fullName),
      // Text deliberately preserves leading zeroes and +63 format.
      TextCellValue(order.phoneNumber),
      TextCellValue(order.category),
      DoubleCellValue(order.weightKg),
      DoubleCellValue(order.pricePerKg),
      DoubleCellValue(order.total),
      TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(order.registeredAt)),
      TextCellValue(DateFormat('yyyy-MM-dd').format(order.claimDate)),
      TextCellValue(order.itemSummary),
      TextCellValue(order.notes),
      TextCellValue(order.claimed ? 'Claimed' : 'Awaiting pickup'),
      TextCellValue(order.smsOptIn ? 'Yes' : 'No'),
      TextCellValue(statusForOrder?.call(order) ?? 'Not scheduled'),
    ]);
  }

  final bytes = workbook.save();
  if (bytes == null) throw StateError('Could not create Excel file.');

  final directory = await getTemporaryDirectory();
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final file = File('${directory.path}/Caitlyn_Customers_$timestamp.xlsx');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(ShareParams(
    files: [
      XFile(file.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    ],
    subject: 'Caitlyn Laundry Shop customer records',
    text: 'Caitlyn Laundry Shop customer records (${orders.length} orders)',
  ));
}
