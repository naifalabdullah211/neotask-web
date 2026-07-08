import 'package:flutter/foundation.dart';
import '../models/calendar_event_model.dart';
import '../services/ics_calendar_service.dart';
import '../services/local_db_service.dart';

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
    // URL persistence is stored per-user in the session/local box.
    _savedIcsUrl = LocalDbService.getUser(userUid) != null
        ? _readSavedUrl(userUid)
        : null;
    if (_savedIcsUrl != null && _savedIcsUrl!.isNotEmpty) {
      await syncNow(userUid, _savedIcsUrl!);
    }
  }

  String? _readSavedUrl(String userUid) {
    // Stored using a simple convention key inside sessionBox via LocalDbService.
    return LocalDbServiceIcsUrlStore.get(userUid);
  }

  Future<void> saveIcsUrl(String userUid, String url) async {
    _savedIcsUrl = url;
    await LocalDbServiceIcsUrlStore.set(userUid, url);
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
      await LocalDbService.clearCalendarEventsForUser(userUid);
      for (final ev in fetched) {
        await LocalDbService.saveCalendarEvent(userUid, ev);
      }

      _events = fetched;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'تعذّر مزامنة التقويم: ${e.toString()}';
      _events = LocalDbService.getCalendarEventsForUser(userUid);
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadCachedForUser(String userUid) {
    _events = LocalDbService.getCalendarEventsForUser(userUid);
    notifyListeners();
  }
}

/// Small helper namespace to persist each user's ICS feed URL using the
/// existing Hive session box (kept separate to avoid touching the core
/// LocalDbService's typed API surface).
class LocalDbServiceIcsUrlStore {
  static String _key(String uid) => 'ics_url_$uid';

  static String? get(String uid) {
    return _box().get(_key(uid)) as String?;
  }

  static Future<void> set(String uid, String url) async {
    await _box().put(_key(uid), url);
  }

  static dynamic _box() {
    return LocalDbService.getSessionBoxForIcs();
  }
}
