import 'package:intl/intl.dart';

final _timeFormat = DateFormat('HH:mm');
final _monthDayFormat = DateFormat('MMM d');
final _monthDayYearFormat = DateFormat('MMM d, yyyy');
final _fullFormat = DateFormat('MMM d, yyyy HH:mm');

/// Timestamp for list rows: precise for recent items, coarser as they age.
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(date);

  if (difference.isNegative) return _timeFormat.format(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (date.year == current.year) return _monthDayFormat.format(date);

  return _monthDayYearFormat.format(date);
}

String formatFullDate(DateTime date) => _fullFormat.format(date);
