import 'package:flutter/material.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/schedule_options.dart';
import 'done_screen.dart';

/// S-07 직접 입력 / 일정 고치기 (같은 양식)
/// 위에서부터 1~6번 질문에 차례로 답하면 끝나도록 구성
/// 고치기가 끝나면 상세 화면이 다시 보여줄 일정 id를 돌려준다.
class EditScreen extends StatefulWidget {
  final Schedule? existing; // 있으면 "고치기"
  final DateTime? initialDate; // 홈에서 고른 날짜
  final RepeatScope? scope; // 반복 일정을 고칠 때: 이 날만 / 이 날부터 모두
  const EditScreen({super.key, this.existing, this.initialDate, this.scope});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final ScheduleDraft _d;
  late final TextEditingController _title;
  late final TextEditingController _place;
  bool _saving = false;

  static const _timePresets = {'오전 9시': 540, '낮 12시': 720, '오후 3시': 900, '오후 6시': 1080};

  bool get _isEdit => widget.existing != null;

  /// 반복 일정 중 이 날 하나만 고치는 경우 → 반복 질문을 보여주지 않는다
  bool get _thisOnly => widget.scope == RepeatScope.thisOnly;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _d = ScheduleDraft.fromSchedule(e);
      if (_thisOnly) _d.clearRepeat();
    } else {
      _d = ScheduleDraft()
        ..date = widget.initialDate == null ? null : dateOnly(widget.initialDate!);
    }
    _title = TextEditingController(text: _d.title ?? '');
    _place = TextEditingController(text: _d.location ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  // ───────── 날짜 ─────────

  DateTime get _today => dateOnly(DateTime.now());

  String? get _dateChoice {
    final d = _d.date;
    if (d == null) return null;
    for (var i = 0; i < 3; i++) {
      if (sameDay(d, _today.add(Duration(days: i)))) return ['오늘', '내일', '모레'][i];
    }
    return _customDateLabel(d);
  }

  String _customDateLabel(DateTime d) => '${d.month}월 ${d.day}일 (${weekdayKo(d)})';

  List<String> get _dateOptions {
    final c = _dateChoice;
    final last = (c != null && !['오늘', '내일', '모레'].contains(c)) ? c : '달력에서 고르기';
    return ['오늘', '내일', '모레', last];
  }

  Future<void> _pickDate(String label) async {
    const quick = {'오늘': 0, '내일': 1, '모레': 2};
    final off = quick[label];
    if (off != null) {
      setState(() => _d.date = _today.add(Duration(days: off)));
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _d.date ?? _today,
      firstDate: DateTime(_today.year - 1),
      lastDate: DateTime(_today.year + 5),
      helpText: '날짜 고르기',
      cancelText: '취소',
      confirmText: '이 날로',
    );
    if (picked != null) setState(() => _d.date = picked);
  }

  // ───────── 시간 ─────────

  String? get _timeChoice {
    if (_d.allDay) return '하루 종일';
    if (_d.startMin == null) return null;
    for (final e in _timePresets.entries) {
      if (e.value == _d.startMin) return e.key;
    }
    return formatTime(_d.startMin!);
  }

  List<String> get _timeOptions {
    final custom = (_d.startMin != null && !_timePresets.containsValue(_d.startMin))
        ? formatTime(_d.startMin!)
        : '직접 고르기';
    return [..._timePresets.keys, '하루 종일', custom];
  }

  Future<void> _pickTime(String label) async {
    if (label == '하루 종일') {
      setState(() {
        _d.allDay = true;
        _d.startMin = null;
        _d.endMin = null;
      });
      return;
    }
    final preset = _timePresets[label];
    if (preset != null) {
      setState(() {
        _d.allDay = false;
        _d.startMin = preset;
        _d.endMin = null;
      });
      return;
    }
    final init = _d.startMin ?? 14 * 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
      helpText: '시간 고르기',
      cancelText: '취소',
      confirmText: '이 시간으로',
    );
    if (t != null) {
      setState(() {
        _d.allDay = false;
        _d.startMin = t.hour * 60 + t.minute;
        _d.endMin = null;
      });
    }
  }

  // ───────── 저장 ─────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    _d.title = _title.text;
    _d.location = _place.text;
    final repo = ScheduleRepository.instance;
    if (_d.alarm) await NotificationService.requestPermission();

    if (_isEdit) {
      final e = widget.existing!;
      // 반복 일정을 "이 날부터 모두" 고치거나, 한 번짜리 일정을 반복으로 바꾸면
      // 기존 것을 지우고 새로 만든다.
      final remake = (e.isRepeat && !_thisOnly) || (!e.isRepeat && _d.repeatRule != null);
      if (remake) {
        if (e.isRepeat) {
          final ids = await repo.deleteSeriesFrom(e.repeatGroup!, e.date);
          await NotificationService.cancelAll(ids);
        } else {
          await repo.delete(e.id!);
          await NotificationService.cancel(e.id!);
        }
        final series = await repo.insertSeries(_d.toSchedule());
        await NotificationService.scheduleAll(series);
        if (mounted) Navigator.pop(context, series.first.id);
      } else {
        // 한 번짜리 일정 고치기, 또는 반복 일정 중 이 날만 고치기(반복에서 빠짐)
        final s = _d.toSchedule(id: e.id);
        await repo.update(s);
        await NotificationService.schedule(s);
        if (mounted) Navigator.pop(context, s.id);
      }
      return;
    }

    final series = await repo.insertSeries(_d.toSchedule());
    await NotificationService.scheduleAll(series);
    if (!mounted) return;
    final undo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DoneScreen(schedule: series.first)),
    );
    if (undo == true) {
      for (final s in series) {
        await repo.delete(s.id!);
      }
      await NotificationService.cancelAll(series.map((s) => s.id!));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    _d.title = _title.text;
    final missing = _d.missing;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TopTextButton(
                        label: '취소', onPressed: () => Navigator.pop(context)),
                  ),
                  Text(_isEdit ? (_thisOnly ? '이 날 일정만 고치기' : '일정 고치기') : '일정 직접 입력',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  const QuestionLabel('1. 무엇을 하나요?'),
                  BigTextField(
                    controller: _title,
                    hint: '예) 병원 예약',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 22),
                  const QuestionLabel('2. 언제 하나요?'),
                  ChoiceGrid(
                    options: _dateOptions,
                    selected: _dateChoice,
                    onSelect: _pickDate,
                    columns: 2,
                  ),
                  const SizedBox(height: 22),
                  const QuestionLabel('3. 몇 시인가요?'),
                  ChoiceGrid(
                    options: _timeOptions,
                    selected: _timeChoice,
                    onSelect: _pickTime,
                  ),
                  const SizedBox(height: 22),
                  const QuestionLabel('4. 어디서 하나요?', note: '(안 써도 돼요)'),
                  BigTextField(controller: _place, hint: '예) 동네 내과'),
                  const SizedBox(height: 22),
                  const QuestionLabel('5. 미리 알려드릴까요?'),
                  AlarmChoice(draft: _d, onChanged: () => setState(() {})),
                  if (!_thisOnly) ...[
                    const SizedBox(height: 22),
                    const QuestionLabel('6. 반복되는 일정인가요?', note: '(예: 매주 병원)'),
                    RepeatChoice(draft: _d, onChanged: () => setState(() {})),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: PrimaryButton(
                label: _isEdit ? '고친 내용 저장하기' : '저장하기',
                onPressed: missing.isEmpty && !_saving ? _save : null,
                disabledLabel: missing.isEmpty ? '저장하는 중…' : needMessage(missing),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
