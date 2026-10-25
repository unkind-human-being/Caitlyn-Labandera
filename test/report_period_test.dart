import 'package:flutter_test/flutter_test.dart';
import 'package:caitlyn_laundry_shop/services/report_period.dart';

void main() {
  test('today starts at midnight and excludes tomorrow', () {
    final window = ReportPeriod.today.windowAt(DateTime(2026, 10, 15, 22));
    expect(window.contains(DateTime(2026, 10, 15, 0)), isTrue);
    expect(window.contains(DateTime(2026, 10, 15, 23, 59)), isTrue);
    expect(window.contains(DateTime(2026, 10, 16)), isFalse);
  });

  test('week starts Monday and ends before next Monday', () {
    final window = ReportPeriod.week.windowAt(DateTime(2026, 10, 15));
    expect(window.start, DateTime(2026, 10, 12));
    expect(window.end, DateTime(2026, 10, 19));
    expect(window.contains(DateTime(2026, 10, 18, 23, 59)), isTrue);
    expect(window.contains(DateTime(2026, 10, 19)), isFalse);
  });

  test('month and year handle rollover boundaries', () {
    final month = ReportPeriod.month.windowAt(DateTime(2026, 12, 23));
    final year = ReportPeriod.year.windowAt(DateTime(2026, 12, 23));
    expect(month.end, DateTime(2027, 1, 1));
    expect(year.end, DateTime(2027, 1, 1));
  });
}
