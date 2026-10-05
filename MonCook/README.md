# MonCook — The Last Recipe

Roblox Studio / Luau 프로젝트입니다. 여러 게임을 보관하는 `Gameproject1`에서 MonCook의 문서와 코드는 이 폴더에 모읍니다.

설계는 [CODEX_START_HERE.md](docs/LastRecipe_Codex_Design/CODEX_START_HERE.md)부터 읽습니다. 첨부 ZIP의 문서 21개를 원본 그대로 보존했습니다. 구현 기준은 분리 문서이며 통합본은 전달용입니다.

## 현재 구현

Phase 0 Foundation 0.1–0.7의 코드와 테스트를 준비했습니다.

- Config Registry, PlayerData 기본값과 migration
- DataService의 원자적 저장, 서버 간 프로필 잠금과 heartbeat
- 최대 4인 파티와 명시적인 JOIN/STAY 응답
- SessionId, 식재료 escrow, 세션 상태 전이와 중복 정산 방지
- Studio FakeTeleport와 Published Reserved Restaurant 텔레포트 래퍼
- 서버 요청 검증과 PC/Touch/Gamepad용 파티·입장·복귀 UI

현재 정산은 **Gold/Renown을 지급하지 않고 맡긴 식재료를 전부 돌려주는 Foundation 골격**입니다. 사냥·조리·주문·판매는 다음 단계입니다. Studio 다중 클라이언트 및 Published 왕복 QA를 통과하기 전까지 Foundation 전체 완료로 판정하지 않습니다.

```text
docs/LastRecipe_Codex_Design/  설계 원본
src/shared/                  Config·타입·기본값·migration
src/server/Services/         저장·파티·세션·이동 서비스
src/server/Adapters/         Roblox API / Studio 테스트 저장소
src/server/ServerConfig.luau 실제 Place ID·저장소·런타임 설정
src/client/Controllers/      파티·입장·복귀 UI
tests/                       순수 로직과 실패·동시 요청 테스트
tools/                       검증 및 PC 복사 스크립트
```

## Studio에서 확인

제공한 `MonCook_Foundation.rbxlx`를 Studio에서 열고 **Server & Clients**로 2–4개 클라이언트를 시작합니다. Studio는 메모리 저장소와 FakeTeleport를 사용하며 플레이어마다 HornboarMeat 5개·Salt 5개를 테스트용으로 줍니다. FakeTeleport는 같은 테스트 서버에서 위치 상태만 바꾸므로 실제 Place 이동과 영속 저장은 Published QA에서 확인합니다.

Rojo를 설치한 경우 이 폴더에서 빌드하거나 Studio에 동기화할 수 있습니다.

```sh
rojo build default.project.json -o MonCook_Foundation.rbxlx
rojo serve default.project.json
```

Published 테스트에는 같은 Experience의 World/Restaurant Place ID를 `src/server/ServerConfig.luau`에 넣고 두 Place에 같은 코드를 배치해야 합니다. 현재 ID는 `0`이며 Studio에서만 사용할 수 있습니다. 자세한 순서와 판정 기준은 [Foundation QA](FOUNDATION_QA.md)를 따릅니다.

## 로직 검증

공식 Luau CLI가 PATH에 있는 환경에서 실행합니다.

```sh
python tools/run_foundation_tests.py
```

원본 Luau의 문법을 컴파일하고, 임시 사본의 require 경로를 CLI용으로 변환해 순수 모듈의 strict 타입 검사와 테스트를 실행합니다. Roblox API 호출·UI·실제 텔레포트는 이 검증에 포함되지 않습니다. 결과와 남은 작업은 [작업 상태](IMPLEMENTATION_STATUS.md)에 기록했습니다.

## Windows PC 보관

전체 소스 ZIP을 임시 폴더에 풀고 [프로젝트 설치 안내](tools/LOCAL_PROJECT_INSTALL.md)를 실행하면 다음 두 위치에 소스·문서·테스트를 복사합니다.

- `C:\smallsize\wak\MonCook`
- `C:\smallsize\wak\MonCook_LocalRepository\MonCook`

변경된 기존 파일은 백업하고 추가 파일은 보존합니다. 이 클라우드 환경에서는 PC의 `C:` 드라이브에 직접 복사할 수 없으므로 PC에서 설치 스크립트를 실행해야 합니다. 문서만 복사하는 [기존 안내](tools/LOCAL_INSTALL.md)도 포함했습니다.
