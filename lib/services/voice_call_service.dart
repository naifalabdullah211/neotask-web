import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import '../models/voice_call_model.dart';

class VoiceCallService {
  VoiceCallService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  static CollectionReference<Map<String, dynamic>> get _calls =>
      _db.collection('voice_calls');

  static String newCallId() => _uuid.v4();

  static Stream<VoiceCall?> watchCall(String callId) {
    return _calls.doc(callId).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : VoiceCall.fromMap(data);
    });
  }

  static Future<VoiceCall?> getCall(String callId) async {
    final snapshot = await _calls.doc(callId).get();
    final data = snapshot.data();
    return data == null ? null : VoiceCall.fromMap(data);
  }

  /// A single-field query keeps Firestore rules/indexing straightforward.
  /// Stale ringing calls are excluded client-side and finalized by the gate.
  static Stream<List<VoiceCall>> watchIncomingCalls(String calleeUid) {
    return _calls
        .where('calleeUid', isEqualTo: calleeUid)
        .snapshots()
        .map((snapshot) {
          final calls = snapshot.docs
              .map((document) => VoiceCall.fromMap(document.data()))
              .where((call) => call.status == VoiceCallStatus.ringing)
              .toList();
          calls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return calls;
        });
  }

  static Future<void> createCall(VoiceCall call) {
    return _calls.doc(call.callId).set(call.toMap());
  }

  static Future<void> acceptCall({
    required String callId,
    required Map<String, dynamic> answer,
  }) {
    return _calls.doc(callId).update({
      'status': VoiceCallStatus.accepted.name,
      'answer': answer,
      'answeredAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> addIceCandidate({
    required String callId,
    required bool fromCaller,
    required Map<String, dynamic> candidate,
  }) {
    final collection = fromCaller
        ? 'caller_candidates'
        : 'callee_candidates';
    return _calls.doc(callId).collection(collection).add(candidate);
  }

  static Stream<List<Map<String, dynamic>>> watchIceCandidates({
    required String callId,
    required bool fromCaller,
  }) {
    final collection = fromCaller
        ? 'caller_candidates'
        : 'callee_candidates';
    return _calls.doc(callId).collection(collection).snapshots().map(
      (snapshot) => snapshot.docs
          .map((document) => <String, dynamic>{
                'id': document.id,
                ...document.data(),
              })
          .toList(),
    );
  }

  /// Finalizes the call and appends exactly one deterministic call-log
  /// message in the same transaction. Retried taps or both peers observing
  /// the same terminal state cannot create duplicate chat entries.
  static Future<bool> finalizeCall({
    required String callId,
    required VoiceCallStatus status,
    required String actorUid,
  }) async {
    if (!status.isTerminalStatus) {
      throw ArgumentError.value(status, 'status', 'must be terminal');
    }

    final callRef = _calls.doc(callId);
    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(callRef);
      final data = snapshot.data();
      if (data == null) return false;
      final call = VoiceCall.fromMap(data);
      if (call.isTerminal) return false;

      final now = DateTime.now();
      final endedAt = now.toIso8601String();
      final duration = call.answeredAt == null
          ? 0
          : now
              .difference(call.answeredAt!)
              .inSeconds
              .clamp(0, 86400)
              .toInt();
      transaction.update(callRef, {
        'status': status.name,
        'endedAt': endedAt,
        'endedByUid': actorUid,
      });

      final otherUid = call.otherParticipant(actorUid);
      final messageId = 'call_$callId';
      final message = ChatMessage(
        messageId: messageId,
        conversationId: call.conversationId,
        taskId: call.taskId,
        senderUid: actorUid,
        recipientUid: otherUid,
        text: _logText(status, duration),
        attachmentType: 'call',
        timestamp: now,
      );
      transaction.set(_db.collection('messages').doc(messageId), message.toMap());
      return true;
    });
  }

  static String _logText(VoiceCallStatus status, int durationSeconds) {
    return switch (status) {
      VoiceCallStatus.ended =>
        'مكالمة صوتية منتهية · ${formatDuration(durationSeconds)}',
      VoiceCallStatus.declined => 'مكالمة صوتية مرفوضة',
      VoiceCallStatus.cancelled => 'مكالمة صوتية ملغاة',
      VoiceCallStatus.missed => 'مكالمة صوتية فائتة',
      VoiceCallStatus.failed => 'تعذّر إكمال المكالمة الصوتية',
      VoiceCallStatus.ringing || VoiceCallStatus.accepted => 'مكالمة صوتية',
    };
  }

  static String formatDuration(int seconds) {
    final safeSeconds = seconds.clamp(0, 86400).toInt();
    final minutes = safeSeconds ~/ 60;
    final remainder = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

extension on VoiceCallStatus {
  bool get isTerminalStatus => switch (this) {
    VoiceCallStatus.declined ||
    VoiceCallStatus.cancelled ||
    VoiceCallStatus.missed ||
    VoiceCallStatus.ended ||
    VoiceCallStatus.failed => true,
    VoiceCallStatus.ringing || VoiceCallStatus.accepted => false,
  };
}
