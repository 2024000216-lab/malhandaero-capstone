import 'package:flutter/material.dart';

import '../data/schedule_repository.dart';
import '../models/schedule.dart';
import '../services/notification_service.dart';
import 'done_screen.dart';

/// 확인 화면(보통/크게 보기)에서 같이 쓰는 저장 흐름.
/// 반복 일정은 날짜마다 저장하고, 완료 화면에서 "되돌리기"를 누르면 모두 지운다.
Future<void> saveDraftsAndShowDone(BuildContext context, List<ScheduleDraft> drafts) async {
  final repo = ScheduleRepository.instance;
  if (drafts.any((d) => d.alarm)) await NotificationService.requestPermission();

  final saved = <Schedule>[];
  final firsts = <Schedule>[];
  for (final d in drafts) {
    final series = await repo.insertSeries(d.toSchedule());
    await NotificationService.scheduleAll(series);
    saved.addAll(series);
    firsts.add(series.first);
  }
  if (!context.mounted) return;

  final undo = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => DoneScreen.many(schedules: firsts)),
  );
  if (undo == true) {
    for (final s in saved) {
      await repo.delete(s.id!);
    }
    await NotificationService.cancelAll(saved.map((s) => s.id!));
  }
}
