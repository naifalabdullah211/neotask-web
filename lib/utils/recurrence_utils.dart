import '../models/task_model.dart';

/// Computes the next occurrence date for a recurring task, supporting
/// ALL recurrence options as requested: daily, weekly, monthly-fixed-date,
/// and monthly-weekday-pattern (e.g. "last Thursday of every month").
class RecurrenceUtils {
  static DateTime? computeNextOccurrence(AppTask task) {
    final base = task.dueDate;
    DateTime? next;

    switch (task.recurrenceType) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        next = base.add(const Duration(days: 1));
        break;
      case RecurrenceType.weekly:
        next = base.add(const Duration(days: 7));
        break;
      case RecurrenceType.monthlyFixedDate:
        final day = task.recurrenceDayOfMonth ?? base.day;
        next = _nextMonthWithDay(base, day);
        break;
      case RecurrenceType.monthlyWeekdayPattern:
        if (task.recurrenceWeekOrdinal != null &&
            task.recurrenceWeekday != null) {
          next = _nextMonthWeekdayPattern(
            base,
            task.recurrenceWeekOrdinal!,
            task.recurrenceWeekday!,
          );
        }
        break;
    }

    if (next != null &&
        task.recurrenceEndDate != null &&
        next.isAfter(task.recurrenceEndDate!)) {
      return null;
    }
    return next;
  }

  static DateTime _nextMonthWithDay(DateTime base, int day) {
    final targetMonth = DateTime(base.year, base.month + 1, 1);
    final daysInMonth =
        DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final clampedDay = day > daysInMonth ? daysInMonth : day;
    return DateTime(
        targetMonth.year, targetMonth.month, clampedDay, base.hour, base.minute);
  }

  static DateTime _nextMonthWeekdayPattern(
    DateTime base,
    WeekOrdinal ordinal,
    Weekday weekday,
  ) {
    final targetMonth = DateTime(base.year, base.month + 1, 1);
    return _weekdayOccurrenceInMonth(
        targetMonth.year, targetMonth.month, ordinal, weekday, base);
  }

  static DateTime _weekdayOccurrenceInMonth(
    int year,
    int month,
    WeekOrdinal ordinal,
    Weekday weekday,
    DateTime timeSource,
  ) {
    final targetWeekdayNum = weekday.index + 1; // Monday=1 ... Sunday=7
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final matchingDays = <int>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      if (date.weekday == targetWeekdayNum) {
        matchingDays.add(d);
      }
    }

    int chosenDay;
    switch (ordinal) {
      case WeekOrdinal.first:
        chosenDay = matchingDays.first;
        break;
      case WeekOrdinal.second:
        chosenDay = matchingDays.length >= 2 ? matchingDays[1] : matchingDays.last;
        break;
      case WeekOrdinal.third:
        chosenDay = matchingDays.length >= 3 ? matchingDays[2] : matchingDays.last;
        break;
      case WeekOrdinal.fourth:
        chosenDay = matchingDays.length >= 4 ? matchingDays[3] : matchingDays.last;
        break;
      case WeekOrdinal.last:
        chosenDay = matchingDays.last;
        break;
    }

    return DateTime(
        year, month, chosenDay, timeSource.hour, timeSource.minute);
  }

  static String recurrenceLabelAr(AppTask task) {
    switch (task.recurrenceType) {
      case RecurrenceType.none:
        return 'بدون تكرار';
      case RecurrenceType.daily:
        return 'يوميًا';
      case RecurrenceType.weekly:
        return 'أسبوعيًا';
      case RecurrenceType.monthlyFixedDate:
        return 'شهريًا (يوم ${task.recurrenceDayOfMonth ?? task.dueDate.day})';
      case RecurrenceType.monthlyWeekdayPattern:
        final ordinalAr = _ordinalAr(task.recurrenceWeekOrdinal);
        final weekdayAr = _weekdayAr(task.recurrenceWeekday);
        return 'شهريًا ($ordinalAr $weekdayAr من كل شهر)';
    }
  }

  static String _ordinalAr(WeekOrdinal? o) {
    switch (o) {
      case WeekOrdinal.first:
        return 'أول';
      case WeekOrdinal.second:
        return 'ثاني';
      case WeekOrdinal.third:
        return 'ثالث';
      case WeekOrdinal.fourth:
        return 'رابع';
      case WeekOrdinal.last:
        return 'آخر';
      case null:
        return '';
    }
  }

  static String _weekdayAr(Weekday? w) {
    switch (w) {
      case Weekday.monday:
        return 'اثنين';
      case Weekday.tuesday:
        return 'ثلاثاء';
      case Weekday.wednesday:
        return 'أربعاء';
      case Weekday.thursday:
        return 'خميس';
      case Weekday.friday:
        return 'جمعة';
      case Weekday.saturday:
        return 'سبت';
      case Weekday.sunday:
        return 'أحد';
      case null:
        return '';
    }
  }
}
