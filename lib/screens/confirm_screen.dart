import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/ai_service.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/schedule_options.dart';
import 'record_screen.dart';
import 'save_flow.dart';
import 'time_sheet.dart';

/// AI 결과 → 확인 화면용 초안 (크게 보기 확인 화면과 같이 사용)
List<ScheduleDraft> draftsFromResults(List<ExtractResult> results) => results
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

/// S-04 확인 (와이어프레임 5차 — 항목형)
/// - 한 번에 여러 일정을 말하면 하나씩 차례로 확인한 뒤 한꺼번에 저장
/// - 일정마다 번호 머리띠 + 날짜·시간·장소·할 일 칸, 칸마다 [고치기] / 빈 칸은 [넣기]
/// - 들은 문장에서 AI가 읽은 부분은 밑줄로 표시 (색약 모드는 굵은 밑줄만)
/// - 시간 고치기는 바텀시트, 시간을 못 들었으면 큰 버튼으로 바로 고르기
class ConfirmScreen extends StatefulWidget {
  final List<ExtractResult> results;
  const ConfirmScreen({super.key, required this.results});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _Mark {
  final int start;
  final int end;
  _Mark(this.start, this.end);
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final List<ExtractResult> _results;
  late final List<ScheduleDraft> _drafts;
  int _index = 0; // 지금 확인 중인 일정
  bool _saving = false;

  ScheduleDraft get _d => _drafts[_index];
  int get _count => _drafts.length;
  bool get _isLast => _index == _count - 1;

  static const _presets = {'오전 9시': 540, '낮 12시': 720, '오후 3시': 900, '오후 6시': 1080};

  @override
  void initState() {
    super.initState();
    _results = List.of(widget.results);
    _drafts = draftsFromResults(_results);
  }

  // ───────── 여러 일정 넘기기 ─────────

  void _goTo(int i) {
    setState(() => _index = i);
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

  Future<void> _openTimeSheet() async {
    final pick = await showTimeSheet(
      context,
      title: _d.title,
      currentMin: _d.startMin,
      allDay: _d.allDay,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _d.allDay = pick.allDay;
      _d.startMin = pick.startMin;
      _d.endMin = null;
    });
  }

  // ───────── 저장 / 나가기 ─────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await saveDraftsAndShowDone(context, _drafts);
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
                    _draftCard(),
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

  /// 들은 문장 + AI가 읽은 부분 밑줄 (지금 확인 중인 일정 부분만)
  Widget _heardBox() {
    final colorBlind = SettingsScope.of(context).colorBlind;
    final r = _results[_index];
    final text = r.transcript;
    final marks = <_Mark>[];
    void add(String? span) {
      if (span == null || span.isEmpty) return;
      final i = text.indexOf(span);
      if (i < 0) return;
      final m = _Mark(i, i + span.length);
      final overlaps = marks.any((o) => m.start < o.end && o.start < m.end);
      if (!overlaps) marks.add(m);
    }

    add(r.spanDate);
    add(r.spanTime);
    add(r.spanLocation);
    add(r.spanTitle);
    marks.sort((a, b) => a.start.compareTo(b.start));

    final markStyle = colorBlind
        ? const TextStyle(
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.ink,
            decorationThickness: 3,
          )
        : const TextStyle(
            backgroundColor: AppColors.dateBg,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
            decorationThickness: 3,
          );

    final spans = <TextSpan>[const TextSpan(text: '“')];
    var pos = 0;
    for (final m in marks) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      spans.add(TextSpan(text: text.substring(m.start, m.end), style: markStyle));
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
          const Text('제가 들은 말',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.sub)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: spans),
            style: const TextStyle(fontSize: 20, height: 1.9, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  /// 번호 머리띠 + 날짜·시간·장소·할 일 칸
  Widget _draftCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.text, width: 2.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Text('${_index + 1}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _d.title ?? '할 일을 정해주세요',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          _fieldRow(
            icon: Icons.calendar_today_rounded,
            label: '날짜',
            value: _d.date == null ? null : formatDateKo(_d.date!),
            onEdit: _changeDate,
            first: true,
          ),
          _timeRow(),
          _fieldRow(
            icon: Icons.place_outlined,
            label: '장소',
            value: _d.location,
            emptyText: '없음',
            emptyIsMissing: false,
            onEdit: () => _changeText(isTitle: false),
          ),
          _fieldRow(
            icon: Icons.check_rounded,
            label: '할 일',
            value: _d.title,
            onEdit: () => _changeText(isTitle: true),
          ),
        ],
      ),
    );
  }

  Widget _editButton(String label, VoidCallback onPressed) {
    final primary = AppColors.primaryOf(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(72, 48),
          side: BorderSide(color: primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _iconCircle(IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: AppColors.grayBg, shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: AppColors.text),
      );

  /// value가 null이면: 꼭 필요한 칸은 "못 들었어요"(빨간 글자 + 연한 배경), 장소는 "없음"
  Widget _fieldRow({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onEdit,
    String emptyText = '못 들었어요',
    bool emptyIsMissing = true,
    bool first = false,
  }) {
    final empty = value == null || value.isEmpty;
    final missing = empty && emptyIsMissing;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: missing ? AppColors.warnBg : Colors.white,
        border: first ? null : const Border(top: BorderSide(color: Color(0xFFE6E6E2), width: 1.5)),
      ),
      child: Row(
        children: [
          _iconCircle(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.sub)),
                Text(
                  empty ? emptyText : value!,
                  style: TextStyle(
                    fontSize: empty && !missing ? 20 : 22,
                    fontWeight: empty && !missing ? FontWeight.w500 : FontWeight.w800,
                    color: missing
                        ? AppColors.danger
                        : (empty ? AppColors.disabledFg : AppColors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _editButton(empty ? '넣기' : '고치기', onEdit),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: missing ? AppColors.warnBg : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE6E6E2), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                _iconCircle(Icons.schedule_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('시간',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.sub)),
                      Text(value,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: missing ? AppColors.danger : AppColors.text,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!missing) _editButton('고치기', _openTimeSheet),
              ],
            ),
          ),
          // 시간을 못 들었으면 큰 버튼으로 바로 고르기 (와이어프레임 4차 "하나만 더")
          if (missing) ...[
            const SizedBox(height: 8),
            const Text('몇 시에 하세요? 아래에서 골라주세요.',
                style: TextStyle(
                    fontSize: 17, color: AppColors.danger, fontWeight: FontWeight.w700)),
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
