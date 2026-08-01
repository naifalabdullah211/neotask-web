import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/meeting_model.dart';
import '../services/firestore_service.dart';

class MeetingProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<MeetingItem> _meetings = [];
  List<MeetingItem> get meetings => _meetings;

  MeetingProvider() {
    FirestoreService.watchAllMeetings().listen((items) {
      _meetings = items;
      notifyListeners();
    });
  }

  MeetingItem? byId(String id) {
    for (final meeting in _meetings) {
      if (meeting.meetingId == id) return meeting;
    }
    return null;
  }

  List<MeetingItem> get upcoming => _meetings
      .where((meeting) => meeting.startTime.isAfter(DateTime.now()))
      .toList();

  List<MeetingItem> get past => _meetings
      .where((meeting) => !meeting.startTime.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime));

  List<MeetingItem> forUser(String uid) => _meetings
      .where(
        (meeting) =>
            meeting.createdBy == uid || meeting.participantUids.contains(uid),
      )
      .toList();

  Future<MeetingItem> createMeeting({
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    required String location,
    required String createdBy,
    required String createdByName,
    required List<String> participantUids,
    List<String> agendaItems = const [],
  }) async {
    final now = DateTime.now();
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
      createdAt: now,
      updatedAt: now,
      agendaItems: agendaItems,
    );
    await FirestoreService.saveMeeting(meeting);
    return meeting;
  }

  Future<void> saveMinutes(MeetingItem meeting, String minutes) =>
      FirestoreService.saveMeeting(
        meeting.copyWith(
          minutes: minutes.trim(),
          status: MeetingStatus.completed,
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> addDecision({
    required MeetingItem meeting,
    required String text,
    required String ownerUid,
    required String ownerName,
    required DateTime dueDate,
  }) async {
    final decision = MeetingDecision(
      decisionId: _uuid.v4(),
      text: text.trim(),
      ownerUid: ownerUid,
      ownerName: ownerName,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    await FirestoreService.saveMeeting(
      meeting.copyWith(
        decisions: [...meeting.decisions, decision],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> linkDecisionToTask({
    required MeetingItem meeting,
    required String decisionId,
    required String taskId,
  }) async {
    final decisions = meeting.decisions
        .map(
          (decision) => decision.decisionId == decisionId
              ? decision.copyWith(linkedTaskId: taskId)
              : decision,
        )
        .toList();
    await FirestoreService.saveMeeting(
      meeting.copyWith(decisions: decisions, updatedAt: DateTime.now()),
    );
  }

  Future<void> toggleDecision(MeetingItem meeting, String decisionId) async {
    final decisions = meeting.decisions
        .map(
          (decision) => decision.decisionId == decisionId
              ? decision.copyWith(isCompleted: !decision.isCompleted)
              : decision,
        )
        .toList();
    await FirestoreService.saveMeeting(
      meeting.copyWith(decisions: decisions, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteMeeting(String meetingId) =>
      FirestoreService.deleteMeeting(meetingId);
}
