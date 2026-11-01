import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'edit_screen.dart';
import 'record_screen.dart';

/// S-00 마이크 권한 안내 (+ 거부했을 때 S-00-E)
/// 시스템 권한 창이 뜨기 전에 어떤 창이 뜨고 어디를 누르면 되는지 먼저 보여준다.
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Permission.microphone.isPermanentlyDenied.then((v) {
      if (v && mounted) setState(() => _denied = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 설정 앱에서 허용하고 돌아오면 바로 녹음 화면으로
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _denied) {
      if (await Permission.microphone.isGranted && mounted) _goRecord();
    }
  }

  void _goRecord() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RecordScreen()));
  }

  Future<void> _request() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (status.isGranted) {
      _goRecord();
    } else {
      setState(() => _denied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _denied ? _deniedView() : _guideView()),
    );
  }

  Widget _guideView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.dateBg,
                  child: Icon(Icons.mic_none_rounded, size: 46, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text('목소리를 들으려면\n마이크가 필요해요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.35)),
                const SizedBox(height: 12),
                const Text('말한 내용을 일정으로 바꿀 때만\n마이크를 사용해요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: AppColors.sub, height: 1.6)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('다음에 이런 창이 떠요',
                          style: TextStyle(fontSize: 16, color: AppColors.sub)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.lightBorder, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('말한대로에서 오디오를 녹음하도록 허용하시겠습니까?',
                                style: TextStyle(fontSize: 16, height: 1.5)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('앱 사용 중에만 허용',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('파란 칸을 눌러주세요',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              PrimaryButton(label: '알겠어요, 다음', onPressed: _request),
              const SizedBox(height: 10),
              SecondaryButton(
                  label: '나중에 할게요', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _deniedView() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TopTextButton(
              label: '뒤로', withArrow: true, onPressed: () => Navigator.pop(context)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.dangerBg,
                  child: Icon(Icons.mic_off_outlined, size: 34, color: AppColors.danger),
                ),
                const SizedBox(height: 16),
                const Text('마이크 사용이 꺼져 있어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text('말로 등록하려면 설정에서\n마이크를 허용해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: AppColors.sub, height: 1.6)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('설정 › 애플리케이션 › 말한대로 › 권한 › 마이크',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              PrimaryButton(label: '설정 열기', onPressed: openAppSettings),
              const SizedBox(height: 10),
              SecondaryButton(
                label: '손으로 직접 입력하기',
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const EditScreen())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
