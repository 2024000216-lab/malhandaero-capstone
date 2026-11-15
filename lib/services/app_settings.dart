import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/schedule.dart';

/// 보기 설정 (색약 모드 · 크게 보기 모드 · 미리 알림 기본값)
/// 일정 DB와 따로 settings.db 에 저장한다. (일정 DB 버전은 건드리지 않음)
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  static const _kColorBlind = 'color_blind';
  static const _kLargeMode = 'large_mode';
  static const _kDefaultAlarm = 'default_alarm';

  bool _colorBlind = false;
  bool _largeMode = false;
  int _defaultAlarm = 10;

  bool get colorBlind => _colorBlind;
  bool get largeMode => _largeMode;
  int get defaultAlarm => _defaultAlarm;

  Database? _db;

  Future<Database> _open() async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'settings.db'),
        version: 1,
        onCreate: (db, version) => db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        ),
      );

  /// 앱 시작 때 한 번 불러온다. 실패해도 기본값으로 동작.
  Future<void> load() async {
    try {
      final rows = await (await _open()).query('settings');
      final map = {for (final r in rows) r['key'] as String: r['value'] as String};
      _colorBlind = map[_kColorBlind] == '1';
      _largeMode = map[_kLargeMode] == '1';
      final alarm = int.tryParse(map[_kDefaultAlarm] ?? '');
      if (alarm != null && alarmChoices.contains(alarm)) _defaultAlarm = alarm;
    } catch (_) {
      // 기본값 사용
    }
    ScheduleDraft.defaultAlarmBefore = _defaultAlarm;
  }

  Future<void> _save(String key, String value) async {
    try {
      await (await _open()).insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // 저장 실패해도 이번 실행 동안은 바뀐 값으로 동작
    }
  }

  void setColorBlind(bool value) {
    if (_colorBlind == value) return;
    _colorBlind = value;
    notifyListeners();
    _save(_kColorBlind, value ? '1' : '0');
  }

  void setLargeMode(bool value) {
    if (_largeMode == value) return;
    _largeMode = value;
    notifyListeners();
    _save(_kLargeMode, value ? '1' : '0');
  }

  void setDefaultAlarm(int minutes) {
    if (_defaultAlarm == minutes) return;
    _defaultAlarm = minutes;
    ScheduleDraft.defaultAlarmBefore = minutes;
    notifyListeners();
    _save(_kDefaultAlarm, '$minutes');
  }
}

/// 화면에서 설정이 바뀌면 다시 그리도록 위젯 트리에 넣는 범위
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  /// build 안에서 사용 (설정이 바뀌면 다시 그림)
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier ??
      AppSettings.instance;
}
