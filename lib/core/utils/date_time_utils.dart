/// Date and time helpers (kept dependency-free on purpose).
const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Midnight (local) of [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The day after [d], at local midnight (safe across daylight-saving changes).
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `yyyy-MM-dd`.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `yyyy-MM-ddTHH:mm` (local time, minute precision).
String isoDateTime(DateTime d) =>
    '${isoDate(d)}T${_two(d.hour)}:${_two(d.minute)}';

/// Parses [isoDate] / [isoDateTime] output back to a local [DateTime].
DateTime parseIso(String s) => DateTime.parse(s);

String formatTimeOfDay(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$h12:${_two(minute)} $suffix';
}

/// `8:30 PM`.
String formatTime(DateTime d) => formatTimeOfDay(d.hour, d.minute);

/// Formats minutes since midnight as `8:30 PM`.
String formatMinutes(int minutes) =>
    formatTimeOfDay(minutes ~/ 60, minutes % 60);

/// `Today`, `Tomorrow`, `Yesterday`, or `Mon, 5 Oct`.
String formatDayLabel(DateTime d, DateTime now) {
  final day = dateOnly(d);
  final today = dateOnly(now);
  if (day == today) return 'Today';
  if (day == nextDay(today)) return 'Tomorrow';
  if (nextDay(day) == today) return 'Yesterday';
  return '${_weekdayNames[day.weekday - 1].substring(0, 3)}, ${day.day} ${_monthNames[day.month - 1]}';
}

/// `Saturday, 3 October`.
String formatLongDate(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${_weekdayNames[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}
