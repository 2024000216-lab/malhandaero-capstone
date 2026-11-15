import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/dashed_border.dart';
import '../widgets/mode_widgets.dart';

/// 와이어프레임 5차 04 — 설정 (색약 모드 + 미리보기, 크게 보기, 미리 알림 기본값)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                    child: TopTextButton(
                        label: '뒤로', withArrow: true, onPressed: () => Navigator.pop(context)),
                  ),
                  const Text('설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Divider(
              height: settings.colorBlind ? 2 : 1,
              thickness: settings.colorBlind ? 2 : 1,
              color: settings.colorBlind ? AppColors.ink : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                children: [
                  _ToggleTile(
                    title: '색약 모드',
                    description: '색 대신 모양과 글자로 보여줘요',
                    value: settings.colorBlind,
                    onChanged: settings.setColorBlind,
                  ),
                  const SizedBox(height: 14),
                  const _Preview(),
                  const SizedBox(height: 14),
                  _ToggleTile(
                    title: '크게 보기 모드',
                    description: '핵심 기능만 크게 보여줘요',
                    value: settings.largeMode,
                    onChanged: (v) {
                      settings.setLargeMode(v);
                      if (v) Navigator.popUntil(context, (r) => r.isFirst);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightBorder, width: 1.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('미리 알림',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text('새 일정에 자동으로 적용돼요',
                            style: TextStyle(fontSize: 16, color: AppColors.sub)),
                        const SizedBox(height: 12),
                        ChoiceGrid(
                          // 10분 전 / 30분 전 / 1시간 전
                          options: [for (final m in alarmChoices.reversed) '${beforeLabel(m)} 전'],
                          selected: '${beforeLabel(settings.defaultAlarm)} 전',
                          onSelect: (label) => settings.setDefaultAlarm(
                            alarmChoices.firstWhere((m) => '${beforeLabel(m)} 전' == label),
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

class _ToggleTile extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
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
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: value ? AppColors.ink : AppColors.lightBorder,
            width: value ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(description,
                          style: const TextStyle(fontSize: 16, color: AppColors.sub)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OnOffPill(on: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "켜면 이렇게 보여요" — 저장(꽉 찬 버튼 + ✓) / 지우기(점선 + ✕)
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.grayBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('켜면 이렇게 보여요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.sub)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColorBlind,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white),
                        SizedBox(width: 6),
                        Text('저장', style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashedBorder(
                    color: AppColors.ink,
                    strokeWidth: 3,
                    radius: 12,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded, color: AppColors.ink),
                          SizedBox(width: 6),
                          Text('지우기', style: label),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
