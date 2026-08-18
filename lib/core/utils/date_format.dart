/// Hand-rolled date/time formatting - no `intl` dependency for a handful of
/// fixed English formats.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _weekdaysFull = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

const _bangkokOffset = Duration(hours: 7);

/// All display formatting is pinned to Bangkok time (UTC+7), independent of
/// the device's local timezone.
DateTime _toBangkok(DateTime dt) => dt.toUtc().add(_bangkokOffset);

String formatTime12h(DateTime dt) {
  final bkk = _toBangkok(dt);
  final hour24 = bkk.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = bkk.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

String formatTime24h(DateTime dt) {
  final bkk = _toBangkok(dt);
  return '${bkk.hour.toString().padLeft(2, '0')}:${bkk.minute.toString().padLeft(2, '0')}';
}

String formatShortDate(DateTime dt) {
  final bkk = _toBangkok(dt);
  return '${_months[bkk.month - 1]} ${bkk.day}';
}

String formatLongDate(DateTime dt) {
  final bkk = _toBangkok(dt);
  return '${_weekdaysFull[bkk.weekday - 1]}, ${_monthsFull[bkk.month - 1]} ${bkk.day}, ${bkk.year}';
}

String formatRelative(DateTime dt) {
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatShortDate(dt);
}

/// "Tonight" / "Aug 20" style day label used on Groups/Home cards.
String formatDayLabel(DateTime dt) {
  final bkk = _toBangkok(dt);
  final now = _toBangkok(DateTime.now());
  final isSameDay =
      bkk.year == now.year && bkk.month == now.month && bkk.day == now.day;
  return isSameDay ? 'Tonight' : formatShortDate(dt);
}
