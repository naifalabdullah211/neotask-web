import 'package:http/http.dart' as http;
import '../models/calendar_event_model.dart';

/// Reads a public iCloud calendar (.ics feed, RFC 5545) — READ ONLY.
/// Fetches on every page load per project decision (no background polling).
///
/// LIMITATIONS documented explicitly (per prior discussion in this project):
/// - This is one-directional: iPhone Calendar -> App. Writing back to the
///   iPhone Calendar is NOT supported by this approach (would require
///   CalDAV write access or native EventKit, neither in current scope).
/// - RRULE (recurring event) expansion here is a simplified implementation
///   covering FREQ=DAILY/WEEKLY/MONTHLY with COUNT or UNTIL. Complex BYDAY
///   combinations are only partially supported.
class IcsCalendarService {
  /// Converts a webcal:// link to https:// (webcal is just an alias scheme).
  static String normalizeUrl(String url) {
    if (url.startsWith('webcal://')) {
      return url.replaceFirst('webcal://', 'https://');
    }
    return url;
  }

  static Future<List<CalendarEventItem>> fetchCurrentMonthEvents(
    String icsUrl,
  ) async {
    final normalized = normalizeUrl(icsUrl.trim());
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      throw Exception('رابط التقويم غير صالح');
    }

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'تعذّر تحميل ملف التقويم (رمز الاستجابة: ${response.statusCode})',
      );
    }

    final events = _parseIcs(response.body);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(seconds: 1));

    return _expandAndFilter(events, monthStart, monthEnd);
  }

  static List<_RawVEvent> _parseIcs(String icsContent) {
    final lines = _unfoldLines(icsContent);
    final events = <_RawVEvent>[];

    Map<String, String>? current;
    for (final line in lines) {
      if (line.trim() == 'BEGIN:VEVENT') {
        current = {};
      } else if (line.trim() == 'END:VEVENT') {
        if (current != null) {
          events.add(_RawVEvent(current));
          current = null;
        }
      } else if (current != null) {
        final idx = line.indexOf(':');
        if (idx > 0) {
          final rawKey = line.substring(0, idx);
          final value = line.substring(idx + 1);
          final key = rawKey.split(';').first.toUpperCase();
          current[key] = value;
        }
      }
    }
    return events;
  }

  /// iCalendar allows folded (wrapped) lines starting with a space/tab.
  static List<String> _unfoldLines(String content) {
    final rawLines = content.split(RegExp(r'\r\n|\n|\r'));
    final result = <String>[];
    for (final line in rawLines) {
      if (line.isNotEmpty && (line.startsWith(' ') || line.startsWith('\t'))) {
        if (result.isNotEmpty) {
          result[result.length - 1] += line.substring(1);
        }
      } else {
        result.add(line);
      }
    }
    return result;
  }

  static DateTime? _parseIcsDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final cleaned = raw.trim();
    try {
      if (cleaned.endsWith('Z')) {
        return DateTime.parse(cleaned).toLocal();
      }
      // Format: YYYYMMDDTHHMMSS or YYYYMMDD
      if (cleaned.contains('T')) {
        final y = int.parse(cleaned.substring(0, 4));
        final mo = int.parse(cleaned.substring(4, 6));
        final d = int.parse(cleaned.substring(6, 8));
        final h = int.parse(cleaned.substring(9, 11));
        final mi = int.parse(cleaned.substring(11, 13));
        final s = cleaned.length >= 15
            ? int.parse(cleaned.substring(13, 15))
            : 0;
        return DateTime(y, mo, d, h, mi, s);
      } else if (cleaned.length >= 8) {
        final y = int.parse(cleaned.substring(0, 4));
        final mo = int.parse(cleaned.substring(4, 6));
        final d = int.parse(cleaned.substring(6, 8));
        return DateTime(y, mo, d);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static List<CalendarEventItem> _expandAndFilter(
    List<_RawVEvent> raw,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final results = <CalendarEventItem>[];

    for (final ev in raw) {
      final uid = ev.fields['UID'] ?? UniqueKey.generate();
      final summary = ev.fields['SUMMARY'] ?? 'بدون عنوان';
      final start = _parseIcsDate(ev.fields['DTSTART']);
      final end = _parseIcsDate(ev.fields['DTEND']);
      final rrule = ev.fields['RRULE'];

      if (start == null) continue;

      if (rrule == null) {
        if (!start.isBefore(monthStart) && !start.isAfter(monthEnd)) {
          results.add(
            CalendarEventItem(
              uid: uid,
              summary: summary,
              start: start,
              end: end,
            ),
          );
        }
        continue;
      }

      // Simplified RRULE expansion: FREQ=DAILY|WEEKLY|MONTHLY with COUNT/UNTIL
      final ruleParts = <String, String>{};
      for (final part in rrule.split(';')) {
        final kv = part.split('=');
        if (kv.length == 2) ruleParts[kv[0]] = kv[1];
      }
      final freq = ruleParts['FREQ'];
      final until = _parseIcsDate(ruleParts['UNTIL']);
      final count = int.tryParse(ruleParts['COUNT'] ?? '');
      final interval = int.tryParse(ruleParts['INTERVAL'] ?? '') ?? 1;

      DateTime cursor = start;
      int occurrences = 0;
      const maxIterations = 500; // safety cap
      int iterations = 0;

      while (iterations < maxIterations) {
        iterations++;
        if (until != null && cursor.isAfter(until)) break;
        if (count != null && occurrences >= count) break;

        if (!cursor.isBefore(monthStart) && !cursor.isAfter(monthEnd)) {
          results.add(
            CalendarEventItem(
              uid: '$uid-${cursor.toIso8601String()}',
              summary: summary,
              start: cursor,
              end: end,
              isRecurringInstance: true,
            ),
          );
        }
        occurrences++;

        if (cursor.isAfter(monthEnd) && (count == null && until == null)) {
          // Unbounded recurrence: stop once we've passed the target month.
          break;
        }

        switch (freq) {
          case 'DAILY':
            cursor = cursor.add(Duration(days: interval));
            break;
          case 'WEEKLY':
            cursor = cursor.add(Duration(days: 7 * interval));
            break;
          case 'MONTHLY':
            cursor = DateTime(
              cursor.year,
              cursor.month + interval,
              cursor.day,
              cursor.hour,
              cursor.minute,
            );
            break;
          default:
            iterations = maxIterations; // unsupported freq, stop
        }

        if (cursor.isAfter(monthEnd) && until == null && count == null) {
          break;
        }
      }
    }

    results.sort((a, b) => a.start.compareTo(b.start));
    return results;
  }
}

class _RawVEvent {
  final Map<String, String> fields;
  _RawVEvent(this.fields);
}

class UniqueKey {
  static int _counter = 0;
  static String generate() {
    _counter++;
    return 'evt-${DateTime.now().millisecondsSinceEpoch}-$_counter';
  }
}
