# Foundation / Phase 0.8 실행·검증

사용자는 기존 Phase 0.8 파티 기능이 Studio에서 정상 동작한다고 확인했습니다. 이번 UI Polish의 화면·입력은 이 환경에서 Studio를 실행하지 못해 미검증입니다. 아래 수동 판정을 별도로 기록합니다. 기존 기능 QA 절차도 보존합니다.

## UI Polish 수동 판정

1. 최신 `MonCook_Phase_0_8_UI_Polish.rbxlx`로 시작하고 Debug 기본 false를 확인합니다. 밝은 텍스트·반투명 웜브라운 배경 뒤에 게임 화면이 보이는지 확인합니다.
2. 공개 Finder 카드가 낮은 두 줄 형태이며 모집 상태 오른쪽에 44px 이상의 참가 버튼이 있는지 확인합니다. 긴 한국어/영문 이름·목표, 만원·활동 중·현재 파티 소속의 비활성 상태를 확인합니다.
3. PC Hover는 밝아지고 Pressed는 진해지며 밖에서 놓기/창 포커스 이탈 후 복구되어야 합니다. Disabled는 구별되고 클릭해도 동작하지 않아야 합니다. Touch와 Gamepad 선택/누름도 확인합니다.
4. 접힌 HUD가 최대 4명 세로 얼굴 스택인지, 좁은 화면에서 가로폭이 줄고 펼치기 44px 버튼이 명확한지 확인합니다. 공간이 부족하면 멤버 영역을 세로 스크롤합니다.
5. 상단 손잡이로 PC 마우스/Touch 드래그를 합니다. 참가·펼치기·응답 버튼과 충돌하지 않으며 밖에서 놓아도 드래그가 끝나야 합니다. 화면 네 모서리, 확대/축소, 세로/가로 전환 후 Safe Area 안으로 보정되어야 합니다. 위치는 현재 클라이언트 세션에서만 유지합니다.
6. 펼친 HUD에서 멤버 얼굴·왕관·공개 여부·목표·초대·탈퇴·Finder를 확인합니다. Ready 아이콘과 텍스트, `3 / 4명 이동 준비`가 밝은 배경과 어두운 배경 모두에서 읽혀야 합니다.
7. 일반 PC, 작은 창, 모바일 세로/가로, 20인 PlayerList를 확인합니다. Chat 창/입력창과 TopBar·Roblox Menu를 열고 닫거나 크기를 바꾸며 HUD 겹침을 확인합니다. PlayerList 실제 bounds는 공개 API가 없어 추정 회피/좁은 화면 정책에 대한 실제 판정이 필수입니다.
8. 기존 Public/Private·초대·JOIN/STAY·Fake 원정·식당 기능이 그대로인지 확인합니다. Debug true로 재시작하면 별도 큰 패널이 보이고 Published에서는 숨겨져야 합니다.

## Studio 파티 UX

1. `MonCook_Phase_0_8_UI_Polish.rbxlx`를 열거나 `default.project.json`을 Rojo로 연결합니다. `Testing.UseFakeTeleport = true`, `Testing.ShowFoundationDebugUI = false`로 시작합니다.
2. **Server & Clients**에서 2–4개 클라이언트를 시작합니다. 서버 준비 로그와 우측 상단 파티 HUD가 보이고 큰 Debug UI와 Party ID 입력칸은 숨겨져야 합니다. 기본 seed는 HornboarMeat 5개·Salt 5개입니다.
3. 호스트가 공개 파티를 만듭니다. 다른 클라이언트의 Finder에 Activity·Target·호스트·인원/4 카드가 보이고 참가 버튼으로 가입되어야 합니다. 5개 클라이언트로 최대 4인 제한을 확인합니다.
4. 공개/비공개를 바꿉니다. 비공개는 Finder에서 사라져야 합니다. 같은 서버 플레이어에게 초대하고 수락/거절·만료·중복·정원 초과를 확인합니다. 오래된 초대나 다른 사용자의 초대는 사용할 수 없어야 합니다.
5. 얼굴·짧은 이름·리더 왕관·접기/펼치기·멤버 표시를 확인합니다. 탈퇴하면 리더가 이전되고 진행 중 동의 확인은 무효화되어야 합니다.
6. 식당 목표를 선택하고 이동을 제안합니다. 호스트는 함께 이동 상태이며 다른 멤버는 응답 중입니다. 응답 후 함께 이동 / 이번엔 남음과 `3/4명 이동 준비` 같은 인원 요약이 정확해야 합니다. 응답이 남아 있으면 출발을 거부해야 합니다.
7. 함께 이동한 멤버만 Restaurant 상태가 되고 STAY 멤버는 World에 남아야 합니다. 호스트 seed 재고는 escrow에 맡겨지고 helper 개인 재고는 유지됩니다. 정산·복귀 후 호스트 재고가 정확히 돌아오며 Gold/Renown은 증가하지 않아야 합니다. helper 선행 복귀와 반복 요청도 확인합니다.
8. 호스트 이탈 후 World의 STAY 멤버가 탈퇴·새 동의 확인을 할 수 있어야 합니다. 이동 중인 참가자가 남아 있으면 활동 상태를 임의로 해제하지 않아야 합니다.
9. PC 마우스, Touch, Gamepad로 선택·Activated 입력을 확인합니다. 작은 세로/가로 화면, 20인 PlayerList, 채팅 창/입력창, Roblox 메뉴, 화면 크기 변경에서 HUD 접근과 스크롤·안전 영역을 확인합니다. 공개 PlayerList bounds API가 없어 예약 영역을 사용하므로 실제 화면 확인이 필요합니다.
10. 테스트를 종료하고 `ShowFoundationDebugUI = true`로 재시작합니다. 기존 큰 패널·Party ID 입력·식당 테스트가 Studio에서만 보여야 합니다. 검증 후 기본값을 `false`로 되돌립니다.

FakeTeleport는 캐릭터를 다른 서버로 옮기지 않습니다. 바닥·Spawn은 테스트 공간이며 Studio 프로필은 Published 저장소에 기록하지 않습니다.

## Studio Expedition

1. 원정 목표를 선택해 동의 확인을 시작합니다. 함께 이동한 멤버만 Expedition에 포함되고 STAY 멤버는 World에 남아야 합니다. 변경된 목표나 이전 제안으로 출발할 수 없어야 합니다.
2. 준비·전송·활동 상태를 확인하고 호스트의 원정 결과 버튼으로 Result 상태를 만듭니다. 이는 Fake 테스트이며 전투·드롭·경제 보상을 만들지 않습니다.
3. 호스트가 Repeat를 선택합니다. 기존 세션이 닫히고 World에서 같은 목표의 **새 JOIN/STAY 동의 확인**이 보여야 합니다. helper를 자동으로 다시 출발시키지 않아야 합니다.
4. 새 원정에서 HostRestaurant을 선택합니다. World에서 식당 목표의 새 동의 확인 후 함께 이동한 멤버만 기존 Restaurant 골격으로 입장해야 합니다. Hearthcross는 새 이동 제안 없이 World로 복귀해야 합니다.
5. helper의 결과 선택, 다른 SessionId, 이전 ActionId·목적지 충돌을 거부해야 합니다. 같은 완료 요청은 전송·보상·새 제안을 중복 생성하지 않아야 합니다.
6. 예약/전송 실패와 호스트 이탈을 확인합니다. 실패한 결과 이동은 Result로 복구하고 재시도는 새 ActionId를 사용합니다. 이전 작업이 늦게 끝나도 새 활동·동의 확인·프로필 잠금을 바꾸지 않아야 합니다.

Quick Match는 사용 불가 인터페이스만 있습니다. 서버 간 검색·매칭·MemoryStoreQueue는 이번 범위에 포함하지 않습니다.

## Published Restaurant 준비·판정

1. 전용 테스트 Experience에 World(최대 20인)와 Restaurant(최대 4인)을 만듭니다. `WorldPlaceId`와 `RestaurantPlaceId`를 설정하고 같은 코드를 배치합니다. Restaurant은 Reserved Server만 허용합니다.
2. 테스트용 `ProfileStoreName`·`SessionMapName`을 사용합니다. Published 새 프로필 재고는 0개이며 양수 escrow 검증에는 통제된 서버 데이터 fixture가 필요합니다.
3. Published에서 큰 Debug UI·원정 시작이 차단되고 공개 Finder/비공개 초대가 현재 World 서버 안에서만 동작하는지 확인합니다.
4. 식당 예약 서버 왕복과 Restaurant HUD 멤버 표시를 확인합니다. 이동 전·도착·복귀·재접속 후 프로필을 비교해 Gold/Renown 유지, 정확한 재고 반환, Closed 세션과 정산 영수증을 확인합니다.
5. 예약/전송 실패·`TeleportInitFailed`·이동 중 연결 끊김·서버 종료를 확인합니다. 현재 잠금 소유 서버만 데이터를 바꾸며 저장 오류를 새 프로필로 덮어쓰지 않아야 합니다.
6. 준비 중 escrow 복구, World 재접속 시 0보상 회수, 늦은 이전 이동 실패 무시, 반복 정산과 helper 동시 복귀를 확인합니다. 실제 다인 Published 왕복·호스트 재접속 유예·helper 보상 확장은 후속 범위입니다.

Published Expedition은 진입을 차단합니다. 지역별 Place 연결, 서버 간 세션 저장·도착 import·복구 계약과 실제 콘텐츠를 먼저 구현해야 합니다.

## 로직 검증 기록

```sh
python tools/run_foundation_tests.py
```

공식 Luau 0.741로 43개 파일 문법 컴파일·순수 모듈 strict 분석과 기존 141개를 포함한 169개 테스트 그룹을 확인했습니다. 이는 Roblox 엔진 실행 결과가 아닙니다. 실제 QA 날짜·Place ID·클라이언트 수·Output 근거와 판정을 [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)에 추가합니다.
