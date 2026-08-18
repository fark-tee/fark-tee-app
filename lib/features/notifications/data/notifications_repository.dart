import '../models/notification_item.dart';

abstract class NotificationsRepository {
  Future<List<NotificationItem>> getNotifications();

  Future<void> markRead(String id);
}
