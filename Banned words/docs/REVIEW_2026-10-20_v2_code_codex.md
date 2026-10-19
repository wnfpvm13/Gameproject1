# V2 코드 검토 (2026-10-20, Codex gpt-6.1-sol xhigh read-only)

실제 `src/` 28개 파일과 Rojo 설정·맵·설치기·외부 보고서를 확인했습니다. **가장 큰 결함은 전사와 발화 시작 시각의 연결 오류입니다.** 아래 ‘재현’은 실제 모듈을 Luau에서 모의 시계·이벤트로 실행한 결과이며, Studio·실기기 검증과는 구분했습니다. 파일은 수정하지 않았습니다.

1. **P0 후보 · 실기기 미검증 — 반향으로 타인이 나를 탈락시킬 수 있음**  
   [Speech.luau:135](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/Speech.luau:135>), [JudgeService.luau:51](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:51>)  
   B가 A의 금칙어를 말하고 A의 스피커 소리가 마이크로 들어오면 A의 전사로 즉시 탈락합니다. 코드만으로 실제 발생 여부는 확정할 수 없습니다. 기존 이어폰 안내에 더해 PTT를 제공하고, PC·폰의 스피커/이어폰 조합으로 검증해야 합니다. Roblox도 반향 개선과 별개로 PTT·헤드폰을 권장합니다. [공식 발표](https://devforum.roblox.com/t/full-release-speech-to-text-api/4357786)

2. **P1 · 재현 — 늦은 전사에 다음 발화의 시작 시각이 붙음**  
   [Speech.luau:75](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/Speech.luau:75>), [Speech.luau:111](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/Speech.luau:111>)  
   A가 98초에 시작하고, 전사가 도착하기 전에 B를 101초에 시작하면 A에도 `101`을 붙여 보냅니다. 새 단어가 100초에 발효됐다면 면제돼야 할 A가 탈락합니다. 실제 이벤트 순서 재현에서 `98 → 101`을 확인했습니다.  
   **수정:** 진행 중 구간과 결과 대기 구간을 분리하고, 구간별 시작·종료 시각과 ID를 보존하세요. 10초 연속 발화의 다음 구간도 ‘전사 수신 시각’으로 시작시키면 안 됩니다.

3. **P1 · 재현 — 200바이트 절단으로 정상 발화를 잃음**  
   [JudgeService.luau:33](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:33>), [Config.luau:47](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/shared/Config.luau:47>)  
   `string.sub`은 문자 수가 아닌 바이트 수로 자릅니다. `"가"×67 .. "사과"`는 뒤의 금칙어가 사라지고 UTF-8도 깨졌습니다(`utf8.len == nil`).  
   **수정:** 정상 STT 구간 전체를 수용하도록 한도를 조정하고 UTF-8을 검증하세요. 길이 제한으로 정상 전사의 뒷부분을 조용히 버리는 처리는 제거해야 합니다.

4. **P1 · 재현 — 경기 종료 후 시작한 발화로 결과가 바뀜**  
   [RoundService.luau:196](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/RoundService.luau:196>), [JudgeService.luau:42](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:42>)  
   종료 후에도 1.2초 동안 `Talk`·판정 열림 상태가 유지되고, 판정에는 종료 시각 검사가 없습니다. 종료가 330초일 때 **330.5초에 시작한 발화도 탈락 처리됨**을 재현했습니다. 최후의 1인이 정해진 뒤에도 같은 문제가 있습니다.  
   **수정:** 종료 조건을 충족한 순간 `cutoffAt`을 고정하고, 유예 중에는 그 시각 이전에 시작된 구간만 받으세요.

5. **P1 · 재현 — 중복 제거가 서로 다른 정상 발화를 삭제함**  
   [JudgeService.luau:35](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:35>)  
   같은 전사 문자열을 2초 안에 다시 말하면 무조건 버립니다. 새 단어 발효 전 `"딸기"`는 통과하고, 발효 후 다시 말한 `"딸기"`도 버려져 생존하는 경우를 재현했습니다. 0.25초 수신 간격 제한 역시 몰려 도착한 정상 결과를 잃을 수 있습니다.  
   **수정:** 문자열 대신 구간 ID로 중복을 제거하고, 정상 결과는 큐에서 모두 판정하세요.

6. **P1 · 확인 — STT 사용 구간 제한만으로 요청 한도를 지키지는 못함**  
   [init.client.luau:49](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/init.client.luau:49>), [Speech.luau:81](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/Speech.luau:81>)  
   켜는 대상은 규칙대로 제한했지만, 켜진 동안의 요청량 관리가 없습니다. 예컨대 CCU 10명의 한도는 분당 51건인데, 전원이 6구간씩 생성하면 60건입니다. 장애 감지도 토스트만 띄워 판정 불능 상태에서 경기가 계속됩니다. 실제 요청량은 미측정입니다.  
   **수정:** 요청량·VAD 대비 전사 도착률을 계측하고 필요한 용량을 확보하세요. 장애 시에는 판정·타이머를 함께 보류하는 처리가 필요합니다. [공식 한도·구간 설명](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioSpeechToText.yaml)

7. **P1 · 확인 — 각자 준비 완료여도 서로 대화할 수 있다는 보장이 없음**  
   [Match.luau:70](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/Match.luau:70>), [VoiceService.luau:42](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/VoiceService.luau:42>)  
   참가 조건은 개인 마이크 준비뿐입니다. 연령 확인·통신 설정 때문에 상호 음성이 차단된 이용자도 같은 경기에 들어갑니다. `Deny + {}`는 플랫폼의 통신 호환성을 보장하지 않습니다.  
   **수정:** 서버에서 `GetChatGroupsAsync()`로 상호 대화 가능한 참가자 집합을 구성하세요. 이 API의 Studio 검증은 Team Test가 필요하므로 기존 로컬 3인 시험으로는 확인되지 않습니다. [공식 문서](https://create.roblox.com/docs/reference/engine/classes/VoiceChatService)

8. **P1 · 재현 — 예고 이후 발생한 연속 탈락은 단어 추가를 연기하지 않음**  
   [WordService.luau:66](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/WordService.luau:66>), [WordService.luau:82](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/WordService.luau:82>)  
   연기 조건은 예고 전 대기 루프에서만 검사합니다. 89초 예고 후 2명이 탈락해도 99초에 그대로 추가되는 것을 재현했습니다. 또한 [RoundService.luau:61](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/RoundService.luau:61>)은 `said`만 집계해 리셋·낙사 탈락도 통계에서 빠집니다.  
   **수정:** 발효 직전까지 탈락 창을 재검사하고, 연기되면 예고 시각도 갱신하세요. 규칙의 ‘탈락’에 맞게 집계 대상을 통일해야 합니다.

9. **P1 · 확인 — 안전했던 카드가 진행 중 금칙어를 포함하게 됨**  
   [HostService.luau:23](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/HostService.luau:23>), [HostService.luau:105](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/HostService.luau:105>), [HostPanel.luau:65](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/UI/HostPanel.luau:65>)  
   `"주말에 하고 싶은 것"` 카드를 띄운 뒤 `"주말"`이 추가돼도 카드는 남습니다. 사건의 `{name}`도 안전 검사 **후** 치환하므로 표시 이름에 금칙어가 있으면 검사에서 빠집니다.  
   **수정:** 최종 표시 문자열을 검사하고, 단어 추가 때 표시 중인 카드·상황·역할 문구를 재검증하세요. 이 재검증 연결은 RoundService가 맡으면 됩니다.

10. **P2 · 조건부 경합 — 유령 리로드 완료 전에 다음 경기 참가 가능**  
    [GhostService.luau:162](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/GhostService.luau:162>), [Match.luau:73](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/Match.luau:73>)  
    리로드 작업을 기다리지 않으며, 참가 검사도 Humanoid의 체력만 확인합니다. 로딩이 재경기 대기보다 길면 Workspace 배치가 끝나지 않은 캐릭터를 참가자로 잡아, 엔진의 최종 스폰 이동이 착석을 덮어쓸 위험이 있습니다. 실기 재현은 필요합니다.  
    **수정:** 플레이어별 로딩 상태를 추적하고 배치·착석 확인 후 참가시키세요. `LoadCharacter()`는 deprecated이므로 `LoadCharacterAsync()`로 교체하되 완료 관리도 함께 해야 합니다. [공식 생성 순서](https://create.roblox.com/docs/reference/engine/classes/Player)

11. **P2 · 확인 — 다른 플레이어의 부활 후 결과 빌보드가 복구되지 않음**  
    [Billboards.luau:136](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/Billboards.luau:136>), [init.client.luau:182](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/init.client.luau:182>)  
    재렌더는 서버 이벤트와 **내** `CharacterAdded`에 의존합니다. 마지막 탈락자가 Result 진입 후 부활하면 기존 Head의 GUI는 사라지고, 다른 이용자에게 새 캐릭터의 결과 단어가 표시되지 않을 수 있습니다.  
    **수정:** 모든 표시 대상의 캐릭터 교체·Head 준비를 구독해 저장된 뷰를 다시 렌더하세요.

12. **P2 · 물리 재검증 필요 — 장벽 충돌 성공이 링 진입 금지까지 보장하지는 않음**  
    [build_lounge_map.luau:138](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/tools/build_lounge_map.luau:138>), [build_lounge_map.luau:187](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/tools/build_lounge_map.luau:187>)  
    장벽 높이는 12이고, 바깥 가구·램프는 발판이 됩니다. 관전자끼리 밟거나 높은 가구에서 뛰어넘는 경로는 기존 충돌 탐침 시험과 별개입니다. 실제 우회 성공은 확인하지 않았습니다.  
    **수정:** 발판을 이용한 점프 시험을 추가하고, 높은 장벽이나 서버의 링 내부 복귀 처리로 보완하세요.

**모듈 구조는 대체로 지시를 충족합니다.** 서비스 간 직접 `require`와 순환 의존은 없고, JudgeService의 탈락·발화 콜백 연결도 좋습니다. 다만 엄격한 “RoundService만 연결”에는 [Main.server.luau:4](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/Main.server.luau:4>)의 VoiceService 직접 시작이 어긋납니다. 이를 RoundService로 옮기세요. 또한 [Match.luau:9](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/Match.luau:9>)는 ‘데이터 전용’ 주석과 달리 통신·모집·상태 변경을 함께 담당합니다. 향후 꼬일 지점은 순환 의존보다 이 공유 상태의 수정 책임입니다.

API 자체의 명백한 오용으로 보지 않은 부분도 있습니다. **BillboardGui의 `fromScale`은 stud 크기로 유효**하고, 서버의 충돌 그룹·음성 접근 목록 설정 방향도 맞습니다. `Enabled` 토글 역시 가능하지만, 전사 버퍼 폐기·진행 중 요청 취소까지 보장한다는 명세는 확인되지 않았습니다. 배정→대화 전환의 실제 발화 경계는 별도 실기 검증이 필요합니다. [BillboardGui 공식 설명](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/BillboardGui.yaml), [STT 공식 설명](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioSpeechToText.yaml)

기본 포함 판정 예시 6건은 통과했고 설치 산출물도 현재 `src/`와 일치했습니다. NFC는 독립 Luau CLI에서 지원되지 않아 이번 실행 검증에서 제외했습니다.
---

## 재확인 (수정 후, Codex)

실제 파일과 모듈 모의 실행으로 확인했습니다. **2·4·6·8·9·12에 문제가 남습니다.** 실기기·Team Test는 미실시했고 파일은 수정하지 않았습니다.

1. **확인 — 반향:** [MicPanel.luau:45](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/UI/MicPanel.luau:45>) 이어폰 안내 유지. 반향·PTT 효과는 실기기 과제로 남아 있습니다.

2. **문제(P1) — 발화 시각:** [Speech.luau:119](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/Speech.luau:119>) 대기열·ID는 반영됐지만, A의 전사가 누락되면 B의 전사에도 A의 시작 시각이 붙습니다(`101→98` 재현). 123줄은 여전히 **수신 시각**을 다음 구간 시작으로 써 `100→100.5`로 밀립니다. **수정:** 누락 구간과 다음 전사를 무조건 FIFO로 연결하지 말고, 연속 발화는 [10초 녹음 경계](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioSpeechToText.yaml)로 분리하세요. 대응이 불명확한 구간은 판정을 보류해야 합니다.

3. **확인 — 절단:** [JudgeService.luau:33](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:33>) UTF-8 검증·600바이트 문자 경계 절단 정상. 한글·이모지·잘못된 UTF-8 사례를 통과했습니다.

4. **문제(P1) — 종료 시각:** [RoundService.luau:198](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/RoundService.luau:198>) 최후 1인이 정해져도 다음 0.2초 폴링까지 `cutoffAt=∞`입니다. 그 사이 시작한 발화로 마지막 생존자까지 탈락하는 것을 재현했습니다. **수정:** 탈락 처리 안에서 종료 조건 성립 즉시 cutoff를 고정하세요. 시간 만료 시각 제한은 정상입니다.

5. **확인 — 중복:** [JudgeService.luau:86](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:86>) 같은 문장·다른 ID는 판정하고, 같은 ID만 제거합니다. 3초 6건 제한도 반영됐습니다.

6. **문제(P2) — 요청량 경고:** [JudgeService.luau:66](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/JudgeService.luau:66>) 임계치를 넘어도 **60초 이후 다음 전사**가 와야 경고합니다. 이후 침묵하면 경고가 누락됩니다. **수정:** 매 수신 시 임계치를 검사하고 분당 한 번 경고하세요. 마이크 테스트·실패 요청은 현재 계측되지 않으며 장애 보류도 미구현입니다.

7. **확인 — 통신 호환성:** [VoiceService.luau:32](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/VoiceService.luau:32>) `GetChatGroupsAsync()` 검사는 아직 없습니다. 남은 과제라는 설명과 일치합니다.

8. **문제(P1) — 연기:** [WordService.luau:69](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/WordService.luau:69>) 마지막 0.25초 대기 후 바로 추가하므로, 그 사이 연속 탈락하거나 경기가 끝나도 단어가 추가됩니다. 재현했습니다. **수정:** 추가 직전에도 `stillTalking()`·연기 조건을 검사하세요. 예고 재전송·취소·`left` 제외 집계는 반영됐습니다.

9. **문제(P1) — 카드:** [HostService.luau:151](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/HostService.luau:151>) 서버는 마지막 카드 하나만 검사하지만 화면에는 주제와 사건이 함께 남습니다. ‘주말’ 주제→안전한 사건→‘주말’ 추가 시 주제가 숨겨지지 않았습니다. **수정:** 표시 중인 주제·사건을 각각 저장하고 재검사하세요. 이름 치환 후 검사·역할 겹침 방지는 정상입니다.

10. **확인 — 리로드:** [Match.luau:89](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/Match.luau:89>) `loading`과 Workspace·HRP 확인이 반영됐습니다. 느린 실제 캐릭터 로딩은 별도 검증이 필요합니다.

11. **확인 — 빌보드:** [init.client.luau:190](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/init.client.luau:190>) 기존·신규 플레이어 모두 `CharacterAdded`에서 Head를 기다린 후 `refresh()`합니다.

12. **문제(P2·신규) — 장벽 가드:** [GhostService.luau:125](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/services/GhostService.luau:125>) 높이 30·1초 검사는 반영됐지만, 발사 중인 탈락자도 아웃사이더여서 링 안에 있으면 스폰으로 이동됩니다. 이동 조건을 재현했습니다. **수정:** 발사 중인 캐릭터를 가드에서 제외하고 연출 종료 후 적용하세요.

13. **확인 — 구조:** [RoundService.luau:228](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/server/RoundService.luau:228>) VoiceService 시작 이동·Match 주석 수정 완료. 설치기도 소스 28개와 일치합니다.

14. **확인 — 화면:** [RingCamera.luau:46](<C:/Users/wnfpv_hjufeq0/orca/workspaces/Gameproject1/금칙어게임만들기/Banned words/src/client/RingCamera.luau:46>)과 맵 생성기의 `9/11/6`, HUD 64px·테마/역할 통합, 사건/예고 `62%/71%` 모두 반영됐습니다.
## Claude 조치 (재확인 후)

- 2: 3초 안에 글자가 안 온 구간은 버림(다음 문장에 시각을 넘기지 않음), 10초 끊김의 다음 조각은 1초 앞당겨 시작(관대한 쪽)
- 4: 탈락 처리 안에서 종료가 정해지는 즉시 cutoffAt 고정
- 6: 전사마다 임계치 검사, 분당 1회 경고
- 8: 추가 직전 같은 단계에서 stillTalking·연기 조건 확인 후 추가
- 9: 주제·사건을 따로 저장하고 각각 재검사(hide which=topic|event)
- 12: 발사된 몸(launchedBody)은 링 가드에서 제외
- 재테스트(3인): 탈락→유령 14.8에서 멈춤, 진행 중 리액션, 2·3번째 단어 추가, 서버 오류 없음
