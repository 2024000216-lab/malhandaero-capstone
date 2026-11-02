import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'confirm_screen.dart';
import 'error_screen.dart';
import 'large_confirm_screen.dart';

/// S-03 처리 중 — 실제 진행 단계(글자로 바꾸기 → 일정 찾기)를 그대로 보여준다
class ProcessingScreen extends StatefulWidget {
  final String audioPath;
  const ProcessingScreen({super.key, required this.audioPath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int _step = 0; // 0: 글자로 바꾸는 중, 1: 일정 찾는 중, 2: 확인 화면 준비
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final text = await AiService.transcribe(widget.audioPath);
      if (_cancelled || !mounted) return;
      setState(() => _step = 1);

      final results = await AiService.extract(text);
      if (_cancelled || !mounted) return;
      setState(() => _step = 2);

      File(widget.audioPath).delete().ignore(); // 다 쓴 녹음 파일 삭제
      // 크게 보기 모드이고 빠진 칸이 없으면 하나씩 크게 확인, 아니면 칸별로 고치는 확인 화면
      final large = AppSettings.instance.largeMode &&
          draftsFromResults(results).every((d) => d.missing.isEmpty);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => large
              ? LargeConfirmScreen(results: results)
              : ConfirmScreen(results: results),
        ),
      );
    } on AiException catch (e) {
      if (_cancelled || !mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ErrorScreen(reason: e.reason, audioPath: widget.audioPath),
        ),
      );
    }
  }

  void _cancel() {
    _cancelled = true;
    File(widget.audioPath).delete().ignore();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          strokeWidth: 7,
                          color: AppColors.primary,
                          backgroundColor: AppColors.divider,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text('일정으로 정리하고 있어요',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('잠시만 기다려주세요',
                          style: TextStyle(fontSize: 18, color: AppColors.sub)),
                      const SizedBox(height: 26),
                      Box(
                        child: Column(
                          children: [
                            _stepRow(0, '1. 목소리를 글자로 바꾸기'),
                            _stepRow(1, '2. 날짜·시간·장소 찾기'),
                            _stepRow(2, '3. 확인 화면 보여주기', last: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SecondaryButton(label: '취소하고 처음으로', onPressed: _cancel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 끝난 단계: 검은 체크 + "끝", 지금 단계: 파란 원 + "하는 중"
  Widget _stepRow(int index, String label, {bool last = false}) {
    final done = index < _step;
    final now = index == _step;
    Widget mark;
    if (done) {
      mark = const CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.text,
        child: Icon(Icons.check, size: 18, color: Colors.white),
      );
    } else {
      mark = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: now ? AppColors.primary : const Color(0xFF9A9A95),
            width: now ? 3 : 2,
          ),
        ),
      );
    }
    return Container(
      height: 58,
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE6E6E2))),
      ),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: now ? FontWeight.w700 : FontWeight.w400,
                  color: (done || now) ? AppColors.text : AppColors.disabledFg,
                ),
              ),
              if (done)
                const TextSpan(
                    text: ' · 끝', style: TextStyle(fontSize: 16, color: AppColors.sub)),
              if (now)
                const TextSpan(
                    text: ' · 하는 중',
                    style: TextStyle(fontSize: 16, color: AppColors.primary)),
            ])),
          ),
        ],
      ),
    );
  }
}
