import '../utils/format.dart';

/// 저장된 일정 1개
class Schedule {
  final int? id;
  final String title;
  final DateTime date; // 날짜만 사용
  final int? startMin; // 자정부터 분 (15:00 → 900)
  final int? endMin;
  final bool allDay;
  final String? location;
  final String? memo;
  final bool alarm;
  final String? transcript; // 말로 등록한 경우 원래 문장

  const Schedule({
    this.id,
    required this.title,
    required this.date,
    this.startMin,
    this.endMin,
    this.allDay = false,
    this.location,
    this.memo,
    this.alarm = true,
    this.transcript,
  });

  Schedule copyWith({int? id}) => Schedule(
        id: id ?? this.id,
        title: title,
        date: date,
        startMin: startMin,
        endMin: endMin,
        allDay: allDay,
        location: location,
        memo: memo,
        alarm: alarm,
        transcript: transcript,
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
        'transcript': transcript,
      };

  factory Schedule.fromMap(Map<String, Object?> m) => Schedule(
        id: m['id'] as int?,
        title: m['title'] as String,
        date: parseDateKey(m['date'] as String),
        startMin: m['start_min'] as int?,
        endMin: m['end_min'] as int?,
        allDay: (m['all_day'] as int? ?? 0) == 1,
        location: m['location'] as String?,
        memo: m['memo'] as String?,
        alarm: (m['alarm'] as int? ?? 0) == 1,
        transcript: m['transcript'] as String?,
      );

  /// 하루 종일 → 당일 오전 9시, 시간 있음 → 10분 전
  DateTime? get alarmTime {
    if (!alarm) return null;
    final base = DateTime(date.year, date.month, date.day);
    if (allDay) return base.add(const Duration(hours: 9));
    if (startMin == null) return null;
    return base.add(Duration(minutes: startMin! - 10));
  }

  String get alarmLabel {
    if (!alarm) return '받지 않음';
    return allDay ? '당일 오전 9시에 알려드려요' : '10분 전에 알려드려요';
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
  bool alarm = true;
  String? transcript;

  ScheduleDraft();

  factory ScheduleDraft.fromSchedule(Schedule s) => ScheduleDraft()
    ..title = s.title
    ..date = s.date
    ..startMin = s.startMin
    ..endMin = s.endMin
    ..allDay = s.allDay
    ..location = s.location
    ..memo = s.memo
    ..alarm = s.alarm
    ..transcript = s.transcript;

  bool get hasTime => allDay || startMin != null;

  /// 저장하려면 아직 정해야 하는 것들
  List<String> get missing => [
        if (title == null || title!.trim().isEmpty) '할 일',
        if (date == null) '날짜',
        if (!hasTime) '시간',
      ];

  Schedule toSchedule({int? id}) => Schedule(
        id: id,
        title: title!.trim(),
        date: date!,
        startMin: allDay ? null : startMin,
        endMin: allDay ? null : endMin,
        allDay: allDay,
        location: (location == null || location!.trim().isEmpty) ? null : location!.trim(),
        memo: memo,
        alarm: alarm,
        transcript: transcript,
      );
}
