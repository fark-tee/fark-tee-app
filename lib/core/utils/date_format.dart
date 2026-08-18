/// Hand-rolled date/time formatting - no `intl` dependency for a handful of
/// fixed English formats.
library;

const _months = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

const _monthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

const _weekdaysFull = [
  'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์',
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
  if (diff.inSeconds < 60) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return 'เมื่อ ${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return 'เมื่อ ${diff.inHours} ชม. ที่แล้ว';
  if (diff.inDays < 7) return 'เมื่อ ${diff.inDays} วันที่แล้ว';
  return formatShortDate(dt);
}

/// "Tonight" / "Aug 20" style day label used on Groups/Home cards.
String formatDayLabel(DateTime dt) {
  final bkk = _toBangkok(dt);
  final now = _toBangkok(DateTime.now());
  final isSameDay =
      bkk.year == now.year && bkk.month == now.month && bkk.day == now.day;
  return isSameDay ? 'คืนนี้' : formatShortDate(dt);
}
