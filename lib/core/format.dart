// Small formatting helpers (no intl dependency needed).

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _group(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

/// R1 234 (whole rands) or R12.50 when there are cents and the value is small.
String rands(int cents) {
  final whole = cents ~/ 100;
  final rem = (cents % 100).abs();
  if (rem == 0 || whole.abs() >= 1000) return 'R${_group(whole)}';
  return 'R${_group(whole)}.${rem.toString().padLeft(2, '0')}';
}

int randsToCents(double rands) => (rands * 100).round();

String two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String weekday(DateTime d) => _weekdays[d.weekday - 1];

String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "Today 18:00", "Tomorrow 06:00", "Thu 18:00"
String whenLabel(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final prefix = diff == 0
      ? 'Today'
      : diff == 1
          ? 'Tomorrow'
          : diff == -1
              ? 'Yesterday'
              : weekday(d);
  return '$prefix ${hhmm(d)}';
}

String timeAgo(DateTime d, DateTime now) {
  final m = now.difference(d).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  final h = m ~/ 60;
  if (h < 24) return '$h h ago';
  final days = h ~/ 24;
  return days == 1 ? 'yesterday' : '$days days ago';
}

String hoursLabel(double hours) {
  if (hours < 1) return '${(hours * 60).round()} min';
  final rounded = (hours * 2).round() / 2;
  return rounded == rounded.roundToDouble() ? '${rounded.round()} h' : '$rounded h';
}

String percent(double p) => '${(p * 100).round()}%';

/// Lowercase slug used as an area id, e.g. "Soweto Zone 6" -> "soweto-zone-6".
String slug(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

/// Greeting for the resident's local time:
/// 05:00-11:59 morning, 12:00-16:59 afternoon, 17:00-04:59 evening.
String greetingFor(DateTime time) {
  final hour = time.toLocal().hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}
