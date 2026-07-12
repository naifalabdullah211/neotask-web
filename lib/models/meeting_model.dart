/// A scheduled meeting entry (title/time/location/participants) visible to
/// both manager and employee under "الاجتماعات". This is a scheduling
/// record ONLY — there is no live audio/video call integration; joining a
/// meeting happens outside the app (in person, phone, or a link pasted
/// into [location]).
class MeetingItem {
  final String meetingId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final String location;
  final String createdBy; // uid
  final String createdByName;
  final List<String> participantUids;
  final DateTime createdAt;

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
  });

  Map<String, dynamic> toMap() {
    return {
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
    };
  }

  factory MeetingItem.fromMap(Map<dynamic, dynamic> map) {
    return MeetingItem(
      meetingId: map['meetingId'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'] as String)
          : DateTime.now(),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      location: map['location'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      participantUids: map['participantUids'] != null
          ? List<String>.from(map['participantUids'] as List)
          : <String>[],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
