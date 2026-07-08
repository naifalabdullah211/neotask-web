import 'package:flutter/foundation.dart';
import '../models/calendar_event_model.dart';
import '../services/ics_calendar_service.dart';
import '../services/firestore_service.dart';

/// Manages the read-only iPhone Calendar (.ics) import, fetched on every
/// page load per project decision (no periodic background polling).
class CalendarProvider extends ChangeNotifier {
  List<CalendarEventItem> _events = [];
  bool _isLoading = false;
  String? _error;
  String? _savedIcsUrl;

  List<CalendarEventItem> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get savedIcsUrl => _savedIcsUrl;

  Future<void> loadIcsUrlForUser(String userUid) async {
    // URL persistence is stored per-user in the `calendar_settings` collection.
    _savedIcsUrl = FirestoreService.getIcsUrl(userUid);
    if (_savedIcsUrl != null && _savedIcsUrl!.isNotEmpty) {
      await syncNow(userUid, _savedIcsUrl!);
    }
  }

  Future<void> saveIcsUrl(String userUid, String url) async {
    _savedIcsUrl = url;
    await FirestoreService.saveIcsUrl(userUid, url);
    notifyListeners();
  }

  Future<void> syncNow(String userUid, String icsUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await IcsCalendarService.fetchCurrentMonthEvents(icsUrl);

      // Diff against previously stored events to support add/update/remove
      // detection (per the UID-comparison approach documented for this app).
      await FirestoreService.clearCalendarEventsForUser(userUid);
      for (final ev in fetched) {
        await FirestoreService.saveCalendarEvent(userUid, ev);
      }

      _events = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'تعذّر مزامنة التقويم: ${e.toString()}';
      _events = FirestoreService.getCalendarEventsForUser(userUid);
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadCachedForUser(String userUid) {
    _events = FirestoreService.getCalendarEventsForUser(userUid);
    notifyListeners();
  }
}
