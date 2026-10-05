# Foundation 실행·검증

이 문서는 구현본의 QA 절차입니다. 원본 설계 문서의 Phase 0 Acceptance는 실제 Studio 및 Published 테스트 결과로 판정합니다. 현재 환경에서는 해당 실행을 확인하지 못했습니다.

## Studio 다중 클라이언트

1. 제공한 `MonCook_Foundation.rbxlx`를 Roblox Studio에서 엽니다. 또는 `default.project.json`을 Rojo로 연결합니다.
2. `ReplicatedStorage.Shared.Config.Definitions.Testing.UseFakeTeleport`가 `true`인지 확인합니다. Studio 저장소는 메모리 안에만 있으며 테스트 종료 후 초기화됩니다.
3. **Server & Clients**에서 2–4개 클라이언트를 시작합니다. Output에 `[MonCook] Foundation services ready; Studio fake transport`가 보이고 UI에 HornboarMeat 5개·Salt 5개가 표시되는지 확인합니다.
4. 호스트가 **만들기**를 누릅니다. ID 입력칸에서 현재 파티 ID를 복사해 다른 클라이언트의 ID 입력칸에 붙이고 **참가**를 누릅니다.
5. 호스트가 **식당 입장 제안**을 누릅니다. 제안 자체로 호스트는 JOIN 처리됩니다. 나머지 멤버는 **JOIN** 또는 **STAY**를 명시적으로 선택합니다. 호스트의 STAY는 거부됩니다.
6. 호스트가 **모든 식재료를 맡기고 입장**을 누릅니다. 응답이 남아 있으면 입장이 거부되어야 합니다. 응답을 마쳤다면 JOIN 멤버만 Restaurant 상태가 되고 STAY 멤버는 World에 남아야 합니다. 호스트 식재료는 0개가 되며 helper 개인 재고는 그대로입니다.
7. 호스트가 **정산 · 월드 복귀**를 누릅니다. 해당 세션의 남아 있는 참가자가 World로 돌아오고 호스트 재고가 각각 5개로 복구되어야 합니다. Gold/Renown은 증가하지 않습니다. 반복 입력으로 재고나 보상을 중복 지급할 수 없어야 합니다.
8. 새 세션에서 helper가 먼저 복귀해도 호스트 세션·재고가 바뀌지 않는지 확인합니다. 별도 5개 클라이언트 테스트에서 5번째 참가 거부, 탈퇴 시 리더 이전, 제안 중 멤버 변경 시 제안 무효화도 확인합니다.
9. 모바일 에뮬레이터의 세로/가로 화면에서 패널 스크롤·버튼·안전 영역을 확인합니다. PC 클릭, Touch, Gamepad 선택/Activated 입력을 각각 확인합니다.

FakeTeleport는 실제 캐릭터를 다른 서버로 옮기지 않습니다. 바닥과 Spawn은 `Foundation_PLACEHOLDER` 테스트 공간입니다. Studio 테스트 프로필은 Published 저장소에 기록하지 않습니다.

## Published 테스트 준비

1. 전용 테스트 Experience 안에 World Place와 Restaurant Place를 만듭니다. World는 최대 20인, Restaurant은 최대 4인으로 설정합니다.
2. `src/server/ServerConfig.luau`의 `WorldPlaceId`와 `RestaurantPlaceId`를 실제 ID로 바꿉니다. World는 시작 Place로 설정합니다. 두 Place에 같은 서버·클라이언트 코드를 배치합니다.
3. 테스트 Experience에만 게시합니다. Published 실행은 `RunService:IsStudio()` 검사로 FakeTeleport를 사용할 수 없으며, Restaurant은 Reserved Server 입장만 허용합니다.
4. 테스트용 `ProfileStoreName`·`SessionMapName`을 사용합니다. Published 새 프로필의 식재료는 0개입니다. 양수 escrow의 영속성 검증에는 전용 테스트 계정의 통제된 서버 데이터 fixture가 필요합니다. Studio seed가 Published 계정에 적용된 것으로 간주하지 않습니다.

## Published 필수 판정

- 실제 Roblox 클라이언트에서 1인 파티를 만들고 **식당 입장 제안**(호스트 자동 JOIN) 후 Restaurant에 입장합니다. Reserved Server로 이동하고 World로 복귀해야 합니다.
- 이동 전·Restaurant·World 복귀·재접속 후 프로필을 비교합니다. Gold/Renown 유지, 맡긴 재고의 정확한 반환, 세션 Closed와 SessionId별 정산 영수증을 확인합니다.
- 입장/복귀 중 연결 끊김, 서버 종료, 예약/전송 실패, `TeleportInitFailed`를 확인합니다. 잠금 소유권을 얻은 서버만 데이터를 바꾸고 기존 저장 실패를 새 프로필로 덮어쓰지 않아야 합니다.
- 초기 전송 실패 또는 World 재접속에서 준비 중 escrow가 복구되어야 합니다. Active 세션의 호스트가 World에서 프로필 잠금을 다시 얻으면 Phase 0의 0보상 정산으로 남은 재고를 회수합니다.
- 같은 정산 반복, 늦은 이전 이동 실패, 다른 SessionId와 이동 방향을 주입해 현재 세션이 취소되거나 중복 지급되지 않는지 확인합니다. 오류는 서버 Output/로그에 남아야 합니다.
- 공개 2–4인 왕복, 호스트 재접속 유예·helper 보상은 Phase 6의 후속 확장 항목입니다. 현 골격의 동시 helper 복귀도 Studio에서 먼저 확인합니다.

정산을 확장하기 전에 실제 조리 소비·주문·판매 장부를 연결해야 합니다. 현재 0보상 반환을 완성된 식당 경제로 판정하지 않습니다.

## 로직 테스트와 판정 기록

```sh
python tools/run_foundation_tests.py
```

Luau 0.741의 문법 컴파일·순수 모듈 strict 분석 및 66개 그룹을 확인했습니다. DataStore/MemoryStore/Teleport API, Roblox 런타임 타입, 화면 및 Published 성공은 별도로 검증해야 합니다. 실행 날짜, Place ID, 계정/클라이언트 수, 통과·실패, Output 근거를 [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)의 미검증 항목에 추가한 뒤 다음 Phase로 진행합니다.
