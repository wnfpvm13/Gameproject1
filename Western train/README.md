# Western train — 서부 2인 협동 기차 게임

MonCook, 금칙어 게임과 별개인 로블록스 게임. 첫 콘텐츠는 B안 "지붕 위 오비": 한 명은 자기 아바타로 만든 얼굴 기관차가
되고(S를 누르면 만화처럼 납작), 다른 한 명은 그 지붕 위에서 오비를 한다. 설계와 결정 기록: [docs/DESIGN.md](docs/DESIGN.md)

**지금 코드: 시제품 1 — 납작해지는 얼굴 기관차** ([docs/PROTOTYPE_SQUASH_2026-10-23.md](docs/PROTOTYPE_SQUASH_2026-10-23.md),
몸체 재설계 [docs/LOCO_DRESSED_2026-10-23.md](docs/LOCO_DRESSED_2026-10-23.md), 얼굴 창·팔다리
[docs/FACECAM_LEGS_2026-10-24.md](docs/FACECAM_LEGS_2026-10-24.md))
- 들어오면 내 아바타가 "아바타 옷을 입은 기관차"가 되어 선로 위에 선다: 머리는 앞 얼굴, 셔츠 입은 몸통은 뒤 운전실, 팔은 바퀴
  크랭크 핀을 큰 주먹으로 쥐고 도는 연결봉, 다리는 뒤로 뻗은 범퍼, 보일러는 짙은 초록, 바퀴는 짙은 빨강. 내 캐릭터는 그 안에 숨는다.
- 화면 위 가운데 얼굴 창에 내 기관차 얼굴이 앞에서 보인다(플레이 카메라는 뒤에서 보므로).
- S(모바일 "납작" 버튼, 게임패드 B)를 누르고 있으면 납작, 떼면 "뽀용" 하고 출렁이며 복귀. 굴뚝 옆으로 증기가 새고, 뒤로 뻗은
  다리가 버둥거리고, 얼굴 창이 커진다.
- 아직 없는 것: 배경 흐름, 장애물·판정, 점프, 지붕 위 카우보이, 소리.

## 폴더

- `src/shared` — 서버·클라이언트 공용: `Config`(조정할 숫자), `Names`(이름), `SquashSpring`·`SquashPose`·`CrankMotion`(순수 수학),
  `PartUtil`(부품 도우미)
- `src/server` — `Main`(연결 + 플레이어별 선로 칸·기관차 수명), `Net`(리모트), `PrototypeStage`(땅·선로), `AvatarBody`, `LocomotiveBuilder`,
  `CharacterHider`, `SquashService`
- `src/client` — `init`(연결만), `SquashInput`, `LocomotiveAnimator`, `SteamPuff`, `DriverCamera`, `FaceCam`(얼굴 창)
- `tools/tests` — Studio 없이 도는 테스트, `tools/lint` — 정적 검사

## 코드 규칙 (전역 규칙 `~/.claude/CLAUDE.md` 3번의 이 게임 구체 사항)

- 서버 부품끼리, 클라이언트 부품끼리는 require하지 않는다. 연결은 `Main.server`와 `init.client`가 콜백으로 한다.
  공용 코드(`src/shared`)는 공용 코드만 require한다. 기준은 `tools/tests/check_deps.py`의 `ALLOWED` 표.
- require는 `require(<경로>:WaitForChild("이름"))` 꼴로만 쓴다(의존 검사가 읽을 수 있게).
- 조정할 숫자는 `src/shared/Config.luau`, 이름은 `src/shared/Names.luau`에 둔다.

## 검사 명령

- `python -I tools/tests/run_tests.py` — 납작·연결봉 수학 테스트(luau CLI, 실제 Config 수치) + 의존 방향 검사
- `python -I tools/lint/run_lint.py` — luau-lsp(Roblox API 타입) + selene. luau-lsp·selene·rojo가 PATH에 있어야 한다
  (이 PC: `~/.local/bin`). Roblox 타입 정의는 `.lint/`에 캐시된다(내려받기가 막히면 `Banned words/.lint/`의 파일을 복사).
- Studio 확인: `rojo build default.project.json -o .qa/<이름>.rbxlx`로 만든 장소를 새 Studio 창에서 열고 Play.

`tools/lint/run_lint.py`와 `tools/tests/check_deps.py`는 `Banned words/tools/`에서 복사해 이 게임에 맞춘 것이다
(중복 도구 — 공용 도구 폴더로 합칠지는 오너와 시점을 정한다).
