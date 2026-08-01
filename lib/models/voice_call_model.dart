enum VoiceCallStatus {
  ringing,
  accepted,
  declined,
  cancelled,
  missed,
  ended,
  failed,
}

class VoiceCall {
  const VoiceCall({
    required this.callId,
    required this.conversationId,
    this.taskId,
    required this.callerUid,
    required this.calleeUid,
    required this.status,
    required this.offer,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.endedByUid,
  });

  final String callId;
  final String conversationId;
  final String? taskId;
  final String callerUid;
  final String calleeUid;
  final VoiceCallStatus status;
  final Map<String, dynamic> offer;
  final Map<String, dynamic>? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? endedByUid;

  bool involves(String uid) => callerUid == uid || calleeUid == uid;

  String otherParticipant(String uid) =>
      callerUid == uid ? calleeUid : callerUid;

  int get durationSeconds {
    final start = answeredAt;
    final end = endedAt;
    if (start == null || end == null) return 0;
    return end.difference(start).inSeconds.clamp(0, 86400).toInt();
  }

  bool get isTerminal => switch (status) {
    VoiceCallStatus.declined ||
    VoiceCallStatus.cancelled ||
    VoiceCallStatus.missed ||
    VoiceCallStatus.ended ||
    VoiceCallStatus.failed => true,
    VoiceCallStatus.ringing || VoiceCallStatus.accepted => false,
  };

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'conversationId': conversationId,
      'taskId': taskId,
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'status': status.name,
      'offer': offer,
      'answer': answer,
      'createdAt': createdAt.toIso8601String(),
      'answeredAt': answeredAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'endedByUid': endedByUid,
    };
  }

  factory VoiceCall.fromMap(Map<dynamic, dynamic> map) {
    return VoiceCall(
      callId: map['callId'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      taskId: map['taskId'] as String?,
      callerUid: map['callerUid'] as String? ?? '',
      calleeUid: map['calleeUid'] as String? ?? '',
      status: VoiceCallStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => VoiceCallStatus.failed,
      ),
      offer: _stringMap(map['offer']),
      answer: map['answer'] == null ? null : _stringMap(map['answer']),
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
      answeredAt: _date(map['answeredAt']),
      endedAt: _date(map['endedAt']),
      endedByUid: map['endedByUid'] as String?,
    );
  }

  static Map<String, dynamic> _stringMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
