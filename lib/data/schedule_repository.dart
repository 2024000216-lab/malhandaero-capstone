import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/schedule.dart';
import '../utils/format.dart';

/// 일정은 기기 안(SQLite)에만 저장한다. 로그인·서버 저장 없음.
class ScheduleRepository {
  ScheduleRepository._();
  static final instance = ScheduleRepository._();

  Database? _db;

  /// 일정이 저장·수정·삭제될 때마다 알림 → 홈 화면이 다시 불러온다
  final changes = ScheduleChanges();

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'malhandaero.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            start_min INTEGER,
            end_min INTEGER,
            all_day INTEGER NOT NULL DEFAULT 0,
            location TEXT,
            memo TEXT,
            alarm INTEGER NOT NULL DEFAULT 1,
            alarm_before INTEGER,
            transcript TEXT,
            repeat_rule TEXT,
            repeat_until TEXT,
            repeat_group TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_schedules_group ON schedules(repeat_group)');
      },
      // 버전 1(알림 10분 고정, 반복 없음)에서 올라올 때 칸 추가
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE schedules ADD COLUMN alarm_before INTEGER');
          await db.execute('UPDATE schedules SET alarm_before = 10 WHERE alarm = 1');
          await db.execute('ALTER TABLE schedules ADD COLUMN repeat_rule TEXT');
          await db.execute('ALTER TABLE schedules ADD COLUMN repeat_until TEXT');
          await db.execute('ALTER TABLE schedules ADD COLUMN repeat_group TEXT');
          await db.execute('CREATE INDEX idx_schedules_group ON schedules(repeat_group)');
        }
      },
    );
  }

  Future<Schedule> insert(Schedule s) async {
    final map = s.toMap()..remove('id');
    final id = await (await _database).insert('schedules', map);
    changes.bump(s.date);
    return s.copyWith(id: id);
  }

  /// 반복 일정이면 날짜마다 1개씩 저장하고 같은 repeatGroup으로 묶는다.
  /// 저장된 일정 전부를 날짜 순으로 돌려준다 (반복이 아니면 1개).
  Future<List<Schedule>> insertSeries(Schedule s) async {
    final dates = Repeat.dates(s.date, s.repeatRule, s.repeatUntil);
    if (dates.length <= 1) {
      return [await insert(s.copyWith(clearRepeat: true))];
    }
    final group = 'g${DateTime.now().microsecondsSinceEpoch}';
    final out = <Schedule>[];
    await (await _database).transaction((txn) async {
      for (final d in dates) {
        final item = s.copyWith(date: d, repeatGroup: group);
        final map = item.toMap()..remove('id');
        final id = await txn.insert('schedules', map);
        out.add(item.copyWith(id: id));
      }
    });
    changes.bump(s.date);
    return out;
  }

  /// 같은 반복 일정 중 [from] 날짜부터 뒤의 것을 지운다. 지운 id 목록을 돌려준다 (알림 취소용).
  Future<List<int>> deleteSeriesFrom(String group, DateTime from) async {
    final db = await _database;
    final rows = await db.query(
      'schedules',
      columns: ['id'],
      where: 'repeat_group = ? AND date >= ?',
      whereArgs: [group, dateKey(from)],
    );
    final ids = rows.map((r) => r['id'] as int).toList();
    await db.delete(
      'schedules',
      where: 'repeat_group = ? AND date >= ?',
      whereArgs: [group, dateKey(from)],
    );
    changes.bump(null);
    return ids;
  }

  /// 같은 반복 일정이 [from] 날짜부터 몇 번 남았는지
  Future<int> countSeriesFrom(String group, DateTime from) async {
    final rows = await (await _database).rawQuery(
      'SELECT COUNT(*) AS c FROM schedules WHERE repeat_group = ? AND date >= ?',
      [group, dateKey(from)],
    );
    return rows.first['c'] as int;
  }

  Future<void> update(Schedule s) async {
    await (await _database)
        .update('schedules', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    changes.bump(s.date);
  }

  Future<void> delete(int id) async {
    await (await _database).delete('schedules', where: 'id = ?', whereArgs: [id]);
    changes.bump(null);
  }

  Future<Schedule?> byId(int id) async {
    final rows =
        await (await _database).query('schedules', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Schedule.fromMap(rows.first);
  }

  /// 하루 종일 일정이 먼저, 그다음 시간 순
  Future<List<Schedule>> byDate(DateTime date) async {
    final rows = await (await _database).query(
      'schedules',
      where: 'date = ?',
      whereArgs: [dateKey(date)],
      orderBy: 'all_day DESC, start_min ASC, id ASC',
    );
    return rows.map(Schedule.fromMap).toList();
  }

  /// { '2026-10-23': 2, ... }
  Future<Map<String, int>> countsBetween(DateTime from, DateTime to) async {
    final rows = await (await _database).rawQuery(
      'SELECT date, COUNT(*) AS c FROM schedules WHERE date BETWEEN ? AND ? GROUP BY date',
      [dateKey(from), dateKey(to)],
    );
    return {for (final r in rows) r['date'] as String: r['c'] as int};
  }
}

class ScheduleChanges extends ChangeNotifier {
  /// 마지막으로 저장·수정된 일정의 날짜 (삭제면 null)
  DateTime? date;

  void bump(DateTime? d) {
    date = d;
    notifyListeners();
  }
}
