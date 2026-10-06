# CODEX RULES

이 문서는 구현 규칙이다. 위반하지 않는다.

## 1. 범위
요청된 기능만 구현한다.
대규모 신규 시스템 임의 추가 금지.

## 2. main
`main` 직접 수정 금지.
Feature branch에서 작업.

## 3. Docs
작업 전 반드시:
- MASTER_GDD
- CODEX_RULES
- TECH_ARCHITECTURE
- DATA_SCHEMA
- 관련 Bible
읽기.

## 4. Server Authority
클라이언트 값을 신뢰하지 않는다.

Server authoritative:
- Damage
- Drops
- Inventory
- Gold
- Renown
- Cooking consumption
- Sale
- Recruitment
- Enhancement
- Session settlement
- Blessings

## 5. Config
밸런스 숫자를 서비스 코드에 하드코딩하지 않는다.
Config 사용.

테스트 임시값:
`TODO_BALANCE` 주석.

## 6. Data
SchemaVersion 필수.
Migration 준비.
기존 데이터 파괴 변경 금지.

## 7. Session
Restaurant 경제 처리는 SessionId 기반.
Settlement는 idempotent.
Pantry escrow 필수.

## 8. 모바일
모바일에서 사용할 수 없는 기능은 완료로 간주하지 않는다.

PC/Touch/Gamepad input abstraction.

## 9. UI
화면 전체를 UI로 덮지 않는다.
Mobile safe area 고려.
기능 해금 전 복잡한 UI 노출 금지.

## 10. Performance
- 모든 NPC Humanoid 사용 금지
- unnecessary pathfinding 금지
- reusable mesh/package
- streaming 고려
- monster budget
- restaurant focus/background simulation

## 11. 기존 파일
기존 시스템을 이유 없이 삭제/대체하지 않는다.
공통 API 변경 시 관련 브랜치 영향 기록.

## 12. 테스트
각 작업 완료 시:
- unit-like logic tests 가능 범위
- server/client test
- mobile emulator
- edge cases
- reconnect/failure cases
를 보고.

## 13. 완료 보고 형식
반드시:
1. 구현 내용
2. 변경 파일
3. 테스트 결과
4. 실패/미검증 항목
5. TODO
6. 다른 브랜치 영향
을 보고.

## 14. 숨기지 말 것
컴파일/런타임 실패, 미검증, TODO를 숨기지 않는다.

## 15. Art placeholders
최종 모델을 기다리며 로직 개발을 막지 않는다.
`*_PLACEHOLDER` Greybox 사용.
Package 교체 가능한 구조 유지.
