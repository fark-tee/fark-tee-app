import '../models/notification_item.dart';
import 'notifications_repository.dart';

class MockNotificationsRepository implements NotificationsRepository {
  final List<NotificationItem> _items = [
    NotificationItem(
      id: 'n1',
      type: NotificationType.meetupInvitation,
      title: 'Maya invited you to Dinner @ Nobu Downtown',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      relatedMeetupId: 'meetup-100',
    ),
    NotificationItem(
      id: 'n2',
      type: NotificationType.meetupAccepted,
      title: 'Alex Chen accepted your invite to Dinner @ Nobu Downtown',
      timestamp: DateTime.now().subtract(const Duration(minutes: 32)),
      relatedMeetupId: 'meetup-100',
    ),
    NotificationItem(
      id: 'n3',
      type: NotificationType.locationSharingStarted,
      title: 'Location sharing started for Dinner @ Nobu Downtown',
      body: 'You can now see where everyone is.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      relatedMeetupId: 'meetup-100',
    ),
    NotificationItem(
      id: 'n4',
      type: NotificationType.friendArrived,
      title: 'Alex Chen has arrived at Nobu Downtown',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
      relatedMeetupId: 'meetup-100',
      read: true,
    ),
    NotificationItem(
      id: 'n5',
      type: NotificationType.meetupStartingSoon,
      title: 'Rooftop · Soho House starts in 3 days',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      relatedMeetupId: 'meetup-101',
      read: true,
    ),
    NotificationItem(
      id: 'n6',
      type: NotificationType.headingHome,
      title: 'Riley is heading home from Nobu Dinner',
      timestamp: DateTime.now().subtract(const Duration(days: 20, hours: 2)),
      read: true,
    ),
    NotificationItem(
      id: 'n7',
      type: NotificationType.meetupCancelled,
      title: 'Gallery Opening — 47 Canal was cancelled',
      timestamp: DateTime.now().subtract(const Duration(days: 66)),
      read: true,
    ),
  ];

  static const _networkDelay = Duration(milliseconds: 300);

  @override
  Future<List<NotificationItem>> getNotifications() async {
    await Future.delayed(_networkDelay);
    final sorted = List<NotificationItem>.from(_items)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  @override
  Future<void> markRead(String id) async {
    await Future.delayed(_networkDelay);
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(read: true);
  }
}
