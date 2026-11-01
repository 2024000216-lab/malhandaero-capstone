import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// S-08 저장 완료 — 잠깐 뜨는 알림 대신 화면 전체로 저장 내용을 확인시킨다.
/// "되돌리기"를 누르면 true를 돌려주고, 이전 화면이 저장을 취소한다.
class DoneScreen extends StatelessWidget {
  final Schedule schedule;
  const DoneScreen({super.key, required this.schedule});

  void _goHome(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final s = schedule;
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
                    padding: const EdgeInsets.only(top: 64),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.success,
                          child: Icon(Icons.check_rounded, size: 52, color: Colors.white),
                        ),
                        const SizedBox(height: 18),
                        const Text('저장했어요',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 24),
                        Box(
                          child: Column(
                            children: [
                              InfoRow(
                                  label: '언제',
                                  value: '${formatDateKo(s.date)}\n${s.timeLabel}'),
                              InfoRow(label: '어디서', value: s.location ?? '장소 없음'),
                              InfoRow(label: '무엇을', value: s.title),
                              InfoRow(label: '알림', value: s.alarmLabel, last: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PrimaryButton(label: '확인', onPressed: () => _goHome(context)),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: '잘못 저장했어요 (되돌리기)',
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
