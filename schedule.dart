import '../utils/format.dart';

/// 반복 규칙
class Repeat {
  static const weekly = 'weekly'; // 매주
  static const biweekly = 'biweekly'; // 2주마다
  static const monthly = 'monthly'; // 매달
  static const all = [weekly, biweekly, monthly];

  /// 한 번에 만들 수 있는 최대 횟수 (알림 예약 수 제한 대비)
  static const maxCount = 60;

  /// 반복 시작일부터 끝나는 날까지의 날짜 목록 (반복이 없으면 시작일 하나)
  static List<DateTime> dates(DateTime start, String? rule, DateTime? until) {
    final s = dateOnly(start);
    if (rule == null || until == null) return [s];
    final end = dateOnly(until);
    final out = <DateTime>[];
    for (var i = 0; i < maxCount; i++) {
      final d = _nth(s, rule, i);
      if (d.isAfter(end)) break;
      out.add(d);
    }
    return out.isEmpty ? [s] : out;
  }

  static DateTime _nth(DateTime s, String rule, int i) {
    switch (rule) {
      case weekly:
        return DateTime(s.year, s.month, s.day + 7 * i);
      case biweekly:
        return DateTime(s.year, s.month, s.day + 14 * i);
      case monthly:
        // 31일처럼 없는 날은 그 달의 마지막 날로
        final lastDay = DateTime(s.year, s.month + i + 1, 0).day;
        return DateTime(s.year, s.month + i, s.day > lastDay ? lastDay : s.day);
      default:
        return s;
    }
  }

  /// "매주 목요일", "2주마다 목요일", "매달 5일" (날짜를 모르면 "매주"처럼 짧게)
  static String name(String rule, DateTime? date) {
    switch (rule) {
      case weekly:
        return date == null ? '매주' : '매주 ${weekdayKo(date)}요일';
      case biweekly:
        return date == null ? '2주마다' : '2주마다 ${weekdayKo(date)}요일';
      case monthly:
        return date == null ? '매달' : '매달 ${date.day}일';
      default:
        return '';
    }
  }

  /// 시작일에서 n달 뒤의 전날 (11월 5일 + 한 달 → 12월 4일)
  static DateTime untilAfterMonths(DateTime start, int months) {
    final s = dateOnly(start);
    return DateTime(s.year, s.month + months, s.day - 1);
  }
}

/// 미리 알림 선택지 (분). null이면 알림 받지 않음
const alarmChoices = [60, 30, 10];

/// 저장된 일정 1개 (반복 일정은 날짜마다 1개씩 저장하고 repeatGroup으로 묶는다)
class Schedule {
  final int? id;
  final String title;
  final DateTime date; // 날짜만 사용
  final int? startMin; // 자정부터 분 (15:00 → 900)
  final int? endMin;
  final bool allDay;
  final String? location;
  final String? memo;
  final int? alarmBefore; // 몇 분 전에 알림 (null이면 알림 없음)
  final String? transcript; // 말로 등록한 경우 원래 문장
  final String? repeatRule; // Repeat.weekly 등 (null이면 한 번만)
  final DateTime? repeatUntil;
  final String? repeatGroup; // 같은 반복 일정끼리 같은 값

  const Schedule({
    this.id,
    required this.title,
    required this.date,
    this.startMin,
    this.endMin,
    this.allDay = false,
    this.location,
    this.memo,
    this.alarmBefore = 10,
    this.transcript,
    this.repeatRule,
    this.repeatUntil,
    this.repeatGroup,
  });

  bool get alarm => alarmBefore != null;
  bool get isRepeat => repeatGroup != null && repeatRule != null;

  Schedule copyWith({
    int? id,
    DateTime? date,
    String? repeatGroup,
    bool clearRepeat = false,
  }) =>
      Schedule(
        id: id ?? this.id,
        title: title,
        date: date ?? this.date,
        startMin: startMin,
        endMin: endMin,
        allDay: allDay,
        location: location,
        memo: memo,
        alarmBefore: alarmBefore,
        transcript: transcript,
        repeatRule: clearRepeat ? null : repeatRule,
        repeatUntil: clearRepeat ? null : repeatUntil,
        repeatGroup: clearRepeat ? null : (repeatGroup ?? this.repeatGroup),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'date': dateKey(date),
        'start_min': startMin,
        'end_min': endMin,
        'all_day': allDay ? 1 : 0,
        'location': location,
        'memo': memo,
        'alarm': alarm ? 1 : 0,
        'alarm_before': alarmBefore,
        'transcript': transcript,
        'repeat_rule': repeatRule,
        'repeat_until': repeatUntil == null ? null : dateKey(repeatUntil!),
        'repeat_group': repeatGroup,
      };

  factory Schedule.fromMap(Map<String, Object?> m) {
    final until = m['repeat_until'] as String?;
    return Schedule(
      id: m['id'] as int?,
      title: m['title'] as String,
      date: parseDateKey(m['date'] as String),
      startMin: m['start_min'] as int?,
      endMin: m['end_min'] as int?,
      allDay: (m['all_day'] as int? ?? 0) == 1,
      location: m['location'] as String?,
      memo: m['memo'] as String?,
      alarmBefore: (m['alarm'] as int? ?? 0) == 1 ? (m['alarm_before'] as int? ?? 10) : null,
      transcript: m['transcript'] as String?,
      repeatRule: m['repeat_rule'] as String?,
      repeatUntil: until == null ? null : parseDateKey(until),
      repeatGroup: m['repeat_group'] as String?,
    );
  }

  /// 하루 종일 → 당일 오전 9시, 시간 있음 → alarmBefore분 전
  DateTime? get alarmTime {
    if (alarmBefore == null) return null;
    final base = DateTime(date.year, date.month, date.day);
    if (allDay) return base.add(const Duration(hours: 9));
    if (startMin == null) return null;
    return base.add(Duration(minutes: startMin! - alarmBefore!));
  }

  String get alarmLabel {
    if (alarmBefore == null) return '받지 않음';
    return allDay ? '당일 오전 9시에 알려드려요' : '${beforeLabel(alarmBefore!)} 전에 알려드려요';
  }

  /// "매주 목요일 · 12월 4일까지" (반복이 아니면 null)
  String? get repeatLabel {
    if (repeatRule == null || repeatUntil == null) return null;
    return '${Repeat.name(repeatRule!, date)} · ${repeatUntil!.month}월 ${repeatUntil!.day}일까지';
  }

  String get timeLabel {
    if (allDay) return '하루 종일';
    if (startMin == null) return '시간 없음';
    if (endMin != null) return '${formatTime(startMin!)} ~ ${formatTime(endMin!)}';
    return formatTime(startMin!);
  }
}

/// 확인·입력 화면에서 아직 다 채워지지 않은 일정
class ScheduleDraft {
  String? title;
  DateTime? date;
  int? startMin;
  int? endMin;
  bool allDay = false;
  String? location;
  String? memo;
  int? alarmBefore = defaultAlarmBefore;
  String? transcript;

  /// 새 일정의 미리 알림 기본값 (설정 화면에서 바꾸면 AppSettings가 갱신)
  static int defaultAlarmBefore = 10;

  // 반복: 기간(몇 달 동안)으로 고르면 repeatMonths, 날짜로 고르면 repeatUntilDate
  String? repeatRule;
  int? repeatMonths;
  DateTime? repeatUntilDate;

  ScheduleDraft();

  factory ScheduleDraft.fromSchedule(Schedule s) => ScheduleDraft()
    ..title = s.title
    ..date = s.date
    ..startMin = s.startMin
    ..endMin = s.endMin
    ..allDay = s.allDay
    ..location = s.location
    ..memo = s.memo
    ..alarmBefore = s.alarmBefore
    ..transcript = s.transcript
    ..repeatRule = s.repeatRule
    ..repeatUntilDate = s.repeatUntil;

  bool get alarm => alarmBefore != null;
  bool get hasTime => allDay || startMin != null;

  /// 반복이 끝나는 날 (반복이 없으면 null)
  DateTime? get repeatUntil {
    if (repeatRule == null) return null;
    if (repeatMonths != null && date != null) {
      return Repeat.untilAfterMonths(date!, repeatMonths!);
    }
    return repeatUntilDate;
  }

  /// 반복해서 만들어질 날짜들
  List<DateTime> get repeatDates =>
      date == null ? const [] : Repeat.dates(date!, repeatRule, repeatUntil);

  void clearRepeat() {
    repeatRule = null;
    repeatMonths = null;
    repeatUntilDate = null;
  }

  /// 저장하려면 아직 정해야 하는 것들
  List<String> get missing {
    final until = repeatUntil;
    return [
      if (title == null || title!.trim().isEmpty) '할 일',
      if (date == null) '날짜',
      if (!hasTime) '시간',
      if (repeatRule != null && (until == null || (date != null && until.isBefore(date!))))
        '반복 끝나는 날',
    ];
  }

  Schedule toSchedule({int? id}) => Schedule(
        id: id,
        title: title!.trim(),
        date: date!,
        startMin: allDay ? null : startMin,
        endMin: allDay ? null : endMin,
        allDay: allDay,
        location: (location == null || location!.trim().isEmpty) ? null : location!.trim(),
        memo: memo,
        alarmBefore: alarmBefore,
        transcript: transcript,
        repeatRule: repeatRule,
        repeatUntil: repeatUntil,
      );
}
