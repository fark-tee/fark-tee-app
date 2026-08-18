import 'package:flutter/foundation.dart';

import 'data/notifications_repository.dart';
import 'models/notification_item.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({required NotificationsRepository repository})
    : _repository = repository;

  final NotificationsRepository _repository;

  bool loading = false;
  List<NotificationItem> notifications = [];

  int get unreadCount => notifications.where((n) => !n.read).length;

  Future<void> load() async {
    // No `notifyListeners()` before the await - `load()` is called from
    // `initState`, while the widget tree is still building, and notifying
    // synchronously there throws ("markNeedsBuild called during build").
    loading = true;
    notifications = await _repository.getNotifications();
    loading = false;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(read: true);
      notifyListeners();
    }
  }
}
