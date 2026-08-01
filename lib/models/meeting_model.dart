enum MeetingStatus { scheduled, completed, cancelled }

class MeetingDecision {
  final String decisionId;
  final String text;
  final String ownerUid;
  final String ownerName;
  final DateTime dueDate;
  final String? linkedTaskId;
  final bool isCompleted;
  final DateTime createdAt;

  const MeetingDecision({
    required this.decisionId,
    required this.text,
    required this.ownerUid,
    required this.ownerName,
    required this.dueDate,
    this.linkedTaskId,
    this.isCompleted = false,
    required this.createdAt,
  });

  MeetingDecision copyWith({String? linkedTaskId, bool? isCompleted}) =>
      MeetingDecision(
        decisionId: decisionId,
        text: text,
        ownerUid: ownerUid,
        ownerName: ownerName,
        dueDate: dueDate,
        linkedTaskId: linkedTaskId ?? this.linkedTaskId,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
    'decisionId': decisionId,
    'text': text,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'dueDate': dueDate.toIso8601String(),
    'linkedTaskId': linkedTaskId,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MeetingDecision.fromMap(Map<dynamic, dynamic> map) =>
      MeetingDecision(
        decisionId: map['decisionId'] as String? ?? '',
        text: map['text'] as String? ?? '',
        ownerUid: map['ownerUid'] as String? ?? '',
        ownerName: map['ownerName'] as String? ?? '',
        dueDate: DateTime.tryParse(map['dueDate']?.toString() ?? '') ??
            DateTime.now(),
        linkedTaskId: map['linkedTaskId'] as String?,
        isCompleted: map['isCompleted'] as bool? ?? false,
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Scheduled meeting plus its durable minutes and executable decisions.
/// Safe defaults keep every meeting created by the earlier scheduler valid.
class MeetingItem {
  final String meetingId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final String location;
  final String createdBy;
  final String createdByName;
  final List<String> participantUids;
  final DateTime createdAt;
  final List<String> agendaItems;
  final String minutes;
  final List<MeetingDecision> decisions;
  final MeetingStatus status;
  final DateTime updatedAt;

  MeetingItem({
    required this.meetingId,
    required this.title,
    required this.description,
    required this.startTime,
    this.endTime,
    required this.location,
    required this.createdBy,
    required this.createdByName,
    required this.participantUids,
    required this.createdAt,
    this.agendaItems = const [],
    this.minutes = '',
    this.decisions = const [],
    this.status = MeetingStatus.scheduled,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  MeetingItem copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<String>? participantUids,
    List<String>? agendaItems,
    String? minutes,
    List<MeetingDecision>? decisions,
    MeetingStatus? status,
    DateTime? updatedAt,
  }) => MeetingItem(
    meetingId: meetingId,
    title: title ?? this.title,
    description: description ?? this.description,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    location: location ?? this.location,
    createdBy: createdBy,
    createdByName: createdByName,
    participantUids: participantUids ?? this.participantUids,
    createdAt: createdAt,
    agendaItems: agendaItems ?? this.agendaItems,
    minutes: minutes ?? this.minutes,
    decisions: decisions ?? this.decisions,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'meetingId': meetingId,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'location': location,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'participantUids': participantUids,
    'createdAt': createdAt.toIso8601String(),
    'agendaItems': agendaItems,
    'minutes': minutes,
    'decisions': decisions.map((item) => item.toMap()).toList(),
    'status': status.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MeetingItem.fromMap(Map<dynamic, dynamic> map) {
    final created = DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return MeetingItem(
      meetingId: map['meetingId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startTime: DateTime.tryParse(map['startTime']?.toString() ?? '') ??
          DateTime.now(),
      endTime: DateTime.tryParse(map['endTime']?.toString() ?? ''),
      location: map['location'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      participantUids: List<String>.from(
        map['participantUids'] as List? ?? const [],
      ),
      createdAt: created,
      agendaItems: List<String>.from(
        map['agendaItems'] as List? ?? const [],
      ),
      minutes: map['minutes'] as String? ?? '',
      decisions: (map['decisions'] as List? ?? const [])
          .map((item) => MeetingDecision.fromMap(item as Map<dynamic, dynamic>))
          .toList(),
      status: MeetingStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => MeetingStatus.scheduled,
      ),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? created,
    );
  }
}
