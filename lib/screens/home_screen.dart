import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/ai_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
import 'permission_screen.dart';
import 'record_screen.dart';

/// S-01 홈: 이번 주 7일 + 고른 날의 일정 + 큰 마이크 버튼
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
                    _card(s),
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
          GestureDetector(
            onLongPress: _healthCheck,
            child: const Text('말한대로',
                style: TextStyle(fontSize: 16, color: AppColors.sub)),
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

  Widget _card(Schedule s) {
    final Widget time;
    if (s.allDay || s.startMin == null) {
      time = Text(s.allDay ? '종일' : '시간\n없음',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary));
    } else {
      final (period, hm) = formatTimeTwoLine(s.startMin!);
      time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(period,
              style: const TextStyle(fontSize: 14, color: AppColors.primary)),
          Text(hm,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      );
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFB5B5B0), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(width: 64, child: time),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s.location ?? '장소 없음',
                        style: const TextStyle(fontSize: 16, color: AppColors.sub)),
                    if (s.isRepeat) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(Repeat.name(s.repeatRule!, s.date),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Text('자세히 ›',
                  style: TextStyle(fontSize: 15, color: AppColors.sub)),
            ],
          ),
        ),
      ),
    );
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
