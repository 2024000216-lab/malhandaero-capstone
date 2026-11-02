import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// S-08 저장 완료 — 잠깐 뜨는 알림 대신 화면 전체로 저장 내용을 확인시킨다.
/// 일정 여러 개를 한 번에 저장한 경우 모두 보여준다.
/// 반복 일정은 첫 날 일정을 넘겨받아 반복 규칙과 함께 보여준다.
/// "되돌리기"를 누르면 true를 돌려주고, 이전 화면이 저장을 취소한다.
class DoneScreen extends StatelessWidget {
  final List<Schedule> schedules;

  /// 일정 1개 (편집 화면 등 기존 사용처)
  DoneScreen({super.key, required Schedule schedule}) : schedules = [schedule];

  /// 일정 여러 개
  const DoneScreen.many({super.key, required this.schedules});

  void _goHome(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  Widget _scheduleBox(Schedule s) => Box(
        child: Column(
          children: [
            InfoRow(label: '언제', value: '${formatDateKo(s.date)}\n${s.timeLabel}'),
            InfoRow(label: '어디서', value: s.location ?? '장소 없음'),
            InfoRow(label: '무엇을', value: s.title),
            if (s.repeatLabel != null) InfoRow(label: '반복', value: s.repeatLabel!),
            InfoRow(label: '알림', value: s.alarmLabel, last: true),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final many = schedules.length > 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(top: many ? 32 : 64, bottom: 16),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.success,
                          child: Icon(Icons.check_rounded, size: 52, color: Colors.white),
                        ),
                        const SizedBox(height: 18),
                        Text(many ? '일정 ${schedules.length}개를 저장했어요' : '저장했어요',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 24),
                        for (var i = 0; i < schedules.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _scheduleBox(schedules[i]),
                        ],
                      ],
                    ),
                  ),
                ),
                PrimaryButton(label: '확인', onPressed: () => _goHome(context)),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: many ? '잘못 저장했어요 (모두 되돌리기)' : '잘못 저장했어요 (되돌리기)',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
