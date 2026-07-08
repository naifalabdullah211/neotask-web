/// Represents a single event imported (read-only) from an iCloud .ics feed.
class CalendarEventItem {
  final String uid; // stable UID from the ICS VEVENT block
  final String summary;
  final DateTime start;
  final DateTime? end;
  final bool isRecurringInstance;

  CalendarEventItem({
    required this.uid,
    required this.summary,
    required this.start,
    this.end,
    this.isRecurringInstance = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'summary': summary,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'isRecurringInstance': isRecurringInstance,
    };
  }

  factory CalendarEventItem.fromMap(Map<dynamic, dynamic> map) {
    return CalendarEventItem(
      uid: map['uid'] as String,
      summary: map['summary'] as String? ?? '',
      start: map['start'] != null
          ? DateTime.parse(map['start'] as String)
          : DateTime.now(),
      end: map['end'] != null ? DateTime.parse(map['end'] as String) : null,
      isRecurringInstance: map['isRecurringInstance'] as bool? ?? false,
    );
  }
}
