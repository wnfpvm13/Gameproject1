# Phase 1 Correction — Combat Hitbox & Attack Range

2026-10-06 사용자 요청의 구현 기준 요약입니다. 대화의 원문 지시가 이 요약보다 우선합니다. [첨부 애니메이션/Hornboar 재설계 지침](PHASE_1_CORRECTION_Animation_Hornboar_Redesign.md)도 함께 적용합니다.

1. Body box는 몸통 대부분·어깨·목·다리 사이 공간을 포함하며 visual보다 약간 관대한 판정을 허용합니다. 첫 일반 몬스터에 pixel-perfect 접촉을 요구하지 않습니다.
2. Horn은 별도 part HP/box를 유지하고 뿌리와 앞부분을 넉넉히 포함합니다. 정면/대각선 Heavy로 노릴 수 있어야 하며, 유효한 Body/Horn overlap에는 Horn을 우선합니다. 파괴 즉시 horn query를 끕니다.
3. Cleaver는 점/얇은 ray 대신 전방 arc / swept box / capsule 영역을 사용합니다. Heavy는 Basic보다 길고 넓으며 PartBreakPower가 높습니다.
4. 초기 Basic reach 5–6 studs / arc 80–100도, Heavy 6–7 / 90–110도. Config와 TODO_BALANCE로 분리하고 실제 Avatar/Cleaver 모션과 Studio에서 조정합니다.
5. 무기의 최대 전진 시점과 서버 hit window를 맞춥니다. 명백한 관통 miss·무기가 닿기 전 damage·뒤쪽 몬스터·범위 밖 타격을 막습니다. visual 접촉보다 약간의 관대한 game box는 허용합니다.
6. 일정 거리/플레이어 전방/화면에서 자연스러운 가까운 target에 약한 facing assist만 사용합니다. 강한 lock-on/순간 회전/자동 공격은 추가하지 않습니다.
7. 확정 Body hit는 작은 spark/sound/flinch, Horn hit는 다른 색·모양 spark/단단한 소리/head recoil, Heavy는 강한 효과/recoil. Miss에는 hit effect가 없습니다. 고어/과도한 화면 흔들림은 금지합니다.
8. `Testing.ShowCombatHitboxes`를 Studio QA에서만 사용합니다. 기본 false, Release 강제 비표시. Player Basic/Heavy 영역과 Body/Horn box를 명확히 다른 색으로 표시합니다.
9. 실제 Studio에서 중앙/어깨/옆구리/정면 Horn/대각선 Horn/뿔 옆 Body/최대 거리/그 바깥/약간 옆/뒤를 보고 공격/Basic1·2·3/Heavy를 확인합니다. 명백한 접촉 대부분이 hit이고 Body/Horn 차이를 이해할 수 있어야 합니다.
10. 서버 권한 damage·contribution·Personal Loot·Core 1회·death receipt·Inventory·multiplayer·거리 보안 계약을 유지합니다. 수정의 실제 acceptance 전 Phase 1 완료를 선언하지 않습니다. 새 Studio 파일을 제공하고 멈춥니다. 전체 소스 PC ZIP은 생성하지 않습니다.
