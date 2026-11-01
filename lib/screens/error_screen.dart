import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'edit_screen.dart';
import 'processing_screen.dart';
import 'record_screen.dart';

/// S-03-E 실패 — 오류 코드 대신 "무슨 일이 생겼고 지금 뭘 하면 되는지"
class ErrorScreen extends StatelessWidget {
  final FailReason reason;
  final String audioPath;
  const ErrorScreen({super.key, required this.reason, required this.audioPath});

  @override
  Widget build(BuildContext context) {
    final (title, desc) = switch (reason) {
      FailReason.network => (
          '연결이 잘 되지 않았어요',
          '와이파이나 데이터가 켜져 있는지\n확인한 뒤 다시 눌러주세요.\n계속 안 되면 잠시 뒤에 해주세요.'
        ),
      FailReason.voice => (
          '목소리가 잘 들리지 않았어요',
          '조용한 곳에서 휴대폰을\n입 가까이 대고 말해주세요.'
        ),
      FailReason.noSchedule => (
          '날짜나 할 일을\n찾지 못했어요',
          '“내일 오전 10시 병원”처럼\n언제, 무엇을 말해주세요.'
        ),
    };

    void replace(Widget page) =>
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));

    void cleanUp() => File(audioPath).delete().ignore();

    final isNetwork = reason == FailReason.network;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.dangerBg,
                      child: Icon(Icons.priority_high_rounded,
                          size: 42, color: AppColors.danger),
                    ),
                    const SizedBox(height: 16),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700, height: 1.35)),
                    const SizedBox(height: 12),
                    Text(desc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, height: 1.6)),
                  ],
                ),
              ),
              // 원인마다 가장 해결될 만한 행동 하나만 파란 버튼
              PrimaryButton(
                label: isNetwork ? '다시 해보기' : '다시 말하기',
                onPressed: () {
                  if (isNetwork) {
                    replace(ProcessingScreen(audioPath: audioPath));
                  } else {
                    cleanUp();
                    replace(const RecordScreen());
                  }
                },
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: '손으로 직접 입력하기',
                onPressed: () {
                  cleanUp();
                  replace(const EditScreen());
                },
              ),
              TextButton(
                onPressed: () {
                  cleanUp();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sub,
                  minimumSize: const Size(double.infinity, 48),
                  textStyle: const TextStyle(
                      fontSize: 17, decoration: TextDecoration.underline),
                ),
                child: const Text('처음 화면으로'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
