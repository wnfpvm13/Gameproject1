# 미니게임 개편 6e — 음성 받아쓰기 판정: 만든 기록 (2026-10-23)

후임 에이전트용 기록이다. 규칙은 `docs/DESIGN_V3.md` 3번 표("음성 금칙어", "금칙어 토크가 나오는 조건"), 5번(받아쓰기 판정), 6번(금칙어 토크의 대화·정산 구간)이 기준이다. 바로 앞 묶음은 `docs/GAMES_6D_2026-10-23.md`(태그 `banned-words-v3-6d`).

## 오너 결정 (2026-10-23)

- 음성 금칙어는 시스템이 받아쓰기로 잡는다(원래 2단계였던 것을 앞당김). 클라이언트가 보고하는 구조라 조작된 클라이언트는 못 잡는 한계를 받아들인다.
- 금칙어 토크는 `VOICE_JUDGING`을 켠 뒤에만 나온다. **`VOICE_JUDGING`은 아직 `false`**다. Studio에는 받아쓰기가 없으므로, 라이브 시험(게시, 오너 승인 뒤)으로 정확도와 한도를 확인하고 켠다.

## 무엇을 했나

V2 때 만든 받아쓰기 판정(`server/services/JudgeService`, `client/Speech`, 시험 `tools/tests/server_tests.luau`·`speech_tests.luau`)이 1단계에서 리모트 연결만 끊긴 채 남아 있었다. 6e는 이것을 금칙어 토크 창에 다시 연결했다.

- **리모트(`server/Net`):** `Settle`(서버 → 클라이언트, `{ key, cutoff }`), `Transcript`, `Settled`를 다시 열었다. `VoicePing`은 V2의 보조 진행자용 활동 시계(`Match.lastActivityAt`)에만 쓰였고 V3에는 쓰는 곳이 없어 되살리지 않고 지웠다(`JudgeService`의 `onVoicePing`·`markActive`, `Config.VOICE_PING_INTERVAL`, `Match.lastActivityAt`도 함께).
- **`RoundService`(연결 담당):**
    - 대화 구간 시작(`setTalkStage("talk")`): `Match.talkStartedAt = now`, `Match.cutoffAt = ∞`, `JudgeService.setOpen(Match.voiceJudging)`.
    - 판이 결정되는 순간(모든 목숨 결과가 지나가는 `tell()`의 `noteDecision`): 토크의 대화 구간이면 `Match.cutoffAt = now`. 구제 대기 때문에 토크가 조금 더 이어져도, 결정 뒤에 시작된 말은 정산에 도착해도 안 센다(설계 2번).
    - 정산(`settleTalk`): `Match.cutoffAt = min(cutoffAt, now)` → `VOICE_JUDGING`이고 대화가 열렸던 토크면 `JudgeService.settle(cutoff)`(모든 음성 생존자의 클라이언트가 "보낼 말을 다 보냄"을 알릴 때까지, 최대 `SETTLE_MAX` 5초). 그동안 늦게 걸린 사람은 바로 날리지 않고 모아 둔다(`holdingLate` → `heldFails`). 기다림이 끝나면 곧바로 `JudgeService.setOpen(false)`(더 받지 않음) → 모아 둔 것을 구제가 모두 끝난 뒤 한 사건으로 함께 적용(`releaseHeld`) → 기다리던 구제·레버 끝내기(최대 `RESCUE_SECONDS + LEVER_SECONDS + SETTLE_SLACK`) → 경계 시각 되돌리기 → 단어 알려 주기·지우기. 설계 6번의 정산 순서(새 입력 마감 → 받아쓰기 기다림 → 구제·레버) 그대로.
    - 채팅 적발 뒤의 처리(땡 → 진행자 구제 대기, 진행자가 없으면 바로 발사)를 `caught(player, word)`로 빼서 채팅(`onChat`)과 받아쓰기(`onSpeechHit`)가 함께 쓴다.
    - `onSpeechHit`: 정산 구간에 도착한 전사도 받는다(`judgingOpen(player, late)`). 말이 토크 안에서 시작됐는지는 `JudgeService`가 이미 범위로 검사했다. 그 사람의 판정이 열려 있으면(구제 대기 등) 합친다(설계 4번).
    - 판 정리(`cleanup`)에서도 `JudgeService.setOpen(false)`.
- **`JudgeService`:** 정산 때 채팅 참가자는 기다리지 않는다(받아쓰기를 안 하므로). 빈도 제한과 길이 검사(상한의 4배 넘으면 읽지 않음)를 UTF-8 검사보다 먼저 한다. 판정을 열 때 전사 번호 기록을 비운다. 주석을 6e·토크 기준으로 고침.
- **클라이언트(`client/init.client`):**
    - `talkingByVoice()`: 토크의 대화·정산 구간이고 내가 살아 있고 채팅 참가자가 아니면 참.
    - 인식기는 마이크 시험 때와 `talkingByVoice()`일 때만 켠다(받아쓰기 요청은 경험 전체에 분당 `1 + 5 × 동시 접속자` 한도).
    - 받아쓴 글은 `talkingByVoice()`일 때만 `Transcript`로 보낸다(화면에는 안 띄움).
    - `Settle`을 받으면 `Speech.waitSettled(cutoff, cutoff + END_TOLERANCE, SETTLE_MAX)` 뒤 `Settled(key)`.
- **설정:** `VOICE_JUDGING = false` 그대로. `SETTLE_MAX`·`END_TOLERANCE`·`SETTLE_NOTICE_AFTER`·`TRANSCRIPT_*`는 V2 값 그대로.
- **시간 예산:** 금칙어 토크의 `expectedSeconds`에 정산의 가장 긴 기다림(`SETTLE_MAX + RESCUE_SECONDS + LEVER_SECONDS + SETTLE_SLACK`)을 넣었다(예전엔 레버·여유가 빠져 1.7초 모자랐음).

## 시험

- `python -I tools/tests/run_tests.py` → 전부 통과. `python -I tools/lint/run_lint.py` → 새 문제 0건(없어진 기존 경고 1건 — 지운 `onSpeech` 호출의 인자 수 — 를 `--update-known`으로 목록에서 지움).
    - round 14d: 받아쓰기가 켜진 토크에서 토크 안의 말에 금칙어가 있으면 바로 발사(진행자 없음), 토크 전에 시작됐을 수 있는 말은 안 셈.
    - round 14e: 정산 때 `Settle`(토크 끝 시각)을 보내고 기다림. 토크 안에서 시작돼 정산 중에 도착한 전사는 걸리고, 끝난 뒤 시작된 말은 안 걸림. 모두 `Settled`를 보내면 `SETTLE_MAX`를 기다리지 않고 넘어감.
    - round 14f: 토크가 끝나면 받아쓰기 판정이 닫힘.
    - round 14g: 구제 대기 중에 판이 결정되면(토크가 이어짐) 결정 뒤에 시작된 말은 정산에 도착해도 안 셈.
    - round 14i: 구제 대기 중에 판이 결정되고 토크가 이어지는 동안 도착한, 결정 전에 한 말의 전사는 센다(모아 뒀다가 정산 뒤 적용).
    - round 14h: 정산 중 늦게 걸린 두 사람은 기다림이 끝날 때까지 그대로 있다가 한 사건(`LifeLost` 한 번)으로 함께 목숨을 잃음.
    - 작성자가 일부러 고장 내 확인(되돌림): 정산 중 늦은 전사를 안 받게 → 14e 실패, 정산 기다림을 빼면 → 14e 실패, 대화 구간에 판정을 안 열면 → 14d 실패, 결정 순간 cutoff를 안 정하면 → 14g 실패, 늦은 탈락을 안 모으면 → 14e·14h 실패.
    - server 1~2절(기존): 범위 규칙, 정산 기다림·알림.
- **Studio 다중 시험(v3_chat, 서버 + 4명, `BW_VoiceJudging` 켬, 진행자 Player1):** 진행자가 금칙어 토크를 고르고 "바로 시작" → 60초 뒤 정산에서 네 클라이언트 모두 바로 `Settled`(key=1)를 보냄. 오류 로그 없음(Studio 전용 음성 그룹 경고만). Studio에는 받아쓰기가 없어서 전사·판정 자체는 볼 수 없다.

## 교차검증 (Codex 1번 + 새 Claude 검토자 1번)

- **둘 다(Codex P1, Claude P2):** 판이 결정된 시각이 cutoff에 안 들어감(구제 대기 동안 토크가 이어져 결정 뒤에 시작된 말이 정산에서 목숨을 뺄 수 있음) → `noteDecision`.
- **둘 다 P2:** 받아쓰기 기다림이 끝난 뒤에도 구제 대기 동안 판정이 열려 있음(늦은 적중이 "땡"만 울리고 사라지거나 구제가 새로 생김) → 기다림 직후 `setOpen(false)`.
- **Codex P1:** 정산 중 전사 도착 순서가 누가 먼저 떨어지는지(전멸 결승 대상)를 바꿈 → 늦은 탈락을 모아 함께 적용(`holdingLate`·`releaseHeld`).
- **Codex P2:** 큰 전사를 빈도 제한 전에 UTF-8 검사함 → 순서 바꿈 + 길이 상한.
- **Claude P3 고침:** 토크 시간 예산 1.7초 모자람(`SETTLE_SLACK`), 전사 번호 기록을 판정 열 때 비움.
- **Codex 재확인(1번):** 위 네 지적은 고쳐졌다고 확인. 새 P2 1건 — 결정 뒤 구제 대기로 토크가 이어지는 동안에는 결정 **전**에 한 말의 전사가 도착해도 버려지는데, 같은 전사가 정산에 오면 인정돼 도착 시점에 따라 결과가 달라짐 → 결정 순간부터 정산과 똑같이 받아 모아 둠(`noteDecision`이 `holdingLate`도 켬, `onSpeechHit`은 결정 뒤면 late로 판정). round 14i 추가(되돌리면 실패 확인). 그 결과 결정 뒤의 채팅 구제 실패도 정산 기다림 뒤에 함께 떨어지므로 round 14b는 정산 끝까지 기다리게 고침(결과는 같음: 결승 전에 본 게임 목숨 1개). 규칙대로 이 수정 뒤 재확인은 더 받지 않음.
- **P3 남김:** `Speech.luau`의 시간·한도 숫자(`WAIT_LIMIT`·`EXPIRED_KEEP` 등)가 Config 밖(V2 때부터, 클라이언트 모듈 안 상수 — 옮길 시점은 오너와), 마이크 시험을 안 한 대기실·관전자 클라이언트는 인식기를 켜 둠(6e 전부터, 라이브에서 한도 잴 때 함께 봄), Settled를 일부러 안 보내는 클라이언트가 토크마다 최대 5초 늦출 수 있음(상한 있음), 진행자 있는 음성 적중 → 구제 → 함께 적용 경로와 채팅 참가자 제외·`SETTLE_MAX` 시간 초과는 round 시험이 직접 안 봄(server 2절이 시간 초과·알림을 봄).

## 남은 것 (라이브 시험, 오너 승인 뒤)

- 게시 장소(STT 시험 장소 84102094280848)에서 `VOICE_JUDGING`을 켠 사본으로: 받아쓰기 정확도(금칙어를 말하면 걸리는지, 비슷한 말에 잘못 걸리지 않는지), 10명이 60초 말할 때 분당 요청 한도, 정산 기다림 길이, 폰에서의 인식기 켜고 끄기.
- 확인 뒤 `Config.VOICE_JUDGING = true`로 바꾸는 것은 오너 결정.
