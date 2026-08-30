import 'package:intl/intl.dart';

String _formatLocale = 'es';
String? _datePattern;
String? _timePattern;
bool _weekStartsMonday = true;

void configureTimeFormatting({
  required String languageCode,
  required String dateFormat,
  required String hourFormat,
  required bool weekStartsMonday,
}) {
  _formatLocale = languageCode;
  _datePattern = switch (dateFormat) {
    'dayMonthYear' => 'dd/MM/yyyy',
    'monthDayYear' => 'MM/dd/yyyy',
    _ => null,
  };
  _timePattern = switch (hourFormat) {
    'h12' => 'h:mm a',
    'h24' => 'HH:mm',
    _ => languageCode == 'en' ? 'h:mm a' : 'HH:mm',
  };
  _weekStartsMonday = weekStartsMonday;
  Intl.defaultLocale = languageCode;
}

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

DateTime startOfWeek(DateTime date, {bool? mondayFirst}) {
  final day = date.weekday;
  final offset = (mondayFirst ?? _weekStartsMonday) ? day - 1 : (day % 7);
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

String formatTimeOfDay(DateTime dt) =>
    DateFormat(_timePattern, _formatLocale).format(dt);

String formatDate(DateTime date) =>
    DateFormat(_datePattern ?? 'EEE d MMM', _formatLocale).format(date);

String formatFullDate(DateTime date) =>
    DateFormat(_datePattern ?? 'EEE d MMM y', _formatLocale).format(date);
