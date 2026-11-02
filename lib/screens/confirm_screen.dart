import 'package:flutter/material.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/schedule_options.dart';
import 'done_screen.dart';
import 'record_screen.dart';

/// S-04 확인
/// - 한 번에 여러 일정을 말하면 하나씩 차례로 확인한 뒤 한꺼번에 저장
/// - 들은 문장에서 AI가 어느 부분을 날짜·시간·장소·할 일로 읽었는지 색+밑줄로 표시
/// - 아래 칸에도 같은 색 이름표를 붙여 연결
/// - 입력칸 대신 "바꾸기" 버튼, 시간은 큰 버튼으로 고르기
class ConfirmScreen extends StatefulWidget {
  final List<ExtractResult> results;
  const ConfirmScreen({super.key, required this.results});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _Mark {
  final int start;
  final int end;
  final Color bg;
  final Color fg;
  _Mark(this.start, this.end, this.bg, this.fg);
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final List<ExtractResult> _results;
  late final List<ScheduleDraft> _drafts;
  int _index = 0; // 지금 확인 중인 일정
  late bool _showTimeChoices;
  bool _saving = false;

  ScheduleDraft get _d => _drafts[_index];
  int get _count => _drafts.length;
  bool get _isLast => _index == _count - 1;

  static const _presets = {'오전 9시': 540, '낮 12시': 720, '오후 3시': 900, '오후 6시': 1080};

  @override
  void initState() {
    super.initState();
    _results = List.of(widget.results);
    _drafts = _results
        .map((r) => ScheduleDraft()
          ..title = r.title
          ..date = r.date
          ..startMin = r.startMin
          ..endMin = r.endMin
          ..allDay = r.allDay
          ..location = r.location
          ..transcript = r.transcript
          ..repeatRule = r.repeatRule
          ..repeatMonths = r.repeatRule == null ? null : r.repeatMonths
          ..repeatUntilDate = r.repeatRule == null ? null : r.repeatUntil)
        .toList();
    _showTimeChoices = !_d.hasTime;
  }

  // ───────── 여러 일정 넘기기 ─────────

  void _goTo(int i) {
    setState(() {
      _index = i;
      _showTimeChoices = !_d.hasTime;
    });
  }

  Future<void> _removeCurrent() async {
    final name = _d.title;
    final remove = await showBigConfirm(
      context,
      title: '이 일정은 빼고 저장할까요?',
      message: name == null ? '이 일정은 저장하지 않아요.' : '“$name” 일정은 저장하지 않아요.',
      safeLabel: '그대로 두기',
      dangerLabel: '이 일정 빼기',
    );
    if (!remove || !mounted) return;
    setState(() {
      _results.removeAt(_index);
      _drafts.removeAt(_index);
      if (_index >= _count) _index = _count - 1;
      _showTimeChoices = !_d.hasTime;
    });
  }

  /// 아직 다 채우지 않은 일정 중 첫 번째 (없으면 -1)
  int get _firstIncomplete => _drafts.indexWhere((d) => d.missing.isNotEmpty);

  // ───────── 바꾸기 ─────────

  Future<void> _changeDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _d.date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '날짜 고르기',
      cancelText: '취소',
      confirmText: '이 날로',
    );
    if (picked != null) setState(() => _d.date = picked);
  }

  Future<void> _changeText({required bool isTitle}) async {
    final v = await showTextInput(
      context,
      title: isTitle ? '무엇을 하나요?' : '어디서 하나요?',
      initial: isTitle ? _d.title : _d.location,
      hint: isTitle ? '예) 병원 예약' : '비워두면 장소 없음',
    );
    if (v == null) return;
    setState(() {
      if (isTitle) {
        _d.title = v.isEmpty ? null : v;
      } else {
        _d.location = v.isEmpty ? null : v;
      }
    });
  }

  String? get _timeChoice {
    if (_d.allDay) return '하루 종일';
    if (_d.startMin == null) return null;
    for (final e in _presets.entries) {
      if (e.value == _d.startMin) return e.key;
    }
    return formatTime(_d.startMin!); // 직접 고른 시간
  }

  List<String> get _timeOptions {
    final custom = (_d.startMin != null && !_presets.containsValue(_d.startMin))
        ? formatTime(_d.startMin!)
        : '직접 고르기';
    return [..._presets.keys, '하루 종일', custom];
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
    final preset = _presets[label];
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

  // ───────── 저장 / 나가기 ─────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ScheduleRepository.instance;
    if (_drafts.any((d) => d.alarm)) await NotificationService.requestPermission();

    // 반복 일정은 날짜마다 저장된다. 완료 화면에는 각 일정의 첫 날만 보여준다.
    final saved = <Schedule>[];
    final firsts = <Schedule>[];
    for (final d in _drafts) {
      final series = await repo.insertSeries(d.toSchedule());
      await NotificationService.scheduleAll(series);
      saved.addAll(series);
      firsts.add(series.first);
    }
    if (!mounted) return;

    final undo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DoneScreen.many(schedules: firsts)),
    );
    if (undo == true) {
      for (final s in saved) {
        await repo.delete(s.id!);
      }
      await NotificationService.cancelAll(saved.map((s) => s.id!));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _askLeave() async {
    final leave = await showBigConfirm(
      context,
      title: '저장하지 않고 나갈까요?',
      message: _count > 1
          ? '나가면 방금 말한 일정 $_count개가 모두 사라져요.'
          : '나가면 방금 말한 내용이 사라져요.',
      safeLabel: '계속 확인하기',
      dangerLabel: '저장 안 하고 나가기',
    );
    if (leave && mounted) Navigator.pop(context);
  }

  // ───────── 화면 ─────────

  @override
  Widget build(BuildContext context) {
    final missing = _d.missing;
    final firstIncomplete = _firstIncomplete;

    // 아래 파란 버튼: 마지막 일정이 아니면 "다음 일정", 마지막이면 "저장"
    final String primaryLabel;
    final VoidCallback? primaryAction;
    final String disabledLabel;
    if (!_isLast) {
      primaryLabel = '다음 일정 확인하기';
      primaryAction = missing.isEmpty ? () => _goTo(_index + 1) : null;
      disabledLabel = missing.isEmpty ? primaryLabel : needMessage(missing);
    } else {
      primaryLabel = _count > 1 ? '$_count개 모두 저장하기' : '저장하기';
      primaryAction = firstIncomplete == -1 && !_saving ? _save : null;
      disabledLabel = missing.isNotEmpty
          ? needMessage(missing)
          : firstIncomplete != -1
              ? '${firstIncomplete + 1}번째 일정을 마저 정해주세요'
              : '저장하는 중…';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          _goTo(_index - 1); // 뒤로 가기 = 이전 일정
        } else {
          _askLeave();
        }
      },
      child: Scaffold(
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
                      child: _index > 0
                          ? TopTextButton(
                              label: '이전',
                              withArrow: true,
                              onPressed: () => _goTo(_index - 1),
                            )
                          : TopTextButton(label: '취소', onPressed: _askLeave),
                    ),
                    const Text('이렇게 저장할까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  children: [
                    if (_count > 1) ...[
                      _progressRow(),
                      const SizedBox(height: 12),
                    ],
                    _heardBox(),
                    const SizedBox(height: 12),
                    Box(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _fieldRow(
                            tag: '날짜',
                            bg: AppColors.dateBg,
                            fg: AppColors.dateFg,
                            value: _d.date == null ? null : formatDateKo(_d.date!),
                            onChange: _changeDate,
                          ),
                          _timeRow(),
                          _fieldRow(
                            tag: '장소',
                            bg: AppColors.placeBg,
                            fg: AppColors.placeFg,
                            value: _d.location ?? '없음',
                            onChange: () => _changeText(isTitle: false),
                          ),
                          _fieldRow(
                            tag: '할 일',
                            bg: AppColors.titleBg,
                            fg: AppColors.titleFg,
                            value: _d.title,
                            onChange: () => _changeText(isTitle: true),
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Box(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('미리 알려드릴까요?',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          AlarmChoice(draft: _d, onChanged: () => setState(() {})),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Box(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('반복되는 일정인가요?',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          RepeatChoice(draft: _d, onChanged: () => setState(() {})),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  children: [
                    PrimaryButton(
                      label: primaryLabel,
                      onPressed: primaryAction,
                      disabledLabel: disabledLabel,
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: '다시 말하기',
                      height: 52,
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const RecordScreen())),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "일정 2개 중 1번째" + 이 일정 빼기
  Widget _progressRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.dateBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: '일정 $_count개 중 ',
                style: const TextStyle(fontSize: 18, color: AppColors.sub),
              ),
              TextSpan(
                text: '${_index + 1}번째',
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ])),
          ),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _removeCurrent,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: const Text('이 일정 빼기'),
            ),
          ),
        ],
      ),
    );
  }

  /// 들은 문장 + 색 하이라이트 (지금 확인 중인 일정 부분만)
  Widget _heardBox() {
    final r = _results[_index];
    final text = r.transcript;
    final marks = <_Mark>[];
    void add(String? span, Color bg, Color fg) {
      if (span == null || span.isEmpty) return;
      final i = text.indexOf(span);
      if (i < 0) return;
      final m = _Mark(i, i + span.length, bg, fg);
      final overlaps = marks.any((o) => m.start < o.end && o.start < m.end);
      if (!overlaps) marks.add(m);
    }

    add(r.spanDate, AppColors.dateBg, AppColors.dateFg);
    add(r.spanTime, AppColors.timeBg, AppColors.timeFg);
    add(r.spanLocation, AppColors.placeBg, AppColors.placeFg);
    add(r.spanTitle, AppColors.titleBg, AppColors.titleFg);
    marks.sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[const TextSpan(text: '“')];
    var pos = 0;
    for (final m in marks) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: TextStyle(
          backgroundColor: m.bg,
          decoration: TextDecoration.underline,
          decorationColor: m.fg,
          decorationThickness: 3,
        ),
      ));
      pos = m.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    spans.add(const TextSpan(text: '”'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('제가 들은 말', style: TextStyle(fontSize: 16, color: AppColors.sub)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: spans),
            style: const TextStyle(fontSize: 20, height: 1.9, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _changeButton(VoidCallback onPressed) => SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('바꾸기'),
        ),
      );

  /// value가 null이면 "못 들었어요"로 빨갛게 표시
  Widget _fieldRow({
    required String tag,
    required Color bg,
    required Color fg,
    required String? value,
    required VoidCallback onChange,
    bool last = false,
  }) {
    final missing = value == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: missing ? AppColors.warnBg : null,
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE6E6E2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tag(tag, bg, fg),
                const SizedBox(height: 4),
                Text(
                  value ?? '못 들었어요',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: missing ? AppColors.danger : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          _changeButton(onChange),
        ],
      ),
    );
  }

  Widget _timeRow() {
    final missing = !_d.hasTime;
    final value = _d.allDay
        ? '하루 종일'
        : _d.startMin == null
            ? '못 들었어요'
            : (_d.endMin != null
                ? '${formatTime(_d.startMin!)} ~ ${formatTime(_d.endMin!)}'
                : formatTime(_d.startMin!));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: missing ? AppColors.warnBg : null,
        border: const Border(bottom: BorderSide(color: Color(0xFFE6E6E2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tag('시간', AppColors.timeBg, AppColors.timeFg),
                    const SizedBox(height: 4),
                    Text(value,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: missing ? AppColors.danger : AppColors.text,
                        )),
                  ],
                ),
              ),
              if (!_showTimeChoices)
                _changeButton(() => setState(() => _showTimeChoices = true)),
            ],
          ),
          if (missing) ...[
            const SizedBox(height: 8),
            const Text('시간을 못 들었어요. 아래에서 골라주세요.',
                style: TextStyle(
                    fontSize: 17, color: AppColors.danger, fontWeight: FontWeight.w500)),
          ],
          if (_showTimeChoices) ...[
            const SizedBox(height: 10),
            ChoiceGrid(
              options: _timeOptions,
              selected: _timeChoice,
              onSelect: _pickTime,
            ),
          ],
        ],
      ),
    );
  }
}
