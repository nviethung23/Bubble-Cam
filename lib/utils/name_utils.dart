String safeFirstName(String? fullName) {
  final String normalized = (fullName ?? '').trim();
  if (normalized.isEmpty) return '';
  final parts = normalized.split(RegExp(r'\s+'));
  return parts.isNotEmpty ? parts.first : normalized;
}

String safeInitials(String? fullName) {
  final String normalized = (fullName ?? '').trim();
  if (normalized.isEmpty) return '';
  final parts = normalized.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    final part = parts.first;
    return part.isNotEmpty ? part[0].toUpperCase() : '';
  }
  final first = parts[0].isNotEmpty ? parts[0][0] : '';
  final second = parts[1].isNotEmpty ? parts[1][0] : '';
  return (first + second).toUpperCase();
}
