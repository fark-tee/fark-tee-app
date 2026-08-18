/// Derives display-only identity bits (initials, a fake @handle) from a name.
/// Used only by the mock data layer - real handles/initials should come from
/// the backend once one exists.
library;

String initialsFor(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String mockHandleFor(String displayName) {
  final slug = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '@$slug';
}
