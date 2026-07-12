import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/meeting_model.dart';
import '../services/firestore_service.dart';

class MeetingProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<MeetingItem> _meetings = [];
  List<MeetingItem> get meetings => _meetings;

  MeetingProvider() {
    _listen();
  }

  void _listen() {
    FirestoreService.watchAllMeetings().listen((items) {
      _meetings = items;
      notifyListeners();
    });
  }

  List<MeetingItem> get upcoming {
    final now = DateTime.now();
    return _meetings.where((m) => m.startTime.isAfter(now)).toList();
  }

  List<MeetingItem> get past {
    final now = DateTime.now();
    return _meetings.where((m) => !m.startTime.isAfter(now)).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<MeetingItem> forUser(String uid) {
    return _meetings
        .where((m) => m.createdBy == uid || m.participantUids.contains(uid))
        .toList();
  }

  Future<void> createMeeting({
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    required String location,
    required String createdBy,
    required String createdByName,
    required List<String> participantUids,
  }) async {
    final meeting = MeetingItem(
      meetingId: _uuid.v4(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      location: location,
      createdBy: createdBy,
      createdByName: createdByName,
      participantUids: participantUids,
      createdAt: DateTime.now(),
    );
    await FirestoreService.saveMeeting(meeting);
  }

  Future<void> deleteMeeting(String meetingId) async {
    await FirestoreService.deleteMeeting(meetingId);
  }
}
