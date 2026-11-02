const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 월요일=월 … 일요일=일
String weekdayKo(DateTime d) => _weekdays[d.weekday - 1];

/// 10월 23일 금요일
String formatDateKo(DateTime d) => '${d.month}월 ${d.day}일 ${weekdayKo(d)}요일';

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-10-23 (DB 저장용)
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _period(int h) {
  if (h == 0) return '밤';
  if (h < 12) return '오전';
  if (h == 12) return '낮';
  return '오후';
}

/// 900 → 오후 3시, 870 → 오후 2시 30분
String formatTime(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '${_period(h)} $hh시${m > 0 ? ' $m분' : ''}';
}

/// 홈 카드용 두 줄 표기: ('오후', '3:00')
(String, String) formatTimeTwoLine(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hh = h % 12 == 0 ? 12 : h % 12;
  return (_period(h), '$hh:${_two(m)}');
}

/// "15:00" → 900
int? parseHm(String? s) {
  if (s == null) return null;
  final p = s.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// 받침이 있으면 '을', 없으면 '를'
String eulReul(String word) {
  if (word.isEmpty) return '를';
  final c = word.runes.last;
  if (c < 0xAC00 || c > 0xD7A3) return '를';
  return (c - 0xAC00) % 28 != 0 ? '을' : '를';
}

/// ['할 일', '시간'] → "할 일, 시간을 정해주세요"
String needMessage(List<String> missing) {
  final joined = missing.join(', ');
  return '$joined${eulReul(missing.last)} 정해주세요';
}

/// 60 → 1시간, 30 → 30분
String beforeLabel(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60}시간' : '$minutes분';
