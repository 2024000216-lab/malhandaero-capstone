import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'home_screen.dart';
import 'permission_screen.dart';
import 'record_screen.dart';

/// 와이어프레임 5차 06 — 크게 보기 홈: 다음 일정 하나만 크게
class LargeHomeScreen extends StatefulWidget {
  const LargeHomeScreen({super.key});

  @override
  State<LargeHomeScreen> createState() => _LargeHomeScreenState();
}

class _LargeHomeScreenState extends State<LargeHomeScreen> {
  final _repo = ScheduleRepository.instance;
  Schedule? _next;
  int _todayCount = 0;

  @override
  void initState() {
    super.initState();
    _repo.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _repo.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = dateOnly(now);
    final nowMin = now.hour * 60 + now.minute;
    final todayItems = await _repo.byDate(today);
    final upcoming = await _repo.upcoming(today);

    Schedule? next;
    for (final s in upcoming) {
      if (sameDay(s.date, today)) {
        // 오늘: 아직 시작 전인 일정만 (하루 종일은 제외)
        if (!s.allDay && s.startMin != null && s.startMin! > nowMin) {
          next = s;
          break;
        }
      } else {
        next = s;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _next = next;
      _todayCount = todayItems.length;
    });
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

  Future<void> _openAll() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: (c.maxHeight - 52).clamp(0.0, double.infinity)),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(formatDateKo(now),
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 18),
                    _nextCard(now),
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 112,
                      child: FilledButton(
                        onPressed: _startVoice,
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic_none_rounded, size: 40),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text('말로 일정 등록',
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 76,
                      child: OutlinedButton(
                        onPressed: _openAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.text, width: 3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('오늘 일정 모두 보기 ($_todayCount개)',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => AppSettings.instance.setLargeMode(false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.sub,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('보통 화면으로',
                          style: TextStyle(fontSize: 19, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nextCard(DateTime now) {
    final s = _next;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.text, width: 3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: s == null
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('다음 일정',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.sub)),
                SizedBox(height: 6),
                Text('남은 일정이 없어요',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('다음 일정',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.sub)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.text,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_whenLabel(s, now),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ),
                if (!sameDay(s.date, now))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(formatDateKo(s.date),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                Text(
                  s.allDay ? '하루 종일' : formatTime(s.startMin ?? 0),
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, height: 1.2),
                ),
                Text(s.title, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
                if (s.location != null)
                  Text(s.location!, style: const TextStyle(fontSize: 24, color: AppColors.sub)),
              ],
            ),
    );
  }

  /// "2시간 뒤", "30분 뒤", "내일", "3일 뒤"
  String _whenLabel(Schedule s, DateTime now) {
    final days = dateOnly(s.date).difference(dateOnly(now)).inDays;
    if (days == 1) return '내일';
    if (days > 1) return '$days일 뒤';
    final start = DateTime(s.date.year, s.date.month, s.date.day)
        .add(Duration(minutes: s.startMin ?? 0));
    final diff = start.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '${m < 1 ? 1 : m}분 뒤';
    return m == 0 ? '$h시간 뒤' : '$h시간 $m분 뒤';
  }
}
