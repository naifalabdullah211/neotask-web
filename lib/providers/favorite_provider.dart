import 'package:flutter/foundation.dart';
import '../models/favorite_model.dart';
import '../services/firestore_service.dart';

/// Per-user starred/favorite tasks ("المفضلة"). See favorite_model.dart for
/// why this is its own collection rather than a boolean field on AppTask.
///
/// Unlike TaskProvider/MessageProvider (which cache a filtered slice
/// in-memory), this provider stays a thin pass-through to
/// FirestoreService's already-live `favorites` cache/stream and simply
/// re-broadcasts changes so widgets watching THIS provider rebuild too.
class FavoriteProvider extends ChangeNotifier {
  FavoriteProvider() {
    _subscribeToChanges();
  }

  void _subscribeToChanges() {
    // Re-notify on every favorites collection change so any screen using
    // context.watch<FavoriteProvider>() re-renders (e.g. a star icon's
    // filled/outlined state) without each screen managing its own stream.
    FirestoreService.watchFavoritesForUser('').listen((_) {
      notifyListeners();
    });
  }

  bool isFavorite(String userUid, String taskId) {
    return FirestoreService.isFavorite(userUid, taskId);
  }

  List<FavoriteTask> favoritesForUser(String userUid) {
    return FirestoreService.getFavoritesForUser(userUid);
  }

  Stream<List<FavoriteTask>> watchFavoritesForUser(String userUid) {
    return FirestoreService.watchFavoritesForUser(userUid);
  }

  Future<void> toggleFavorite(String userUid, String taskId) async {
    final id = FirestoreService.favoriteIdFor(userUid, taskId);
    if (FirestoreService.isFavorite(userUid, taskId)) {
      await FirestoreService.removeFavorite(id);
    } else {
      final favorite = FavoriteTask(
        favoriteId: id,
        userUid: userUid,
        taskId: taskId,
        createdAt: DateTime.now(),
      );
      await FirestoreService.saveFavorite(favorite);
    }
    notifyListeners();
  }
}
