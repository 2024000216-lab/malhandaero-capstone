import 'package:flutter/material.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

/// 와이어프레임 5차 03 — 메뉴 (일정 관리 + 보기 설정 바로 켜기)
/// 보고서 모드는 제거했다.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Schedule> _today = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ScheduleRepository.instance.byDate(dateOnly(DateTime.now()));
    if (mounted) setState(() => _today = items);
  }

  String get _summary {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    Schedule? next;
    for (final s in _today) {
      if (!s.allDay && s.startMin != null && s.startMin! > nowMin) {
        next = s;
        break;
      }
    }
    final base = '오늘 ${_today.length}개';
    if (next == null) return '$base · 남은 일정이 없어요';
    return '$base · 다음 ${formatTime(next.startMin!)} ${next.title}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

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
                    child: TopTextButton(label: '닫기', onPressed: () => Navigator.pop(context)),
                  ),
                  const Text('메뉴', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  const _Label('무엇을 볼까요?'),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.text, width: 2),
                    ),
                    child: InkWell(
                      // 메뉴는 홈(일정 관리)에서 열리므로 닫으면 일정 관리로 돌아간다
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.iconBg,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.calendar_today_rounded,
                                      size: 30, color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('일정 관리',
                                          style: TextStyle(
                                              fontSize: 24, fontWeight: FontWeight.w800)),
                                      Text('보고, 고치고, 지워요',
                                          style: TextStyle(fontSize: 16, color: AppColors.sub)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 30),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.grayBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_summary, style: const TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _Label('보기 설정'),
                  const SizedBox(height: 14),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightBorder, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _QuickToggle(
                          title: '크게 보기',
                          description: '핵심 기능만 크게',
                          value: settings.largeMode,
                          onChanged: (v) {
                            settings.setLargeMode(v);
                            // 켜면 바로 큰 홈 화면으로
                            if (v) Navigator.popUntil(context, (r) => r.isFirst);
                          },
                        ),
                        const Divider(height: 1),
                        _QuickToggle(
                          title: '색약 모드',
                          description: '색 대신 모양과 글자로 구분',
                          value: settings.colorBlind,
                          onChanged: settings.setColorBlind,
                        ),
                        const Divider(height: 1),
                        Material(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            ),
                            child: const SizedBox(
                              height: 64,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text('설정 전체 보기',
                                          style: TextStyle(
                                              fontSize: 19, fontWeight: FontWeight.w700)),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: AppColors.sub),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.sub));
}

class _QuickToggle extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _QuickToggle({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      Text(description,
                          style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: value ? AppColors.text : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.text, width: 2),
                  ),
                  child: Text(
                    value ? '켜짐' : '꺼짐',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: value ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
