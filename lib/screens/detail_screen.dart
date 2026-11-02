import 'package:flutter/material.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/schedule_options.dart';
import 'edit_screen.dart';

/// S-05 일정 자세히
class DetailScreen extends StatefulWidget {
  final int scheduleId;
  const DetailScreen({super.key, required this.scheduleId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _repo = ScheduleRepository.instance;
  late int _id = widget.scheduleId; // 반복 일정을 고치면 id가 바뀔 수 있다
  Schedule? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _repo.byId(_id);
    if (!mounted) return;
    if (s == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _s = s);
  }

  Future<void> _edit() async {
    final s = _s!;
    RepeatScope? scope;
    if (s.isRepeat) {
      scope = await showRepeatScopeDialog(
        context,
        title: '어떤 일정을 고칠까요?',
        thisOnlyLabel: '이 날 일정만 고치기',
        fromThisLabel: '이 날부터 모두 고치기',
      );
      if (scope == null || !mounted) return;
    }
    final newId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(existing: s, scope: scope)),
    );
    if (newId != null) _id = newId;
    _load();
  }

  /// 지우기는 되돌릴 수 없어서, 안전한 쪽("지우지 않기")이 파란 주 버튼
  Future<void> _delete() async {
    final s = _s!;
    var scope = RepeatScope.thisOnly;
    var count = 1;
    if (s.isRepeat) {
      final picked = await showRepeatScopeDialog(
        context,
        title: '어떤 일정을 지울까요?',
        thisOnlyLabel: '이 날 일정만 지우기',
        fromThisLabel: '이 날부터 모두 지우기',
      );
      if (picked == null || !mounted) return;
      scope = picked;
      if (scope == RepeatScope.fromThis) {
        count = await _repo.countSeriesFrom(s.repeatGroup!, s.date);
        if (!mounted) return;
      }
    }

    final ok = await showBigConfirm(
      context,
      title: count > 1
          ? '‘${s.title}’ $count개를 지울까요?'
          : '‘${s.title}’${eulReul(s.title)} 지울까요?',
      message: '지우면 다시 살릴 수 없고\n알림도 오지 않아요.',
      safeLabel: '지우지 않기',
      dangerLabel: '네, 지울게요',
    );
    if (!ok) return;
    if (scope == RepeatScope.fromThis) {
      final ids = await _repo.deleteSeriesFrom(s.repeatGroup!, s.date);
      await NotificationService.cancelAll(ids);
    } else {
      await _repo.delete(s.id!);
      await NotificationService.cancel(s.id!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      body: SafeArea(
        child: s == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: TopTextButton(
                          label: '뒤로',
                          withArrow: true,
                          onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      children: [
                        Text(s.title,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 18),
                        Box(
                          child: Column(
                            children: [
                              InfoRow(
                                  label: '언제',
                                  value: '${formatDateKo(s.date)}\n${s.timeLabel}'),
                              InfoRow(
                                  label: '어디서',
                                  value: s.location ?? '없음',
                                  muted: s.location == null),
                              if (s.repeatLabel != null)
                                InfoRow(label: '반복', value: s.repeatLabel!),
                              InfoRow(label: '알림', value: s.alarmLabel),
                              InfoRow(
                                  label: '메모',
                                  value: s.memo ?? '없음',
                                  muted: s.memo == null,
                                  last: true),
                            ],
                          ),
                        ),
                        if (s.transcript != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('말로 등록한 일정',
                                    style:
                                        TextStyle(fontSize: 15, color: AppColors.sub)),
                                const SizedBox(height: 4),
                                Text('“${s.transcript}”',
                                    style: const TextStyle(fontSize: 17, height: 1.5)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: '고치기',
                            icon: Icons.edit_outlined,
                            bold: true,
                            height: 60,
                            onPressed: _edit,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SecondaryButton(
                            label: '지우기',
                            icon: Icons.delete_outline,
                            color: AppColors.danger,
                            bold: true,
                            height: 60,
                            onPressed: _delete,
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
