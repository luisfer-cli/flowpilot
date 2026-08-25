import 'package:intl/intl.dart';

/// Day key in the format yyyyMMdd (e.g. 20260820). Used for calendar queries.
int dayKey(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}

DateTime dateFromDayKey(int key) {
  final year = key ~/ 10000;
  final month = (key % 10000) ~/ 100;
  final day = key % 100;
  return DateTime(year, month, day);
}

/// Returns a date at 00:00:00 of the given [date].
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Returns the date at 23:59:59.999 of the given [date].
DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

DateTime startOfWeek(DateTime date, {bool mondayFirst = true}) {
  final day = date.weekday;
  final offset = mondayFirst ? day - 1 : (day % 7);
  return startOfDay(date).subtract(Duration(days: offset));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

/// Formats a duration in minutes as a human readable string, e.g. "1h 25m".
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String formatTimeOfDay(DateTime dt) => DateFormat.Hm().format(dt);

String formatDate(DateTime date) => DateFormat('EEE d MMM').format(date);

String formatFullDate(DateTime date) => DateFormat('EEE d MMM y').format(date);
