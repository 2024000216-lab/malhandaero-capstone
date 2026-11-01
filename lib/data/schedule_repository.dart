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
      version: 1,
      onCreate: (db, version) => db.execute('''
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
          transcript TEXT
        )
      '''),
    );
  }

  Future<Schedule> insert(Schedule s) async {
    final map = s.toMap()..remove('id');
    final id = await (await _database).insert('schedules', map);
    changes.bump(s.date);
    return s.copyWith(id: id);
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
