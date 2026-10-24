# 장외홈런 · 사운드 · 조명 (1단계): 만든 기록 (2026-10-25)

후임 에이전트용 기록이다. 결정과 규칙은 `docs/DESIGN.md`(결정 6, 3·4번)가 기준이다. 앞선 기록은 `docs/HEALTH_AIM_2026-10-25.md`.

## 무엇을 만들었나

오너: "1. 장외홈런, 2. Alt 그대로, 3. 향상된 그래픽과 사운드 필요, 맵의 확장". 계획을 세워 교차검증했다(꾸미기 전에 맵 구조부터 하도록
순서를 바꿈, DESIGN 결정 6). 그중 1단계를 만들었다.
- **장외홈런:** 체력 0이 되는 한 방에 하늘 높이 날아가고(위 120, 옆 60) 빛 꼬리를 남긴다.
  - 맞은 자리에 큰 금색 "홈런!"이 뜨고, 방망이 "딱!"과 환호가 난다.
  - 1.1초 뒤 서버가 몸을 관전석으로 옮기기 직전 자리에 "✦"가 반짝이고 소리가 난다.
  - 화면 위에 "A → B 홈런!" 알림. 떨어짐도 "A → B 떨어뜨림" / "B 떨어짐"(결과가 난 뒤의 떨어짐은 세지 않음).
- **사운드:**
  - 칙칙폭폭 루프, 휘두르는 휙, 맞는 소리 세 단계(퍽 / 빡 / 홈런 딱 + 환호)
  - 카운트다운 째깍, 시작 기적, 승리음 + 환호
  - 대기 음악(Country Fiddle), 카운트다운·난투 음악(Resophonic Reel)
  - 오른쪽 아래 "때리기" 버튼 위 "♪ 음악 켬/끔" 버튼(음악만 끔)
- **조명:** 프로젝트 파일 `Lighting`에 늦은 오후(16.4시) 햇빛, ShadowMap 그림자, 먼지 낀 Atmosphere, 약한 Bloom·ColorCorrection·SunRays.
  관전석은 그림자를 끔(떠 있는 상자의 큰 네모 그림자).

## 모듈

| 모듈 | 바뀐 것 |
|---|---|
| `shared/Config` | `Config.Sounds`(이름 → id·크기·자르기·반복·음악 여부, 출처 주석), `Hit.SmashPush/SmashLift` 60/120, `Feedback.Gold`, `Fall.HomeRunSeconds` 1.1, `Feedback`의 홈런 글자·꼬리·반짝·알림 시간(옛 HitSound·SwingSound·SmashSeconds 없앰) |
| `shared/SoundBank`(새) | Config.Sounds 재생: `play(name, at?)`(3D 또는 화면 전체, `seconds`면 로드된 뒤부터 세어 끝 0.5초 줄이며 자름), `loop(name)`, `preload()`(시작할 때 전부 미리 받기), `playing(name)`(환호를 한 번만), `setMusic(on)`(음악 SoundGroup 볼륨). 클라이언트 부품끼리는 require하지 않는 규칙 때문에 shared에 둠, 서버에서는 아무것도 안 함 |
| `shared/Names` | `FeedRemote` |
| `server/Net` | `Feed` 리모트 |
| `server/RoundService` | `eliminate(model, how)`: how = "homerun"/"fall"/"gone". 홈런은 1.1초, 떨어짐은 1.6초 뒤 관전석. "gone"(죽음·나감)이 아니면 `announce(피해자 이름, 떨어뜨린 사람 이름?, how)` |
| `server/Main` | FallWatch → "fall"(난투 중일 때만 — 결과 뒤 승자가 떨어져도 승자), 스매시 → "homerun", `announce` → `Feed:FireAllClients` |
| `server/ArenaBuilder` | 관전석 부품 `CastShadow = false` |
| `client/HitFeedback` | SoundBank 사용: 휘두르기 "Swing", 맞음 "HitLight", 날림이면 "HitLaunch"를 더하고, 홈런이면 화면 전체로 "HomeRun" + "Cheer"(예측으로 이미 퍽을 냈어도 종류 소리는 남) |
| `client/HomeRunShow`(새) | "홈런!" 빌보드(떠오르며 사라짐), Trail, 몸을 매 프레임 따라가다 관전석 높이(70 − 8 위)에 나타나거나 사라지거나 1.7초가 지나면 마지막 비행 자리에 "✦" + "Twinkle", 그때 Trail을 끄고 지움(관전석까지 띠가 생기지 않게) |
| `client/FeedHud`(새) | 화면 위 알림 3줄(긴 이름은 글자가 줄어듦), 4초 뒤 흐려지며 사라짐 |
| `client/KnockFlight`, `client/FallDrift` | 날아가거나 떨어진 몸이 관전석에 도착하면 속도를 0으로(미끄러지지 않게) |
| `client/RoundAudio`(새) | 기차 루프, 단계별 음악(대기·결과 / 카운트다운·난투), 카운트다운 초마다 째깍, 카운트다운 → 난투에 기적, 승자 있으면 승리음 + 환호(홈런 환호가 나는 중이면 한 번만, 결과 중에 들어온 사람은 안 남), "때리기" 버튼 위 음악 버튼 |
| `client/init` | 위 셋 연결: 스매시 Hit → HomeRunShow, Feed → FeedHud, 매 프레임 FeedHud·RoundAudio |
| `default.project.json` | `Lighting` 속성과 자식(Atmosphere, Bloom, ColorCorrection, SunRays, Sky) |
| `tools/tests` | 홈런이 반짝일 때 아직 지붕 높이보다 위, 모래까지 0.2초 넘는 여유, 가장 높아도 관전석 아래 → 53개 |

## 음원 (Tick만 로블록스 내장, 나머지는 로블록스 공식 라이선스 업로드: Pro Sound Effects, APM Music)

로블록스 안에서는 어느 게임에서나 무료로 쓸 수 있다. 로블록스 밖(홍보 영상 등)에서 쓰는 것은 따로 확인해야 한다. 크리에이터 스토어 검색
결과의 올린 이가 "ProSoundEffects"(효과음)와 "APMOfficial"(음악)였다(Studio MCP `search_asset`, 2026-10-25).
Studio에서 12개 모두 로드됨을 확인했다(길이 확인). 저는 소리를 들을 수 없어 음질과 크기는 오너가 들어 봐야 한다.

| 이름 | id | 출처 이름 | 길이 |
|---|---|---|---|
| Swing | 9120972321 | Wood Whoosh Slicing Air Quick Swings 4 | 0.56 |
| HitLight | 9119330371 | Soccer Ball Tackle 4 | 1.01 |
| HitLaunch | 9125380595 | Baseball Wood Bat Hits Hard Ball Power Whack 1 (1.2초로 자름) | 1.83 |
| HomeRun | 9125380872 | Baseball Wood Bat Hits Hard Ball Power Whack 5 (2초로 자름) | 1.89 |
| Cheer | 9120973900 | Wrestling Crowd 2 (3.5초로 자름) | 20.79 |
| Twinkle | 9126073001 | Synth Sparkle Tone Ding 4 | 1.16 |
| Win | 9126073318 | Synth Sparkle Tone Ding 1 | 1.60 |
| Whistle | 9119628070 | Steam Train Whistle Single Blows Airy 2 (2.5초로 자름) | 5.03 |
| Tick | rbxasset://sounds/electronicpingshort.wav | 로블록스 내장 | 0.72 |
| Train | 9112889081 | Train Steam 2 (반복) | 58.2 |
| MusicWaiting | 1840254626 | Country Fiddle (APM, 반복) | 64.1 |
| MusicFight | 1838431777 | Resophonic Reel - 30's Mix (APM, 반복) | 131.0 |

## Studio에서 확인한 것

- 새로 빌드한 QA 장소(`.qa/TrainBrawl_QA2.rbxlx`, 조명 포함)에서 혼자 시험.
- 소리 12개 로드. 난투 중 기차 루프와 난투 음악 재생.
- 장외홈런(이번 시험만 한 대 피해 50으로 바꿔 두 대째에 홈런; 아래 수치는 검토 전 위 힘 110일 때 — 120으로 올린 뒤의 플레이어
  기록은 "교차검증" 아래):
  - 샌드백이 0.05초 뒤 날아가 0.55초에 가장 높이 43.8에 이르렀다. 1.1초 뒤 높이 21.3에서 사라졌다(지붕 위 공중, 관전석 아래).
  - 클라이언트 기록 순서: 첫 타 퍽 → 둘째 타 퍽·홈런 딱·환호, "홈런!"(맞은 자리), 빛 꼬리 → 1.12초 뒤 "✦"(높이 34.7, 49 앞)와 반짝 소리.
  - 화면 위 알림 "dogyes → 샌드백 1 홈런!", 떨어뜨린 수 1.
  - 마지막 샌드백 홈런으로 판이 끝나 승리음과 환호.
- 검토 반영 뒤 다시 확인한 것은 아래 "교차검증". 확인 못 한 것:
  - 시험 중 QA 창이 여러 번 최소화되고 Esc 메뉴가 열려 있어(다른 입력이 들어간 것으로 보임) 홈런 화면 캡처는 못 했다. 기록으로만 확인했다.
  - 조명 화면도 다음에 확인한다.

## 교차검증

- Codex: P1 없음. P2 — 순간이동 뒤에도 Trail이 남아 하늘에서 관전석까지 띠, 프레임 끊김을 순간이동으로 오인, 로딩 시간을 자르기
  시간에 셈(첫 재생이 무음). P3 — 긴 이름 알림 넘침.
- Claude 검토자: P1 없음. P2 — 같은 Trail 띠, 폰 가로 화면에서 음악 버튼이 "때리기" 버튼과 겹침. P3 — 관전석에 비행 속도로 도착,
  모래 착지까지 여유 0.17초, 순간이동 오감지, 미리 받기 없음, 결과 중 들어온 사람의 승리음·환호 중복, 홈런 소리가 날아가는 몸에 붙음,
  이름 식 중복·금색 중복·SoundBank 서버 보호, 문서 표현, Lighting 동기화 주의, 결과 뒤 승자 떨어짐 알림.
- 반영: 모두 고쳤다(위 120으로 올려 여유 0.27초, 관전석 높이로 도착 판정, Trail 끄기, 미리 받기·로드 뒤 자르기, 버튼 위치, 도착 정지,
  환호 한 번, 홈런 소리 화면 전체, 결과 뒤 떨어짐 무시, 문서). Lighting은 `$path` 없이 적힌 속성만 덮어써서, 이미 있는 장소에
  동기화하면 다른 이름의 기존 효과는 남는다(새로 빌드한 장소 기준).
- 재확인(1회): Codex — 대부분 FIXED, 환호 중복(결과가 먼저 오는 경우)·`setMusic` 서버 보호·문서 한 줄 PARTLY, 새 P1·P2 없음.
  Claude 검토자 — 코드 지적 모두 FIXED, 문서 수치 두 줄 PARTLY, 새 P1·P2 없음. → 환호는 양쪽에서 `SoundBank.playing`으로 한 번만,
  `setMusic`은 클라이언트에서만, 문서 수치 표시(다시 검토받지 않음). P3로 남김: 결과 단계에서 떨어진 승자는 다음 대기로 옮겨질 때까지
  (최대 5초) 모래에 누워 밀려감, 떨어뜨린 사람이 나갔으면 계정 이름이 나옴, 네트워크가 0.6초 넘게 출렁이면 반짝임이 늦은 자리에서.
- 검토 반영 뒤 Studio:
  - 클라이언트 2개(이번 시험만 한 대 피해 50): Player2가 홈런을 맞아 "홈런!" → 최고 높이 49.1 → 하늘(높이 31.4)에서 "✦" →
    관전석 도착(72.5). 빛 꼬리가 꺼짐(관전석까지 띠 없음). 도착 속도 14.8 → 0으로 멈추고 일어남.
  - 폰(Galaxy A06 시뮬레이터): "♪ 음악 켬" 버튼이 "때리기" 버튼 위에 있어 겹치지 않음. 알림의 "→"와 "♪"가 제대로 보임.

## 알려진 한계와 다음

- 소리 크기 균형과 음질은 들어 봐야 한다(특히 관중 환호가 사막에 어울리는지, 음악 크기).
- 음원이 나중에 내려가면 그 소리만 조용해진다(게임은 멈추지 않음).
- 다음: 2단계 맵 구조(회색 상자), 3단계 꾸미기(DESIGN 결정 6).
