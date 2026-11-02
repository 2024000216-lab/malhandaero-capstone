import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'processing_screen.dart';

/// S-02 녹음
/// - 최대 60초
/// - 말을 한 번 한 뒤 3초 동안 조용하면 자동으로 끝냄
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  static const _maxSeconds = 60;
  static const _silenceStopMs = 3000;
  static const _voiceDb = -38.0; // 이보다 크면 "말하는 중"
  static const _silenceDb = -45.0; // 이보다 작으면 "조용함"
  static const _tickMs = 200;

  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  String? _path;
  int _elapsedMs = 0;
  int _silentMs = 0;
  bool _heardVoice = false;
  bool _finishing = false;
  final List<double> _levels = List.filled(20, 0.1);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _stopTimers();
    _recorder.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _timer?.cancel();
    _ampSub?.cancel();
  }

  Future<void> _start() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _elapsedMs = 0;
    _silentMs = 0;
    _heardVoice = false;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _path!,
    );

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: _tickMs))
        .listen(_onAmplitude);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += 1000);
      if (_elapsedMs >= _maxSeconds * 1000) _finish();
    });
    if (mounted) setState(() {});
  }

  void _onAmplitude(Amplitude a) {
    final db = a.current;
    if (db > _voiceDb) {
      _heardVoice = true;
      _silentMs = 0;
    } else if (db < _silenceDb && _heardVoice) {
      _silentMs += _tickMs;
      if (_silentMs >= _silenceStopMs) _finish();
    }
    // -60dB ~ 0dB 를 0.1 ~ 1.0 막대 높이로
    final level = ((db + 60) / 60).clamp(0.1, 1.0);
    if (!mounted) return;
    setState(() {
      _levels.removeAt(0);
      _levels.add(level);
    });
  }

  /// "다 말했어요"
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _stopTimers();
    final path = await _recorder.stop();
    if (!mounted || path == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ProcessingScreen(audioPath: path)),
    );
  }

  /// "처음부터 다시 말하기"
  Future<void> _restart() async {
    _stopTimers();
    await _recorder.stop();
    _deleteFile();
    await _start();
  }

  /// "그만하기"
  Future<void> _cancel() async {
    _finishing = true;
    _stopTimers();
    await _recorder.stop();
    _deleteFile();
    if (mounted) Navigator.pop(context);
  }

  void _deleteFile() {
    final p = _path;
    if (p != null) File(p).delete().ignore();
  }

  /// 빨간 "그만하기" 버튼 — 녹음을 멈추고 홈으로 돌아간다
  Widget _stopButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _cancel,
        icon: const Icon(Icons.close_rounded, size: 26),
        label: const Text('그만하기'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remain = _maxSeconds - _elapsedMs ~/ 1000;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 10),
                  child: _stopButton(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('일정을 말해주세요',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이렇게 말해보세요',
                              style: TextStyle(fontSize: 16, color: AppColors.sub)),
                          SizedBox(height: 6),
                          Text('“금요일 오후 3시에\n도서관에서 팀 회의”',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w500, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('일정 여러 개를 한 번에 말해도 돼요.',
                        style: TextStyle(fontSize: 17, color: AppColors.sub)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle, size: 14, color: AppColors.danger),
                        SizedBox(width: 10),
                        Text('듣고 있어요',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 64,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final l in _levels)
                            Container(
                              width: 7,
                              height: 64 * l,
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(TextSpan(children: [
                      const TextSpan(
                          text: '남은 시간 ',
                          style: TextStyle(fontSize: 18, color: AppColors.sub)),
                      TextSpan(
                          text: '$remain초',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ])),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Column(
                  children: [
                    RoundActionButton(
                      semanticLabel: '다 말했어요',
                      onPressed: _finish,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('다 말했어요',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    SecondaryButton(
                      label: '처음부터 다시 말하기',
                      icon: Icons.refresh,
                      onPressed: _restart,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
