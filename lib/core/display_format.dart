import 'package:intl/intl.dart';

String peso(num amount) =>
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2)
        .format(amount);

String readableDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

String readableDateTime(DateTime date) =>
    DateFormat('MMM d, yyyy • h:mm a').format(date);

String shortWeight(double weight) =>
    weight == weight.roundToDouble()
        ? weight.toStringAsFixed(0)
        : weight.toStringAsFixed(2);
