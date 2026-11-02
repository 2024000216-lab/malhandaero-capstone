import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/ai_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'confirm_screen.dart';
import 'save_flow.dart';

/// 와이어프레임 5차 07 — 크게 보기: 일정을 하나씩 확인 (맞아요 / 고칠래요)
/// 빠진 칸이 있는 일정은 처리 화면에서 보통 확인 화면으로 보낸다.
class LargeConfirmScreen extends StatefulWidget {
  final List<ExtractResult> results;
  const LargeConfirmScreen({super.key, required this.results});

  @override
  State<LargeConfirmScreen> createState() => _LargeConfirmScreenState();
}

class _LargeConfirmScreenState extends State<LargeConfirmScreen> {
  late final List<ScheduleDraft> _drafts = draftsFromResults(widget.results);
  int _index = 0;
  bool _saving = false;

  ScheduleDraft get _d => _drafts[_index];

  Future<void> _accept() async {
    if (_index < _drafts.length - 1) {
      setState(() => _index++);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    await saveDraftsAndShowDone(context, _drafts);
    if (mounted) setState(() => _saving = false);
  }

  /// 고칠 때는 칸별로 고칠 수 있는 보통 확인 화면으로
  void _fix() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ConfirmScreen(results: widget.results)),
    );
  }

  Future<void> _cancel() async {
    final leave = await showBigConfirm(
      context,
      title: '저장하지 않고 나갈까요?',
      message: '나가면 방금 말한 내용이 사라져요.',
      safeLabel: '계속 확인하기',
      dangerLabel: '저장 안 하고 나가기',
    );
    if (leave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = _drafts.length;
    final d = _d;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          setState(() => _index--);
        } else {
          _cancel();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TopTextButton(
                      label: _index > 0 ? '이전' : '취소',
                      withArrow: _index > 0,
                      onPressed: _index > 0 ? () => setState(() => _index--) : _cancel,
                    ),
                    const Spacer(),
                    for (var i = 0; i < total; i++) ...[
                      Container(
                        width: 28,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= _index ? AppColors.text : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.text, width: 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text('${_index + 1} / $total',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('이 일정이 맞나요?',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.text, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field('할 일', d.title ?? '', size: 40, first: true),
                          _field('날짜', formatDateKo(d.date!)),
                          _field('시간', _timeText(d)),
                          _field('장소', d.location ?? '없음',
                              size: 24, muted: d.location == null),
                          if (d.repeatRule != null && d.date != null)
                            _field('반복', Repeat.name(d.repeatRule!, d.date), size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _bigButton('고칠래요', filled: false, onPressed: _fix)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _bigButton(
                        _index < total - 1 ? '맞아요' : (total > 1 ? '맞아요, 저장' : '맞아요'),
                        onPressed: _saving ? null : _accept,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeText(ScheduleDraft d) {
    if (d.allDay) return '하루 종일';
    if (d.startMin == null) return '시간 없음';
    if (d.endMin != null) return '${formatTime(d.startMin!)} ~ ${formatTime(d.endMin!)}';
    return formatTime(d.startMin!);
  }

  Widget _field(String label, String value,
      {double size = 28, bool muted = false, bool first = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppColors.divider, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, color: AppColors.sub)),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w800,
              color: muted ? AppColors.disabledFg : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigButton(String label, {bool filled = true, required VoidCallback? onPressed}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    const style = TextStyle(fontSize: 26, fontWeight: FontWeight.w800);
    return SizedBox(
      height: 96,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOf(context),
                foregroundColor: Colors.white,
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: FittedBox(child: Text(label, style: style)),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.text, width: 3),
                shape: shape,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: FittedBox(child: Text(label, style: style)),
            ),
    );
  }
}
