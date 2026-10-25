import 'package:flutter_test/flutter_test.dart';
import 'package:caitlyn_laundry_shop/data/laundry_order.dart';

void main() {
  test('existing customer records are not opted into SMS by migration', () {
    final old = LaundryOrder(
      id: 'consent-test', fullName: 'Maria', phoneNumber: '09171234567',
      category: 'White', weightKg: 1, pricePerKg: 350,
      registeredAt: DateTime(2026, 10, 15), claimDate: DateTime(2026, 10, 20),
      itemQuantities: const {}, notes: '',
    );
    final restored = LaundryOrder.fromMap(old.toMap());
    expect(restored.smsOptIn, isFalse);
    expect(restored.claimed, isFalse);
    expect(restored.copyWith(claimed: true).claimed, isTrue);
    expect(restored.copyWith(smsOptIn: true).smsOptIn, isTrue);
    expect(restored.smsOptIn, isFalse);
    expect(restored.claimed, isFalse);
    expect(restored.copyWith(claimed: true).claimed, isTrue);
  });

  test('calculates order totals with centavo rounding', () {
    final order = LaundryOrder(
      id: '123456789012',
      fullName: 'Maria Dela Cruz',
      phoneNumber: '09171234567',
      category: 'Random',
      weightKg: 2.25,
      pricePerKg: 150,
      registeredAt: DateTime(2026, 10, 15, 10),
      claimDate: DateTime(2026, 10, 18),
      itemQuantities: const {'Pants': 2, 'T-shirt': 3},
      notes: 'Please fold neatly.',
    );
    expect(order.total, 337.50);
    expect(order.itemSummary, contains('Pants ×2'));
    expect(order.receiptId, '#56789012');
  });

  test('stores and restores a price snapshot and all receipt data', () {
    final order = LaundryOrder(
      id: '111222333444',
      fullName: 'John Smith',
      phoneNumber: '+639181234567',
      category: 'White',
      weightKg: 1.5,
      pricePerKg: 350,
      registeredAt: DateTime(2026, 10, 15, 12),
      claimDate: DateTime(2026, 10, 17),
      itemQuantities: const {'Dress': 1},
      notes: '',
    );
    final restored = LaundryOrder.fromMap(order.toMap());
    expect(restored.fullName, 'John Smith');
    expect(restored.phoneNumber, '+639181234567');
    expect(restored.pricePerKg, 350);
    expect(restored.total, 525);
    expect(restored.claimDate, DateTime(2026, 10, 17));
    expect(restored.itemQuantities['Dress'], 1);
  });
}
