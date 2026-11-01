/**
 * 말한대로 — Cloud Functions
 * 앱은 음성 파일만 보내고, OpenAI API 키는 여기(Secret Manager)에만 있다.
 *
 *  - transcribe      : 음성(m4a, base64) → Whisper → 텍스트
 *  - extractSchedule : 텍스트 → GPT → 일정 JSON
 *  - healthCheck     : API 키·모델 ID가 올바른지 확인 (앱에서 '말한대로' 글자를 길게 누르면 실행)
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const { defineSecret, defineString } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const OPENAI_MODEL = defineString("OPENAI_MODEL", {
  description: "일정 추출에 쓸 OpenAI 모델 ID (OpenAI 대시보드에 표시된 그대로)",
});

// 서울 리전, 동시에 뜨는 서버 수 제한(요금 폭주 방지)
setGlobalOptions({ region: "asia-northeast3", maxInstances: 3 });

const MAX_AUDIO_BYTES = 5 * 1024 * 1024; // 1분 녹음은 1MB 안쪽
const MAX_TEXT_LENGTH = 500;

// 무음일 때 Whisper가 지어내는 대표적인 문장들
const SILENCE_HALLUCINATIONS = [
  "시청해주셔서 감사합니다",
  "시청해 주셔서 감사합니다",
  "구독과 좋아요",
  "MBC 뉴스",
];

function authHeader() {
  return { Authorization: `Bearer ${OPENAI_API_KEY.value()}` };
}

// ───────────────────────── transcribe ─────────────────────────
exports.transcribe = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    const b64 = request.data && request.data.audioBase64;
    if (typeof b64 !== "string" || b64.length === 0) {
      throw new HttpsError("invalid-argument", "NO_AUDIO");
    }
    const audio = Buffer.from(b64, "base64");
    if (audio.length === 0) throw new HttpsError("invalid-argument", "NO_AUDIO");
    if (audio.length > MAX_AUDIO_BYTES) {
      throw new HttpsError("invalid-argument", "AUDIO_TOO_LARGE");
    }

    const form = new FormData();
    form.append("file", new Blob([audio], { type: "audio/mp4" }), "voice.m4a");
    form.append("model", "whisper-1");
    form.append("language", "ko");

    const res = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: authHeader(),
      body: form,
    });
    if (!res.ok) {
      logger.error("Whisper error", res.status, await res.text());
      throw new HttpsError("unavailable", "OPENAI_ERROR");
    }

    const json = await res.json();
    const text = (json.text || "").trim();
    const isHallucination = SILENCE_HALLUCINATIONS.some((p) => text.includes(p));
    if (!text || isHallucination) {
      throw new HttpsError("not-found", "NO_SPEECH");
    }
    return { text };
  }
);

// ─────────────────────── extractSchedule ───────────────────────
function buildPrompt(today, weekday) {
  return `너는 한국어 문장에서 일정 정보를 뽑는 도우미야.
오늘은 ${today} (${weekday}요일)이고, 시간대는 한국(Asia/Seoul)이야.
사용자 문장에서 일정 1개를 뽑아서 아래 JSON 형식으로만 답해. 다른 말은 쓰지 마.

{
  "has_schedule": true 또는 false,
  "title": 할 일을 짧게 (예: "팀 회의", "병원 예약") 또는 null,
  "date": "YYYY-MM-DD" 또는 null,
  "start_time": "HH:mm" (24시간) 또는 null,
  "end_time": "HH:mm" (24시간) 또는 null,
  "all_day": true 또는 false,
  "location": 장소 또는 null,
  "spans": {
    "date": 문장에서 날짜를 말한 부분 또는 null,
    "time": 문장에서 시간을 말한 부분 또는 null,
    "location": 문장에서 장소를 말한 부분 또는 null,
    "title": 문장에서 할 일을 말한 부분 또는 null
  }
}

규칙:
1. 오늘, 내일, 모레, 이번 주/다음 주 X요일 같은 말은 오늘 날짜를 기준으로 실제 날짜로 바꿔. 한 주는 월요일에 시작해.
2. 요일만 말하면(예: "금요일") 오늘 이후 가장 가까운 그 요일로 해. 오늘이 그 요일이면 오늘이야.
3. 날짜를 말하지 않았으면 date는 null.
4. 시간을 말하지 않았으면 start_time은 null, all_day는 false. "하루 종일", "종일"이라고 했을 때만 all_day를 true로 해.
5. 오전/오후 없이 1시~6시라고 하면 오후로 봐. "저녁 7시"는 19:00, "밤 10시"는 22:00.
6. 끝나는 시간을 말했을 때만 end_time을 채워.
7. 일정이 여러 개면 첫 번째 일정만 뽑아.
8. spans의 값은 사용자 문장에 있는 글자를 그대로 복사해. 바꾸거나 요약하지 마.
9. 일정과 관계없는 문장이면 has_schedule을 false로 해.`;
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

function str(v) {
  return typeof v === "string" && v.trim() ? v.trim() : null;
}

// GPT 답을 앱이 믿고 쓸 수 있는 형태로 정리
function normalize(raw, text) {
  const spans = raw && typeof raw.spans === "object" && raw.spans ? raw.spans : {};
  const span = (k) => {
    const v = str(spans[k]);
    return v && text.includes(v) ? v : null; // 문장에 실제로 있는 글자만
  };
  const date = str(raw.date);
  const start = str(raw.start_time);
  const end = str(raw.end_time);
  const allDay = raw.all_day === true;
  return {
    has_schedule: raw.has_schedule === true,
    title: str(raw.title),
    date: date && DATE_RE.test(date) ? date : null,
    start_time: !allDay && start && TIME_RE.test(start) ? start : null,
    end_time: !allDay && end && TIME_RE.test(end) ? end : null,
    all_day: allDay,
    location: str(raw.location),
    spans: {
      date: span("date"),
      time: span("time"),
      location: span("location"),
      title: span("title"),
    },
  };
}

exports.extractSchedule = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 60 },
  async (request) => {
    const { text, today, weekday } = request.data || {};
    if (typeof text !== "string" || !text.trim() || text.length > MAX_TEXT_LENGTH) {
      throw new HttpsError("invalid-argument", "BAD_TEXT");
    }
    if (typeof today !== "string" || !DATE_RE.test(today)) {
      throw new HttpsError("invalid-argument", "BAD_DATE");
    }

    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { ...authHeader(), "Content-Type": "application/json" },
      body: JSON.stringify({
        model: OPENAI_MODEL.value(),
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: buildPrompt(today, String(weekday || "")) },
          { role: "user", content: text },
        ],
      }),
    });
    if (!res.ok) {
      logger.error("GPT error", res.status, await res.text());
      throw new HttpsError("unavailable", "OPENAI_ERROR");
    }

    const json = await res.json();
    let raw;
    try {
      raw = JSON.parse(json.choices[0].message.content);
    } catch (e) {
      logger.error("GPT JSON parse error", json);
      throw new HttpsError("unavailable", "BAD_RESPONSE");
    }

    const out = normalize(raw, text);
    if (!out.has_schedule || (!out.title && !out.date)) {
      throw new HttpsError("failed-precondition", "NO_SCHEDULE");
    }
    return out;
  }
);

// ───────────────────────── healthCheck ─────────────────────────
exports.healthCheck = onCall({ secrets: [OPENAI_API_KEY] }, async () => {
  const model = OPENAI_MODEL.value();
  const res = await fetch(
    `https://api.openai.com/v1/models/${encodeURIComponent(model)}`,
    { headers: authHeader() }
  );
  if (res.status === 401) {
    return { ok: false, message: "OpenAI API 키가 올바르지 않아요." };
  }
  if (res.status === 404) {
    return { ok: false, message: `모델 ID(${model})를 찾을 수 없어요. functions/.env를 확인하세요.` };
  }
  if (!res.ok) {
    return { ok: false, message: `OpenAI 응답 오류 (${res.status})` };
  }
  return { ok: true, message: `연결 성공 · 모델 ${model}` };
});
