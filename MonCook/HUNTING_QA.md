# Phase 1 Studio QA — 미실행 체크리스트

최신 판정·애니메이션·재설계 모델의 실행 조건/acceptance는 [CORRECTION_QA.md](CORRECTION_QA.md)를 먼저 확인합니다.

이 환경에서는 Roblox Studio에 연결하지 못했습니다. 아래는 실제 실행 결과가 아니라 판정 절차입니다. 자동 테스트 288개 그룹/빌드 검증과 Studio 판정을 분리해 기록합니다. Phase 1 acceptance는 이 체크리스트가 통과한 뒤 판정합니다.

## 준비

1. `MonCook_Phase_1_Hunting.rbxlx`를 열고 Test → **Server & Clients 2명**, 이후 4명으로 실행합니다. Output에 Foundation과 Shared Greenwood runtime 준비 메시지가 나오고 오류가 없어야 합니다.
2. `Testing.ShowFoundationDebugUI`는 기본 false로 둡니다. 필요할 때만 true로 바꿔 Foundation QA를 진행합니다. 사냥 UI·보상은 해당 플래그와 독립적입니다.
3. 시작 가방에는 Studio 테스트 seed인 HornboarMeat 5개·Salt 5개가 있습니다. 각 클라이언트의 시작 수량을 기록합니다. Studio Stop은 메모리 저장소를 초기화하므로 영구 DataStore 검증으로 판정하지 않습니다.
4. World에서 표지판 방향으로 이동합니다. 현재 Hornboar 슬롯은 2개, 사망 후 despawn 2.2초/respawn 7초 설정입니다. 정확한 현재 값은 `HuntingConfig`를 확인합니다. 밸런스는 TODO_BALANCE입니다.

## 필수 플레이 15항목

| # | 조작 | 통과 기준 |
| --- | --- | --- |
| 1 | 몬스터에서 떨어져 관찰 | Idle/Roam과 걷기 자세가 구분되고 지면 위에 유지 |
| 2 | 플레이어 접근 | Alert → Chase가 읽히고 무기/HP 표시 정상 |
| 3 | 중거리에서 돌진 유도 | Windup 방향 고정, 바닥 예고 + `! 돌진 준비` 후 Charge/Recover; 예고 중 측면 이동으로 회피 가능 |
| 4 | M1을 공격 종료마다 연속 입력 | 1→2→3 스윙/서버 combo, 지연하면 1로 reset; 연타 spam 중 무제한 피해 없음 |
| 5 | Q 강공 | 일반보다 느린 스윙, 높은 뿔 피해, 공격 window와 시각 일치 |
| 6 | 이동하며 F 회피 | 짧은 서버 이동, cooldown, 벽/바위·낭떠러지 clamp; stamina/i-frame 의존 없음 |
| 7 | 정면 뿔과 측면 몸통 각각 공격 | 별도 Horn HP 감소, 측면 Body 판정; 시각상 먼 공격/장애물 뒤 타격은 거절 |
| 8 | 뿔을 두 번 강공으로 타격 | 설정상 뿔 파괴 가능, intact 숨김/stump 표시, VFX/텍스트, Horn hitbox 비활성; 몸통 생존 가능 |
| 9 | 계속 공격하여 처치 | Dead 자세 → despawn, 한 번만 사망; 사체 반복 공격으로 피해/보상 재지급 없음 |
| 10 | 처치 후 개인 알림 확인 | Meat 보장, Fat/Loin 독립 확률, Gold 불변; 연출은 해당 클라이언트 개인용 |
| 11 | I 가방 열기 | Ingredients/Materials 분리, 이름/아이콘/수량, 시작 대비 Meat 증가·HornCore는 Materials |
| 12 | 사망 후 대기 | 설정 지연 뒤 새 EncounterId로 재생성, HP/뿔 복구, MaxAlive 2 유지 |
| 13 | 파티 없이 2명 같은 개체 공격 | 두 플레이어 모두 기여, 한 플레이어가 마지막 타격해도 독점 없음 |
| 14 | 두 클라이언트 가방/알림 비교 | 기여자별 Meat·개별 roll 지급, 비기여자는 지급 없음; 뿔 파괴 이후 처음 기여한 사람은 이전 Core를 소급 획득하지 않음 |
| 15 | Device Emulator Touch | 공격/강공/회피 버튼 실제 동작, 이동 방향 회피, 근처 정면 target assist; 자동 공격 없음 |

## 입력·화면·Foundation 회귀

- PC: M1/Q/F/I. Space 점프·Shift Lock 유지. Chat/TextBox 입력, Party 버튼, Roblox Menu 조작 중 공격하지 않음.
- Touch: 세로/가로, 작은 창, 태블릿. 이동 thumbstick/점프 버튼과 공격 버튼의 겹침·44px 이상 터치 크기·Safe Area·텍스트/가방 scroll 확인.
- Gamepad: R2 Basic / X Heavy / B Dodge / A 기본 점프. 선택된 GUI와 전투 입력 충돌, Roblox Menu 확인. Gamepad UI 상세 탐색은 V1 후속 polish 대상.
- PC/작은 창/모바일에서 Party HUD·Finder·Chat·PlayerList·TopBar 겹침 확인. 파티 HUD를 의도적으로 수동 이동한 겹침은 기존 정상 계약입니다.
- [FOUNDATION_QA.md](FOUNDATION_QA.md)의 Public/Private·Finder·ReadyCheck·FakeTeleport·Restaurant 흐름 유지. 원정/Restaurant 위치 및 traveling 상태에서 사냥 입력/데미지 차단, World 복귀 시 재개.
- 캐릭터 사망/리스폰 후 무기 재부착·서버 sequence/cooldown 일관성, 4인 동시 사냥, 클라이언트 종료 직전 보상 flush 및 로그 확인.

## 보안·저장·실패

자동 테스트는 malformed/duplicate/먼 거리/쿨다운/죽은 대상/미장착/기여도/저장 실패와 ack 유실을 다룹니다. Studio에서는 별도 QA place에서만 잘못된 intent를 보내고 서버가 피해·보상을 만들지 않는지 확인합니다. Release UI에는 reward/grant/roll remote가 없습니다.

Published 검증은 Experience의 기존 World/Restaurant 설정과 API 허용을 연결한 QA place에서 진행합니다. 재접속 전후 Inventory/첫 AnalyticsFlags/HuntingReceipts를 확인하고, DataStore 실패 시 성공한 저장만 알림·수량으로 보이는지 확인합니다. 실제 실패/프로필 lock 충돌은 안전한 QA 저장소에서 재현합니다. Receipt 보존 3,600초는 보상 retry 600초보다 길며 만료분만 이후 성공한 grant에서 정리합니다.

보상 대기열은 서버 메모리입니다. 정상 종료에는 최대 5초 flush를 시도하지만 저장 장애·종료 timeout·프로세스 강제 종료에 미확정 보상이 남을 수 있습니다. 성공한 지급은 receipt로 중복을 막습니다. 이 차이를 결과에 기록합니다.

## Art / animation

- Hornboar/Cleaver를 Close·Medium·Far와 R6/R15 캐릭터 옆에서 확인: 뿔·넓은 어깨·낮은 중심·Cleaver 실루엣, 밝은 판타지 색, 고어 없음.
- Idle/Walk/Run/Alert/Windup/Charge/Headbutt/HitReact/Stagger/Death가 구분되고 2–4개 클라이언트에서 서버 상태와 일치.
- 정상 뿔 → 별도 HP 감소 → intact 숨김 → stump → Core 개인 연출. Body/Horn hitbox는 시각과 별개이며 파괴 후 horn query가 꺼짐.
- 서버의 `HIT_Hornboar_Body`/`HIT_Hornboar_Horn` 투명도를 QA용으로만 잠시 낮춰 돌진/머리치기/스윙 판정과 시각 차이를 측정. 결과와 설정 보정 필요 여부 기록.
- 재료 pop/move/fade는 지급 성공 뒤 개인 cosmetic만 발생하고 다른 사람이 주워갈 수 없음. 희귀/부위 알림은 아이콘+텍스트로 구분.
- Streaming 재등장, 모바일 frame time/메모리, native Part 수, 벽에 막힌 AI, 장시간 respawn 확인.
- FBX 소스는 13 actions로 보강했습니다. 현재 Hornboar visual은 Blender topology 기반 EditableMesh MeshParts + procedural Motor6D poses이며, API 실행 조건은 CORRECTION_QA를 따릅니다. Blender 메시/AnimationId 업로드와 실제 재생은 별도 미검증입니다. Custom SFX도 아직 placeholder입니다.

## 결과 기록

테스트 날짜, Studio 버전, PC/모바일 크기, R6/R15, 클라이언트 수, 15항목별 PASS/FAIL, Output 오류, 재접속 수량, 뿔/공격 판정 영상·스크린샷, 성능 수치를 기록합니다. 실패가 있으면 Phase 1 acceptance를 보류하고 해당 범위만 수정합니다. Phase 2 콘텐츠로 진행하지 않습니다.
