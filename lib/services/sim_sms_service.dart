import 'package:flutter/services.dart';

import '../data/laundry_order.dart';

/// Native Android SMS bridge. No SMS composer, no cloud and no internet needed.
/// WorkManager handles scheduled work even after the Flutter activity closes.
class SimSmsService {
  static const MethodChannel _channel = MethodChannel('caitlyn_laundry/sim_sms');

  static bool validPhMobile(String value) =>
      RegExp(r'^(09\d{9}|\+639\d{9}|639\d{9})$')
          .hasMatch(value.replaceAll(RegExp(r'[\s\-]'), ''));

  static String normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (!validPhMobile(cleaned)) {
      throw const FormatException('Enter a valid Philippine mobile number, e.g. 09171234567.');
    }
    if (cleaned.startsWith('09')) return '+63${cleaned.substring(1)}';
    if (cleaned.startsWith('639')) return '+$cleaned';
    return cleaned;
  }

  static String pickupMessage(LaundryOrder order) {
    // Short English template; non-GSM characters can reduce the SMS segment limit.
    final name = order.fullName.trim();
    final safeName = name.length > 28 ? '${name.substring(0, 28)}...' : name;
    return 'Hi $safeName, Caitlyn Laundry Shop: Your laundry '
        '${order.receiptId} is ready for pickup on '
        '${order.claimDate.month}/${order.claimDate.day}/${order.claimDate.year}. '
        'Please claim it. Thank you!';
  }

  /// The native app requests dangerous SEND_SMS permission via Android's dialog.
  static Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  static Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  static Future<bool> isSmsCapable() async =>
      await _channel.invokeMethod<bool>('isSmsCapable') ?? false;

  /// Returns a native request ID. Queued/requested is NOT the same as sent.
  static Future<String> sendTest({
    required String number,
    required String message,
  }) async {
    final id = await _channel.invokeMethod<String>('sendTest', {
      'phone': normalizePhone(number),
      'message': message.trim(),
    });
    if (id == null || id.isEmpty) throw StateError('SMS request was not accepted.');
    return id;
  }

  static Future<void> sendOrderNow({
    required LaundryOrder order,
    required String message,
  }) async {
    await _channel.invokeMethod<void>('sendOrderNow', {
      'id': order.id,
      'phone': normalizePhone(order.phoneNumber),
      'message': message.trim(),
    });
  }

  /// Enqueues/cancels one-time Android WorkManager tasks per eligible order.
  /// Native code enforces permission, opt-in and an idempotency ledger.
  static Future<int> syncScheduled({
    required bool enabled,
    required int minutesAfterMidnight,
    required List<LaundryOrder> orders,
    required bool Function(String) alreadySentOrAttempted,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final jobs = <Map<String, Object>>[];
    if (enabled) {
      for (final order in orders) {
        if (alreadySentOrAttempted(order.id)) continue;
        if (!validPhMobile(order.phoneNumber)) continue;
        final due = DateTime(order.claimDate.year, order.claimDate.month,
            order.claimDate.day, minutesAfterMidnight ~/ 60,
            minutesAfterMidnight % 60);
        // Never bulk-send overdue orders when automation is switched on.
        if (!due.isAfter(clock.add(const Duration(minutes: 1)))) continue;
        jobs.add({
          'id': order.id,
          'phone': normalizePhone(order.phoneNumber),
          'message': pickupMessage(order),
          'whenMs': due.millisecondsSinceEpoch,
        });
      }
    }
    final count = await _channel.invokeMethod<int>('syncScheduled', {
      'enabled': enabled,
      'jobs': jobs,
    });
    return count ?? 0;
  }

  static Future<List<Map<String, dynamic>>> statuses() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getStatuses');
    if (result == null) return [];
    return result
        .whereType<Map>()
        .map((value) => value.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}
