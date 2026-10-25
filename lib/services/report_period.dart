/// An inclusive-start, exclusive-end time window in local device time.
class ReportWindow {
  final DateTime start;
  final DateTime end;
  const ReportWindow(this.start, this.end);

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(end);
}

enum ReportPeriod { today, week, month, year }

extension ReportPeriodInfo on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.week:
        return 'This Week';
      case ReportPeriod.month:
        return 'This Month';
      case ReportPeriod.year:
        return 'This Year';
    }
  }

  ReportWindow windowAt(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportPeriod.today:
        return ReportWindow(day, day.add(const Duration(days: 1)));
      case ReportPeriod.week:
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return ReportWindow(monday, monday.add(const Duration(days: 7)));
      case ReportPeriod.month:
        return ReportWindow(
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1),
        );
      case ReportPeriod.year:
        return ReportWindow(DateTime(now.year), DateTime(now.year + 1));
    }
  }
}
