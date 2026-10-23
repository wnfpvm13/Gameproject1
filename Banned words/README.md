# Banned words — 금칙어 게임 Korean

MonCook과 별개인 로블록스 음성 파티 게임. V3: 밝은 실내 수영장의 플라잉 체어에 앉아 미션을 하고, 자기만 모르는
금칙어(머리 위, 본인만 못 봄)를 피한다. 실패하면 의자가 뒤로 젖혀지며 "펑" 하고 래그돌로 수영장에 날아간다.
(V2는 원형 라운지 의자에서 받아쓰기로 판정했다.)

**설계 기준: V3 (2026-10-22, 2026-10-23 미니게임 개편으로 최신화) — [docs/DESIGN_V3.md](docs/DESIGN_V3.md)** (실내 수영장 + 진행자 + 미니게임 10가지, 금칙어는 미니게임 "금칙어 토크" 하나, 의자 벨·발언권, 자유 대화 없음). 개편은 묶음 6a~6e로 만든다(설계 12번); 아래 "지금 코드"는 개편 전 흐름이다.
지금 코드는 V3 1단계 묶음 5b까지(1단계 전체) — 채팅 자동 판정·구제·채팅 전달 규칙: [docs/CHAT_JUDGING_2026-10-23.md](docs/CHAT_JUDGING_2026-10-23.md), 비공개 서버 금칙어(1인 1단어, 진행자 귀 판정·다시 뽑기): [docs/BANNED_WORDS_2026-10-23.md](docs/BANNED_WORDS_2026-10-23.md), 한마디·투표·진행자 판정(단상 레버): [docs/ONE_WORD_2026-10-23.md](docs/ONE_WORD_2026-10-23.md), 퀴즈·결승 퀴즈·룰렛(2D 원판): [docs/QUIZ_ROULETTE_2026-10-23.md](docs/QUIZ_ROULETTE_2026-10-23.md), 진행자 모드(지원·선정·미션 메뉴·효과음·판 중 교체): [docs/PRESENTER_2026-10-23.md](docs/PRESENTER_2026-10-23.md), 채팅 참가(음성이 안 되는 사람, 말풍선 강조): [docs/CHAT_JOIN_2026-10-23.md](docs/CHAT_JOIN_2026-10-23.md), 판 규칙(목숨 3개·8분·결승): [docs/ROUND_RULES_2026-10-22.md](docs/ROUND_RULES_2026-10-22.md), 발사 연출: [docs/FLING_2026-10-22.md](docs/FLING_2026-10-22.md). 공개 서버는 금칙어 없이 미션만(1단계), 비공개 서버는 진행자가 귀로(음성) 판정하고 채팅은 자동 판정 + 진행자 구제다. 2단계(공개 서버 금칙어, 음성 인식)는 실기기 시험 뒤. V2 규칙·코드 구조·테스트 기록은 [docs/DESIGN_V2.md](docs/DESIGN_V2.md), V2 마지막 상태는 git 태그 `banned-words-v2-final`.
- V3 맵(밝은 실내 수영장, 맵 `tools/build_pool_hall.luau` → 조명 `tools/build_pool_lighting.luau`): [docs/VISUAL_V3_POOL_2026-10-22.md](docs/VISUAL_V3_POOL_2026-10-22.md)
- 제작 내역 전체(처음부터 V2.1.1까지): [docs/HISTORY_2026-10-20.md](docs/HISTORY_2026-10-20.md)
- 그래픽(A안 예능 토크 스튜디오 세트, 맵 `tools/build_lounge_map.luau` → 조명 `tools/build_lounge_lighting.luau`): [docs/VISUAL_PLAN_2026-10-21.md](docs/VISUAL_PLAN_2026-10-21.md)
- 가상 시계 테스트 + 의존 방향 검사(Studio 없이): `python -I tools/tests/run_tests.py` (luau CLI 필요)
- 정적 검사(Roblox API 타입 + 린트): `python -I tools/lint/run_lint.py` (luau-lsp·selene·rojo 필요)

**코드 규칙(이 게임)** — 전역 규칙(`~/.claude/CLAUDE.md` 3번)의 구체 사항
- 서비스끼리는 require하지 않는다. 연결은 `RoundService`가 콜백으로 한다. UI 패널끼리도 require하지 않고, 클라이언트 연결은 `init.client`만 한다.
- 조정할 숫자(시간·확률·한도)는 `src/shared/Config.luau`에 둔다. 대화 중 플레이어가 소리 내 읽을 수 있는 새 고정 문구는 `Config.TEXT`에 넣는다(`tools/check_content.luau`가 단어장 전체와 대조한다). 예전 문구 일부는 아직 각 모듈 안에 있다.
- 바꾼 동작은 `tools/tests/run_tests.py`(가상 시계 테스트 + 고정 문구 검사 + 의존 방향 검사)와 `tools/lint/run_lint.py`로 확인한다. 층 규칙의 기준은 `tools/tests/check_deps.py`의 `ALLOWED` 표다(V2 때 설명은 `docs/DESIGN_V2.md` "개발 도구" 절, V3의 missions 층은 `docs/DESIGN_V3.md` 13번).
아래 2026-10-17 결정 중 수영장·버전1 동시 출시는 V2 결정으로 바뀌었다.

- 설계 원본(Claude Docs, 그림 포함): https://claude.ai/code/artifact/36208a40-0e2b-49e8-becf-d77f1b3fef31
- 저장소 사본: [docs/DESIGN.md](docs/DESIGN.md)
- 상태: 프로토타입 v0(수영장·의자·금칙어 탈락) — `docs/PROTOTYPE_v0.md`. STT 검증 기록은 `tools/stt_probe/`, `tools/stt_live_test/`.

## 오너 결정 사항 (2026-10-20, V2)

- 외부 재검토 보고서 규칙으로 전환: 자유 대화, 포함 문자열 판정, 금칙어 1→2→3 누적, 인원별 경기 시간,
  침묵 탈락 없음, 보조 진행자(테마·역할·주제·사건), 유령 관전 + 리액션, 빠른 재경기
- 맵: 원형 라운지 / 서버당 1경기 최대 10명 / 단어장+누적 먼저, 버전1(직접 출제)은 그다음 / 토크쇼 삭제
- 코드는 파트별 모듈로 나눠 꼬이지 않게

## 오너 결정 사항 (2026-10-17)

- 2~10명, 한국어 전용 서버, 목숨 1개
- "내 단어만 모르는" 예능형
- 버전1: 처음에 채팅으로 금칙어를 내고, 자기를 뺀 무작위 플레이어의 금칙어가 됨
- 버전2: 정해진 단어장으로 진행
- 첫 출시는 버전1·2만. 버전3(누적 금칙어)·버전4(팀 대항전)는 테스트 후 업데이트
- 게임 이름: 금칙어 게임 Korean
- 맵: 수영장. 틀리면 의자에서 날아감
- MonCook과 별도 폴더(`Banned words/`)

## 설계 과정 기록 (후임 에이전트용)

1. STT 가능 여부부터 확인: DevForum "Full Release: Speech-to-Text API"(2026-02, 한국어 2026-05 추가)와
   Creator Hub `AudioSpeechToText` 레퍼런스를 직접 열어 확인했다.
2. 설계는 Claude Docs 문서 하나에 섹션별로 채웠고, 판정 흐름도·아키텍처 그림은 문서 위젯으로 그렸다.
3. 재검토 1차(메인 에이전트)에서 고친 오류:
   - 목숨 1개로 바뀐 뒤 남아 있던 "목숨 -1", "3초 재판정 금지" 문구
   - 버전3 개수 계산 오류(4분에 4개 → 3분째 4개), "수영장 둔치", "남을 낙인" 오기
   - 위젯/본문에 "삐!"가 "샐!"로 들어간 오류(유니코드 이스케이프 실수 → 이후 한글은 글자 그대로 입력)
   - `"as":"text"` 수정에서 백틱이 코드 서식이 아니라 글자로 들어간 문제
4. 재검토 2차(Codex `gpt-6.1-sol` xhigh, read-only, 14건 지적 → 근거 확인 후 전부 반영):
   - **가장 큰 오류:** 서버에서 받아쓰기를 한다는 전제. 로블록스 측 답변(2026-05)에 "서버는 오디오 처리가 거의 다 꺼져 있다".
     → 받아쓰기는 클라이언트(SpeechClient), 판정은 서버. 조작 대비로 "증인 교차 확인" 추가.
   - 받아쓴 문장 전체 표시는 소통 제한 우회 위험 → 걸린 금칙어만 표시
   - 의심 판정 투표는 생존자·출제자 이해관계 + 2~3인 판에서 작동 불가 → 의심은 경고만(탈락 없음)
   - 공백 제거와 어절 경계 판정 충돌 → 어절 경계 유지, 공백 제거본은 의심 판정에만
   - 질문 카드가 10명 모두를 못 돌고 단답으로 통과 → 인원별 간격, 두 어절 이상, 반복 답 무효
   - 유도 점수 추임새 수확 → 직전 마지막 발화자 1명만, 순위는 생존 우선
   - 팀전 `OthersWords`가 팀원 단어를 클라이언트로 보내는 문제, 홀수 팀전, 동률, 이탈·리셋·동시 탈락, 텍스트 모드 응답 판정, 경기 시간 표기(5~8분 → 약 5~6분)
   - 호출 한도 소진 시 공백 → 탈락자 받아쓰기 중단 + "판정 일시 정지"
   - Codex 프롬프트/결과는 세션 스크래치패드에만 있었음. 다시 돌릴 때: `codex exec -m gpt-6.1-sol -c model_reasoning_effort=xhigh -s read-only --skip-git-repo-check -o <out> - < prompt.txt`

## 아직 검증 안 된 것 (1단계에서 반드시 확인)

- 클라이언트 `AudioSpeechToText`가 라이브 서버에서도 되는지, 다른 플레이어 목소리도 받아써지는지(증인 방식 전제)
- 한국어 단어 인식률(목표 80% 이상), 지연, 호출 한도 소모
- 출제 단계에 일반 채팅을 숨기고 서버만 받는 방법(TextChatService)
- Audio API로 거리 감쇠 없는 음성 연결
- 음소거 상태를 서버가 읽을 수 있는지
