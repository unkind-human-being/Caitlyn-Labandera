import 'package:hive_flutter/hive_flutter.dart';

import '../services/sim_sms_service.dart';
import 'auth_service.dart';
import 'laundry_order.dart';
import 'sms_reminder.dart';

class AppStore {
  static const categories = <String>['Random', 'White', 'Blanket'];
  static const clothingItems = <String>[
    'Pants', 'T-shirt', 'Jacket', 'Dress', 'Blanket', 'Curtains',
  ];
  static const defaultPrices = <String, double>{
    'Random': 150, 'White': 350, 'Blanket': 500,
  };

  late final Box<dynamic> ordersBox;
  late final Box<dynamic> settingsBox;
  late final Box<dynamic> remindersBox;
  late final AuthService auth;

  Future<void> initialize() async {
    await Hive.initFlutter();
    // Keep V1 box names; upgrading does not delete existing customers.
    ordersBox = await Hive.openBox<dynamic>('laundry_orders_v1');
    settingsBox = await Hive.openBox<dynamic>('laundry_settings_v1');
    remindersBox = await Hive.openBox<dynamic>('laundry_sms_reminders_v1');
    if (!settingsBox.containsKey('prices')) {
      await settingsBox.put('prices', Map<String, double>.from(defaultPrices));
    }
    auth = AuthService(settingsBox);
    await auth.initialize();
    try {
      await refreshNativeSms();
      await syncAutoSms();
    } catch (error) {
      // A missing native installation must not prevent login to the shop.
      await settingsBox.put('smsLastError', error.toString());
    }
  }

  Map<String, double> get prices {
    final stored = settingsBox.get('prices');
    if (stored is! Map) return Map<String, double>.from(defaultPrices);
    return {
      for (final name in categories)
        name: (stored[name] is num)
            ? (stored[name] as num).toDouble() : defaultPrices[name]!,
    };
  }

  Future<void> updatePrices(Map<String, double> next) =>
      settingsBox.put('prices', Map<String, double>.from(next));

  List<LaundryOrder> get orders {
    final result = <LaundryOrder>[];
    for (final value in ordersBox.values) {
      if (value is Map) result.add(LaundryOrder.fromMap(value));
    }
    result.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    return result;
  }

  Future<void> saveOrder(LaundryOrder order) async {
    await ordersBox.put(order.id, order.toMap());
    await _syncWithoutBlockingCustomerSave();
  }

  Future<void> deleteOrder(String id) async {
    await ordersBox.delete(id);
    await remindersBox.delete(id);
    await _syncWithoutBlockingCustomerSave();
  }

  Future<void> _syncWithoutBlockingCustomerSave() async {
    try {
      await syncAutoSms();
    } catch (error) {
      await settingsBox.put('smsLastError', error.toString());
    }
  }

  bool get autoSmsEnabled => settingsBox.get('autoSmsEnabled', defaultValue: false) == true;
  int get smsMinutes => (settingsBox.get('autoSmsMinutes', defaultValue: 540) as num).toInt();
  String? get smsSchedulingError => settingsBox.get('smsLastError') as String?;

  /// Settings call this only after explicit yes/no approval and permission check.
  Future<int> updateAutoSms({required bool enabled, required int minutes}) async {
    final count = await SimSmsService.syncScheduled(
      enabled: enabled,
      minutesAfterMidnight: minutes,
      orders: orders.where((order) => order.smsOptIn && !order.claimed).toList(),
      alreadySentOrAttempted: (id) => reminderFor(id)?.attempted == true,
    );
    await settingsBox.put('autoSmsEnabled', enabled);
    await settingsBox.put('autoSmsMinutes', minutes);
    await settingsBox.delete('smsLastError');
    await refreshNativeSms();
    return count;
  }

  Future<int> syncAutoSms() async {
    final count = await SimSmsService.syncScheduled(
      enabled: autoSmsEnabled,
      minutesAfterMidnight: smsMinutes,
      orders: orders.where((order) => order.smsOptIn && !order.claimed).toList(),
      alreadySentOrAttempted: (id) => reminderFor(id)?.attempted == true,
    );
    await settingsBox.delete('smsLastError');
    await refreshNativeSms();
    return count;
  }

  SmsReminder? reminderFor(String orderId) {
    final value = remindersBox.get(orderId);
    return value is Map ? SmsReminder.fromMap(value) : null;
  }

  String smsStatusFor(String orderId) =>
      reminderFor(orderId)?.status ?? 'Not scheduled';

  Future<void> refreshNativeSms() async {
    final statuses = await SimSmsService.statuses();
    for (final status in statuses) {
      final id = status['id']?.toString();
      if (id == null || !ordersBox.containsKey(id)) continue;
      final existing = reminderFor(id);
      final updated = (existing ?? SmsReminder(
        orderId: id,
        preparedAt: DateTime.now(),
        confirmedSentAt: null,
        lastMessage: '',
      )).withNative(status);
      if (existing?.nativeStatus != updated.nativeStatus ||
          existing?.nativeDetail != updated.nativeDetail ||
          existing?.nativeUpdatedAt != updated.nativeUpdatedAt) {
        await remindersBox.put(id, updated.toMap());
      }
    }
  }
}
