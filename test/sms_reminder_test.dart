import 'package:flutter_test/flutter_test.dart';
import 'package:caitlyn_laundry_shop/data/sms_reminder.dart';
import 'package:caitlyn_laundry_shop/services/sim_sms_service.dart';

void main() {
  test('V2 manually prepared SMS is not incorrectly marked sent', () {
    final record = SmsReminder(
      orderId: 'r1', preparedAt: DateTime(2026, 10, 15),
      confirmedSentAt: null, lastMessage: 'Your laundry is due for pickup.',
    );
    final restored = SmsReminder.fromMap(record.toMap());
    expect(restored.confirmedSentAt, isNull);
    expect(restored.status, contains('Prepared in SMS app'));
    expect(restored.wasSent, isFalse);
  });

  test('V2 manual sent status migrates', () {
    final record = SmsReminder(
      orderId: 'r2', preparedAt: DateTime(2026, 10, 15),
      confirmedSentAt: DateTime(2026, 10, 15, 12), lastMessage: 'Pickup',
    );
    expect(SmsReminder.fromMap(record.toMap()).wasSent, isTrue);
  });

  test('queued is not delivered or sent', () {
    final record = SmsReminder(
      orderId: 'r3', preparedAt: DateTime(2026, 10, 15),
      confirmedSentAt: null, lastMessage: 'Pickup', nativeStatus: 'queued',
    );
    expect(record.wasSent, isFalse);
    expect(record.attempted, isTrue);
    expect(record.status, contains('awaiting'));
  });

  test('native sent and delivered are accepted as sends', () {
    for (final state in ['sent', 'delivered']) {
      final record = SmsReminder(orderId: 'r3',
        preparedAt: DateTime(2026, 10, 15),
        confirmedSentAt: null, lastMessage: '', nativeStatus: state);
      expect(record.wasSent, isTrue);
    }
  });

  test('PH numbers are normalized to +63 and validated', () {
    expect(SimSmsService.normalizePhone('0917 123 4567'), '+639171234567');
    expect(SimSmsService.normalizePhone('639171234567'), '+639171234567');
    expect(SimSmsService.validPhMobile('12345'), isFalse);
    expect(() => SimSmsService.normalizePhone('12345'), throwsFormatException);
  });
}
