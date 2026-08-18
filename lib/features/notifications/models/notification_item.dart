enum NotificationType {
  meetupInvitation,
  meetupAccepted,
  meetupStartingSoon,
  locationSharingStarted,
  friendArrived,
  meetupCancelled,
  headingHome,
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.timestamp,
    this.body,
    this.read = false,
    this.relatedMeetupId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final DateTime timestamp;
  final bool read;
  final String? relatedMeetupId;

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    timestamp: timestamp,
    read: read ?? this.read,
    relatedMeetupId: relatedMeetupId,
  );
}
