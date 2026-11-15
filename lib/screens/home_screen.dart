import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/ai_service.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/dashed_border.dart';
import '../widgets/mode_widgets.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
import 'menu_screen.dart';
import 'permission_screen.dart';
import 'record_screen.dart';

/// S-01 홈 (일정 관리): 이번 주 7일 + 고른 날의 일정 + 큰 마이크 버튼
/// 와이어프레임 5차: 메뉴 버튼, 끝난 일정 / 다음 일정 표시 (색약 모드는 점선·굵은 테두리 + 글자)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = ScheduleRepository.instance;
  DateTime _selected = dateOnly(DateTime.now());
  List<Schedule> _items = [];
  Map<String, int> _counts = {};

  DateTime get _today => dateOnly(DateTime.now());

  /// 고른 날이 들어 있는 주의 일요일
  DateTime get _weekStart =>
      _selected.subtract(Duration(days: _selected.weekday % 7));

  @override
  void initState() {
    super.initState();
    _repo.changes.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _repo.changes.removeListener(_onChanged);
    super.dispose();
  }

  /// 일정이 저장되면 그 날짜로 이동해서 보여준다
  void _onChanged() {
    final d = _repo.changes.date;
    if (d != null) _selected = dateOnly(d);
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.byDate(_selected);
    final counts =
        await _repo.countsBetween(_weekStart, _weekStart.add(const Duration(days: 6)));
    if (!mounted) return;
    setState(() {
      _items = items;
      _counts = counts;
    });
  }

  void _select(DateTime d) {
    setState(() => _selected = dateOnly(d));
    _load();
  }

  Future<void> _openCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '날짜 고르기',
      cancelText: '취소',
      confirmText: '이 날 보기',
    );
    if (picked != null) _select(picked);
  }

  Future<void> _startVoice() async {
    final granted = await Permission.microphone.isGranted;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => granted ? const RecordScreen() : const PermissionScreen(),
      ),
    );
    _load();
  }

  Future<void> _openNew() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(initialDate: _selected)),
    );
    _load();
  }

  Future<void> _openDetail(Schedule s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(scheduleId: s.id!)),
    );
    _load();
  }

  Future<void> _openMenu() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen()));
    _load();
  }

  /// 이미 지난 일정인지 (지난 날 / 오늘 시작 시각이 지남 / 끝나는 시각이 있으면 그 시각이 지남)
  bool _isDone(Schedule s, DateTime now) {
    final day = dateOnly(s.date);
    final today = dateOnly(now);
    if (day.isBefore(today)) return true;
    if (day.isAfter(today) || s.allDay || s.startMin == null) return false;
    final nowMin = now.hour * 60 + now.minute;
    return (s.endMin ?? s.startMin!) <= nowMin;
  }

  /// '말한대로' 글자를 길게 누르면 API 연결 테스트
  Future<void> _healthCheck() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final (ok, message) = await AiService.healthCheck();
    if (!mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ok ? '연결 성공' : '연결 실패'),
        content: Text(message, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = sameDay(_selected, _today);
    final colorBlind = SettingsScope.of(context).colorBlind;
    final now = DateTime.now();
    // 오늘이면 아직 시작 전인 첫 일정을 "다음 일정"으로 표시
    int? nextId;
    if (isToday) {
      for (final s in _items) {
        if (!s.allDay && s.startMin != null && !_isDone(s, now)) {
          nextId = s.id;
          break;
        }
      }
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _weekStrip(),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: _openCalendar,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline),
                  ),
                  child: const Text('달력 크게 보기'),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                children: [
                  Text(
                    '${isToday ? '오늘' : '이 날'} 일정 ${_items.length}개',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_items.isEmpty) _empty(),
                  for (final s in _items) ...[
                    _card(s, done: _isDone(s, now), next: s.id == nextId, colorBlind: colorBlind),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            _bottom(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onLongPress: _healthCheck,
                  child: const Text('말한대로',
                      style: TextStyle(fontSize: 16, color: AppColors.sub)),
                ),
              ),
              TextButton.icon(
                onPressed: _openMenu,
                icon: const Icon(Icons.menu_rounded, size: 24),
                label: const Text('메뉴'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text,
                  minimumSize: const Size(64, 44),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(formatDateKo(_selected),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () => _select(_today),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  minimumSize: const Size(64, 44),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                child: const Text('오늘로'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    const names = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(7, (i) {
          final d = _weekStart.add(Duration(days: i));
          final on = sameDay(d, _selected);
          final count = _counts[dateKey(d)] ?? 0;
          final mark = sameDay(d, _today) ? '오늘' : (count > 0 ? '● $count' : '');
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: on ? AppColors.text : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: on ? AppColors.text : AppColors.lightBorder, width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _select(d),
                  child: SizedBox(
                    height: 76,
                    child: DefaultTextStyle(
                      style: TextStyle(color: on ? Colors.white : AppColors.text),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(names[i], style: const TextStyle(fontSize: 14)),
                          Text('${d.day}',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          Text(mark,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _card(Schedule s, {required bool done, required bool next, required bool colorBlind}) {
    final primary = AppColors.primaryOf(context);
    final timeColor = done ? AppColors.disabledFg : primary;
    final textColor = done ? AppColors.sub : AppColors.text;

    final Widget time;
    if (s.allDay || s.startMin == null) {
      time = Text(s.allDay ? '종일' : '시간\n없음',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: timeColor));
    } else {
      final (period, hm) = formatTimeTwoLine(s.startMin!);
      time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(period, style: TextStyle(fontSize: 14, color: timeColor)),
          Text(hm,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: timeColor)),
        ],
      );
    }

    // 테두리: 끝남 = 점선(색약) / 연한 선, 다음 일정 = 굵은 선, 나머지 = 기본
    final BorderSide side;
    if (done) {
      side = colorBlind
          ? BorderSide.none // 점선은 DashedBorder가 그린다
          : const BorderSide(color: AppColors.lightBorder, width: 1.5);
    } else if (next) {
      side = BorderSide(color: primary, width: colorBlind ? 4 : 2.5);
    } else {
      side = BorderSide(
        color: colorBlind ? AppColors.ink : const Color(0xFFB5B5B0),
        width: colorBlind ? 2 : 1.5,
      );
    }

    Widget card = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: side),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (next) ...[
                TextTag(text: '▶ 다음 일정', filled: true, color: primary),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  SizedBox(width: 64, child: time),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 4),
                        Text(s.location ?? '장소 없음',
                            style: const TextStyle(fontSize: 16, color: AppColors.sub)),
                        if (s.isRepeat) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.repeat_rounded, size: 18, color: timeColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(Repeat.name(s.repeatRule!, s.date),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: timeColor)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (done)
                    const TextTag(text: '끝남', color: AppColors.sub)
                  else
                    const Text('자세히 ›', style: TextStyle(fontSize: 15, color: AppColors.sub)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (done && colorBlind) {
      card = DashedBorder(color: AppColors.border, radius: 14, child: card);
    }
    return card;
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB5B5B0), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Text('이 날은 일정이 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('아래 파란 버튼을 누르고\n일정을 말해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.sub, height: 1.5)),
        ],
      ),
    );
  }

  Widget _bottom() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          RoundActionButton(
            semanticLabel: '눌러서 말하기',
            onPressed: _startVoice,
            child: const Icon(Icons.mic_none_rounded, size: 52, color: Colors.white),
          ),
          const SizedBox(height: 10),
          const Text('눌러서 말하기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SecondaryButton(
            label: '손으로 직접 입력',
            icon: Icons.edit_outlined,
            onPressed: _openNew,
          ),
        ],
      ),
    );
  }
}
