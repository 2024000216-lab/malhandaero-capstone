import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

import '../utils/format.dart';

/// 실패 원인 — 실패 화면 문구를 이걸로 고른다
enum FailReason { network, voice, noSchedule }

class AiException implements Exception {
  final FailReason reason;
  AiException(this.reason);
}

/// GPT가 뽑은 일정 + 근거가 된 문장 조각(spans)
class ExtractResult {
  final String transcript;
  final String? title;
  final DateTime? date;
  final int? startMin;
  final int? endMin;
  final bool allDay;
  final String? location;
  final String? repeatRule; // weekly / biweekly / monthly
  final int? repeatMonths; // "한 달 동안" → 1
  final DateTime? repeatUntil; // "12월 31일까지"
  final String? spanDate;
  final String? spanTime;
  final String? spanLocation;
  final String? spanTitle;

  ExtractResult({
    required this.transcript,
    this.title,
    this.date,
    this.startMin,
    this.endMin,
    this.allDay = false,
    this.location,
    this.repeatRule,
    this.repeatMonths,
    this.repeatUntil,
    this.spanDate,
    this.spanTime,
    this.spanLocation,
    this.spanTitle,
  });
}

class AiService {
  // Cloud Functions와 같은 서울 리전
  static final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  static HttpsCallable _callable(String name) => _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

  /// 1단계: 녹음 파일 → 텍스트
  static Future<String> transcribe(String audioPath) async {
    try {
      final bytes = await File(audioPath).readAsBytes();
      final res = await _callable('transcribe').call({
        'audioBase64': base64Encode(bytes),
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final text = (data['text'] as String? ?? '').trim();
      if (text.isEmpty) throw AiException(FailReason.voice);
      return text;
    } on AiException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw AiException(_reasonOf(e));
    } catch (_) {
      throw AiException(FailReason.network);
    }
  }

  /// 2단계: 텍스트 → 일정 정보 (한 문장에 여러 개면 여러 개)
  static Future<List<ExtractResult>> extract(String transcript) async {
    final now = DateTime.now();
    try {
      final res = await _callable('extractSchedule').call({
        'text': transcript,
        'today': dateKey(now),
        'weekday': weekdayKo(now),
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final list = (data['schedules'] as List?) ?? const [];
      final results = list
          .map((e) => _toResult(transcript, Map<String, dynamic>.from(e as Map)))
          .toList();
      if (results.isEmpty) throw AiException(FailReason.noSchedule);
      return results;
    } on AiException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw AiException(_reasonOf(e));
    } catch (_) {
      throw AiException(FailReason.network);
    }
  }

  static ExtractResult _toResult(String transcript, Map<String, dynamic> data) {
    final spans = Map<String, dynamic>.from((data['spans'] as Map?) ?? {});
    final dateStr = data['date'] as String?;
    final untilStr = data['repeat_until'] as String?;
    return ExtractResult(
      transcript: transcript,
      title: data['title'] as String?,
      date: dateStr == null ? null : parseDateKey(dateStr),
      startMin: parseHm(data['start_time'] as String?),
      endMin: parseHm(data['end_time'] as String?),
      allDay: data['all_day'] == true,
      location: data['location'] as String?,
      repeatRule: data['repeat'] as String?,
      repeatMonths: (data['repeat_months'] as num?)?.toInt(),
      repeatUntil: untilStr == null ? null : parseDateKey(untilStr),
      spanDate: spans['date'] as String?,
      spanTime: spans['time'] as String?,
      spanLocation: spans['location'] as String?,
      spanTitle: spans['title'] as String?,
    );
  }

  /// 연결 테스트: (성공 여부, 안내 문구)
  static Future<(bool, String)> healthCheck() async {
    try {
      final res = await _callable('healthCheck').call();
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['ok'] == true, data['message'] as String? ?? '');
    } on FirebaseFunctionsException catch (e) {
      return (false, 'Cloud Functions 호출 실패: ${e.code}\n${e.message ?? ''}');
    } catch (e) {
      return (false, '인터넷 또는 Firebase 연결 실패\n$e');
    }
  }

  static FailReason _reasonOf(FirebaseFunctionsException e) {
    switch (e.message) {
      case 'NO_SPEECH':
        return FailReason.voice;
      case 'NO_SCHEDULE':
        return FailReason.noSchedule;
      default:
        return FailReason.network;
    }
  }
}
