/// A per-user "favorite/starred" marker on a task ("المفضلة").
///
/// Scoped to tasks only for this MVP (the app's core object) — kept as its
/// own small collection (rather than a boolean field on [AppTask]) so that
/// "favorite" is a per-USER relationship, not a shared task property: two
/// different employees/managers can each star the same task independently
/// without their choices interfering with one another.
class FavoriteTask {
  final String favoriteId;
  final String userUid;
  final String taskId;
  final DateTime createdAt;

  FavoriteTask({
    required this.favoriteId,
    required this.userUid,
    required this.taskId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'favoriteId': favoriteId,
      'userUid': userUid,
      'taskId': taskId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FavoriteTask.fromMap(Map<dynamic, dynamic> map) {
    return FavoriteTask(
      favoriteId: map['favoriteId'] as String,
      userUid: map['userUid'] as String? ?? '',
      taskId: map['taskId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
