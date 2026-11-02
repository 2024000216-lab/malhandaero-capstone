import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';

/// 미리 알림 고르기: 1시간 전 / 30분 전 / 10분 전 / 받지 않음
/// 하루 종일 일정은 당일 아침 9시 / 받지 않음
class AlarmChoice extends StatelessWidget {
  final ScheduleDraft draft;
  final VoidCallback onChanged; // draft를 바꾼 뒤 부르는 콜백 (부모가 setState)

  const AlarmChoice({super.key, required this.draft, required this.onChanged});

  static const _off = '받지 않음';
  static const _morning = '당일 아침 9시';

  @override
  Widget build(BuildContext context) {
    final List<String> options;
    final String selected;
    if (draft.allDay) {
      options = const [_morning, _off];
      selected = draft.alarm ? _morning : _off;
    } else {
      options = [for (final m in alarmChoices) '${beforeLabel(m)} 전', _off];
      selected = draft.alarm ? '${beforeLabel(draft.alarmBefore!)} 전' : _off;
    }
    return ChoiceGrid(
      options: options,
      selected: selected,
      columns: 2,
      onSelect: (label) {
        if (label == _off) {
          draft.alarmBefore = null;
        } else if (label == _morning) {
          draft.alarmBefore ??= 10;
        } else {
          draft.alarmBefore = alarmChoices.firstWhere((m) => '${beforeLabel(m)} 전' == label);
        }
        onChanged();
      },
    );
  }
}

/// 반복 고르기 + 언제까지 고르기
class RepeatChoice extends StatelessWidget {
  final ScheduleDraft draft;
  final VoidCallback onChanged;

  const RepeatChoice({super.key, required this.draft, required this.onChanged});

  static const _none = '반복 안 함';
  static const _months = {'한 달 동안': 1, '두 달 동안': 2, '석 달 동안': 3};
  static const _pick = '끝나는 날 고르기';

  String _untilLabel(DateTime d) => '${d.month}월 ${d.day}일까지';

  Future<void> _pickUntil(BuildContext context) async {
    final start = draft.date ?? dateOnly(DateTime.now());
    final init = draft.repeatUntil ?? Repeat.untilAfterMonths(start, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: init.isBefore(start) ? start : init,
      firstDate: start,
      lastDate: DateTime(start.year + 1, start.month, start.day),
      helpText: '반복이 끝나는 날 고르기',
      cancelText: '취소',
      confirmText: '이 날까지',
    );
    if (picked == null) return;
    draft.repeatMonths = null;
    draft.repeatUntilDate = picked;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final rule = draft.repeatRule;
    final ruleOptions = {
      _none: null,
      for (final r in Repeat.all) Repeat.name(r, draft.date): r,
    };
    final ruleSelected = ruleOptions.entries
        .firstWhere((e) => e.value == rule, orElse: () => ruleOptions.entries.first)
        .key;

    final until = draft.repeatUntil;
    String? untilSelected;
    if (rule != null) {
      final m = draft.repeatMonths;
      if (m != null && _months.containsValue(m)) {
        untilSelected = _months.entries.firstWhere((e) => e.value == m).key;
      } else if (until != null) {
        untilSelected = _untilLabel(until);
      }
    }
    final customLabel =
        (untilSelected != null && !_months.containsKey(untilSelected)) ? untilSelected : _pick;

    final dates = draft.repeatDates;
    final tooEarly = until != null && draft.date != null && until.isBefore(draft.date!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChoiceGrid(
          options: ruleOptions.keys.toList(),
          selected: ruleSelected,
          columns: 2,
          onSelect: (label) {
            final r = ruleOptions[label];
            if (r == null) {
              draft.clearRepeat();
            } else {
              draft.repeatRule = r;
              // 처음 반복을 고르면 "한 달 동안"으로 시작
              if (draft.repeatMonths == null && draft.repeatUntilDate == null) {
                draft.repeatMonths = 1;
              }
            }
            onChanged();
          },
        ),
        if (rule != null) ...[
          const SizedBox(height: 14),
          const Text('언제까지 반복할까요?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ChoiceGrid(
            options: [..._months.keys, customLabel],
            selected: untilSelected,
            columns: 2,
            onSelect: (label) {
              final m = _months[label];
              if (m != null) {
                draft.repeatMonths = m;
                draft.repeatUntilDate = null;
                onChanged();
              } else {
                _pickUntil(context);
              }
            },
          ),
          const SizedBox(height: 10),
          if (tooEarly)
            const Text('끝나는 날이 시작하는 날보다 앞이에요. 다시 골라주세요.',
                style: TextStyle(
                    fontSize: 17, color: AppColors.danger, fontWeight: FontWeight.w500))
          else if (draft.date != null && until != null)
            Text(
              '${formatDateKo(dates.first)}부터 ${_untilLabel(until)}, 모두 ${dates.length}번 저장돼요.'
              '${dates.length >= Repeat.maxCount ? ' (최대 ${Repeat.maxCount}번)' : ''}',
              style: const TextStyle(fontSize: 17, color: AppColors.sub, height: 1.5),
            ),
        ],
      ],
    );
  }
}

/// 반복 일정을 고치거나 지울 때 범위 고르기
enum RepeatScope { thisOnly, fromThis }

Future<RepeatScope?> showRepeatScopeDialog(
  BuildContext context, {
  required String title,
  required String thisOnlyLabel,
  required String fromThisLabel,
}) {
  return showDialog<RepeatScope>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('반복해서 저장한 일정이에요.',
                style: TextStyle(fontSize: 18, color: AppColors.sub, height: 1.5)),
            const SizedBox(height: 20),
            PrimaryButton(
              label: thisOnlyLabel,
              height: 60,
              onPressed: () => Navigator.pop(context, RepeatScope.thisOnly),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: fromThisLabel,
              bold: true,
              onPressed: () => Navigator.pop(context, RepeatScope.fromThis),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: '취소',
              height: 52,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
