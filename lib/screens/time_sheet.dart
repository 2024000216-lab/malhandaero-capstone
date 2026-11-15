import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 시간 고르기 결과 (allDay면 startMin은 null)
class TimePick {
  final bool allDay;
  final int? startMin;
  const TimePick.allDay()
      : allDay = true,
        startMin = null;
  const TimePick.at(int this.startMin) : allDay = false;
}

/// 와이어프레임 5차 02 — 시간 칸 하나만 고치는 바텀시트. 닫으면 null.
Future<TimePick?> showTimeSheet(
  BuildContext context, {
  required String? title,
  required int? currentMin,
  required bool allDay,
}) {
  return showModalBottomSheet<TimePick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TimeSheet(title: title, currentMin: currentMin, allDay: allDay),
  );
}

class _TimeSheet extends StatelessWidget {
  final String? title;
  final int? currentMin;
  final bool allDay;
  const _TimeSheet({required this.title, required this.currentMin, required this.allDay});

  static const _presets = [540, 720, 900, 1080]; // 오전 9시, 낮 12시, 오후 3시, 오후 6시

  Future<void> _pickOther(BuildContext context) async {
    final init = currentMin ?? 14 * 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
      helpText: '시간 고르기',
      cancelText: '취소',
      confirmText: '이 시간으로',
    );
    if (t == null || !context.mounted) return;
    Navigator.pop(context, TimePick.at(t.hour * 60 + t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(title!,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.sub)),
                      const SizedBox(height: 4),
                      const Text('몇 시로 바꿀까요?',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.grayBg,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size(64, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('닫기'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.1,
              children: [
                for (final m in _presets)
                  _option(
                    label: formatTime(m),
                    isCurrent: !allDay && currentMin == m,
                    primary: primary,
                    onTap: () => Navigator.pop(context, TimePick.at(m)),
                  ),
                _option(
                  label: '하루 종일',
                  isCurrent: allDay,
                  primary: primary,
                  onTap: () => Navigator.pop(context, const TimePick.allDay()),
                ),
                _option(
                  label: '다른 시간',
                  isCurrent: false,
                  primary: primary,
                  onTap: () => _pickOther(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SecondaryButton(label: '그대로 두기', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required String label,
    required bool isCurrent,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: isCurrent ? AppColors.iconBg : Colors.white,
        foregroundColor: AppColors.text,
        side: BorderSide(color: isCurrent ? primary : AppColors.border, width: isCurrent ? 3 : 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (isCurrent)
            Text('지금 시간',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: primary)),
        ],
      ),
    );
  }
}
