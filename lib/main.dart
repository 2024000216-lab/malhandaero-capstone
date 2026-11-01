import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart'; // flutterfire configure 로 생성되는 파일
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();
  runApp(const MalhandaeroApp());
}

class MalhandaeroApp extends StatelessWidget {
  const MalhandaeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '말한대로',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // 날짜·시간 고르기 창을 한국어로
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 휴대폰 글자 크기 설정을 따르되, 화면이 깨지지 않게 1.6배까지만
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.6,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
