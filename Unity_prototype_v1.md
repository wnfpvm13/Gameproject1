# Unity 프로토타입 기술 설계서 v1

- 문서 버전: v1
- 기준일: 2026-09-18
- 대상 프로젝트: 아르데니아 / 라스트라 자율 용병단 시뮬레이션
- 목적: Codex와 Unity를 이용해 1차 프로토타입을 구현하기 위한 기술 기준을 고정한다.
- 우선순위: **재미 검증 > 확장성 > 그래픽 완성도**
- 핵심 원칙: **시뮬레이션 로직과 화면 표현을 분리하고, 밸런스 수치를 코드에 하드코딩하지 않는다.**

---

# 1. 기술 목표

이 프로젝트는 모바일 가로형 2D 픽셀아트 게임이다.

플레이어가 용병을 직접 조종하지 않고 다음을 통해 간접적으로 영향을 준다.

- 시설 건설과 배치
- 장비와 선물
- 의뢰와 원정 방침
- 휴식/방어/우선 의뢰 등 지침
- 마을 환경과 동선
- 관계와 지원

따라서 기술적으로 가장 중요한 것은 다음 네 가지다.

1. **자율 AI가 안정적으로 행동할 것**
2. **AI가 왜 그렇게 행동했는지 설명할 수 있을 것**
3. **맵·건물·몬스터·장비·스킬을 Unity Editor에서 코드 없이 수정할 수 있을 것**
4. **장기 저장 데이터가 시스템 확장 후에도 깨지지 않을 것**

---

# 2. 기본 기술 스택

## 2.1 엔진

- Unity 6 LTS 계열 사용
- 실제 프로젝트 생성 시 설치 가능한 최신 안정 LTS를 확인한 뒤 버전을 고정
- 중간에 임의로 Unity 버전을 올리지 않는다.
- 플랫폼: Android 우선
- iOS는 구조적으로 대응 가능하게 만들되 1차 프로토타입 빌드 대상에서는 제외
- 화면 방향: Landscape

## 2.2 언어

- C#

## 2.3 Codex

**Unity 공식 Codex Plugin 사용을 필수 개발 환경으로 한다.**

원칙:

- Codex는 작업 시작 전 프로젝트 구조를 먼저 확인한다.
- Unity 관련 작업은 공식 Unity 스킬을 우선 활용한다.
- 패키지/프로젝트 생성/검증에는 Unity CLI 사용을 허용한다.
- 플러그인은 게임 런타임 의존성이 아니다.
- 게임 기능은 플러그인이 없어도 정상 실행되어야 한다.
- Codex가 코드를 수정한 뒤 반드시 컴파일 오류와 테스트 결과를 확인한다.

## 2.4 추천 Unity 패키지

프로토타입 기본:

- 2D Tilemap Editor
- 2D Tilemap Extras
- 2D Pixel Perfect
- Input System
- Test Framework
- Cinemachine
- Android Logcat

검토:

- 2D URP / 2D Renderer
- Unity Behavior
- AI Navigation

원칙:

- 필요한 기능이 없는 상태에서 Asset Store 패키지를 무분별하게 추가하지 않는다.
- 길찾기는 우선 커스텀 Grid A*를 사용한다.
- Unity AI Navigation은 비교 테스트 후 대체 가치가 있을 때만 도입한다.
- Odin Inspector 등 유료 에디터 확장은 기본 Inspector가 불편해진 이후 검토한다.

---

# 3. 렌더링 / 픽셀아트 기준

## 3.1 카메라

- 탑다운 Orthogonal
- 모바일 가로 화면
- 카메라 드래그 이동
- 핀치 줌
- 특정 용병/이벤트 추적 기능
- 중요 이벤트 발생 시 카메라 바로가기 제공

## 3.2 픽셀 기준

초안:

- 타일 기준: 32×32 px
- Pixels Per Unit: 32
- 캐릭터 실제 크기는 아트 테스트 후 결정
- 픽셀 퍼펙트 카메라 적용
- 픽셀 스프라이트 Filter Mode는 Point 중심
- 아트 제작 전 최종 PPU 변경 가능

## 3.3 Sorting

권장:

- Ground
- Road
- GroundDecoration
- BuildingBase
- Character
- BuildingTop / AboveCharacter
- Effects
- UI World Marker

캐릭터와 일부 오브젝트는 Y 좌표 기반 Sorting을 사용한다.

건물은 하단/상단 레이어를 나눌 수 있게 제작한다.

---

# 4. 프로젝트 폴더 구조

```text
Assets/
├─ _Project/
│  ├─ Art/
│  │  ├─ Characters/
│  │  ├─ Monsters/
│  │  ├─ Buildings/
│  │  ├─ Tiles/
│  │  ├─ UI/
│  │  └─ VFX/
│  ├─ Audio/
│  ├─ Data/
│  │  ├─ Races/
│  │  ├─ Classes/
│  │  ├─ Personalities/
│  │  ├─ Traits/
│  │  ├─ Skills/
│  │  ├─ Weapons/
│  │  ├─ Equipment/
│  │  ├─ Monsters/
│  │  ├─ Buildings/
│  │  ├─ Contracts/
│  │  ├─ Regions/
│  │  └─ Balance/
│  ├─ Prefabs/
│  │  ├─ Characters/
│  │  ├─ Monsters/
│  │  ├─ Buildings/
│  │  ├─ Props/
│  │  ├─ UI/
│  │  └─ Debug/
│  ├─ Scenes/
│  │  ├─ Bootstrap/
│  │  ├─ Town/
│  │  ├─ World/
│  │  ├─ Combat/
│  │  ├─ Dungeon/
│  │  └─ Test/
│  ├─ Scripts/
│  │  ├─ Core/
│  │  ├─ Simulation/
│  │  ├─ Time/
│  │  ├─ Characters/
│  │  ├─ AI/
│  │  ├─ Relationships/
│  │  ├─ Buildings/
│  │  ├─ Pathfinding/
│  │  ├─ Contracts/
│  │  ├─ Expedition/
│  │  ├─ Combat/
│  │  ├─ Economy/
│  │  ├─ Save/
│  │  ├─ UI/
│  │  └─ Debug/
│  ├─ Editor/
│  └─ Tests/
│     ├─ EditMode/
│     └─ PlayMode/
└─ ThirdParty/
```

프로젝트 고유 파일은 `_Project` 아래에 배치해 Unity 기본/외부 패키지와 구분한다.

---

# 5. 아키텍처 원칙

## 5.1 정의 데이터와 런타임 상태 분리

### Definition
변하지 않는 게임 정의.

예:

- 직업
- 스킬
- 무기
- 몬스터 종류
- 건물 종류
- 성격
- 특성
- 지역
- 의뢰 템플릿

`ScriptableObject` 중심으로 관리한다.

### State
플레이 중 계속 변하는 데이터.

예:

- 레나의 현재 HP
- 피로도
- 관계
- 장비
- 현재 위치
- 현재 행동
- 건물 실제 위치
- 의뢰 진행도
- Gold
- 세계 날짜

일반 직렬화 가능한 C# 데이터로 관리한다.

**ScriptableObject에 세이브 상태를 저장하지 않는다.**

---

# 6. 주요 데이터 구조

아래는 논리 구조이며 클래스명은 구현 중 변경 가능하다.

## 6.1 Definition

```text
RaceDefinition
ClassDefinition
PersonalityDefinition
TraitDefinition
SkillDefinition
WeaponDefinition
EquipmentDefinition
MonsterDefinition
BuildingDefinition
ContractTemplate
RegionDefinition
StatusEffectDefinition
```

각 Definition은 안정적인 ID를 가진다.

예:

```text
building.hospital
monster.goblin_raider
skill.warrior.heavy_strike
trait.combat_genius
```

표시 이름을 Save Key로 사용하지 않는다.

## 6.2 MercenaryState

```text
Id
Name
RaceId
ClassId
BirthStar
CurrentStar
Level
Experience
Stats
PotentialData
MasteryData
PersonalityIds
TraitIds
SkillStates
EquipmentState
Needs
Condition
InjuryState
SoulState
Age
ReligionId
OriginData
FamilyData
PastData
GoalData
CurrentActivity
CurrentLocation
GuildTrust
RelationshipMap
MemoryList
CombatHistory
LifeHistory
```

`PotentialData`는 저장되지만 일반 UI에 공개하지 않는다.

## 6.3 RelationshipState

방향성을 가진다.

```text
FromCharacterId
ToCharacterId
BaseScore
Tags
Memories
LastInteractionTime
```

`A → B`와 `B → A`는 별도 데이터다.

## 6.4 MemoryState

```text
MemoryType
Importance
CreatedDay
RelatedCharacterIds
RelatedEventId
DecayPolicy
NarrativeKey
```

중요도:

- Weak
- Medium
- Strong

## 6.5 BuildingState

```text
Id
BuildingDefinitionId
GridPosition
Rotation
Level
ConstructionState
ConstructionProgress
DamageState
AssignedWorkerIds
```

프로토타입에서는 Rotation을 제한하거나 비활성화 가능.

## 6.6 ContractState

```text
Id
TemplateId
RegionId
TargetId
RewardGold
RewardData
RiskTier
CreatedTime
ExpireTime
Status
InterestedMercenaryIds
PartyId
```

## 6.7 ExpeditionState

```text
Id
PartyId
ContractId
Origin
Destination
DistanceTier
TravelProgress
TravelDuration
TravelEventCount
Policy
State
EncounterQueue
ResultLog
```

## 6.8 PartyState

```text
Id
MemberIds
LeaderId
CurrentExpeditionId
PartyTrustData
Doctrine
```

## 6.9 SaveRoot

```text
SaveVersion
WorldSeed
WorldTimeState
EconomyState
SettlementState
Mercenaries
ProfessionalResidents
RelatedResidents
Buildings
Contracts
Parties
Expeditions
History
CriticalEventQueue
Settings
```

---

# 7. Simulation과 View 분리

게임 핵심 계산은 가능하면 `MonoBehaviour`에 직접 넣지 않는다.

권장:

```text
MercenarySimulation
CombatSimulation
RelationshipSimulation
EconomySimulation
ExpeditionSimulation
```

이들은 순수 C# 로직으로 최대한 작성한다.

Unity Scene의 역할:

- Sprite 표시
- 애니메이션
- 입력
- 카메라
- 사운드
- 이펙트
- 실제 위치 보간

장점:

- EditMode 테스트 가능
- 오프스크린 파티 시뮬레이션 가능
- 세이브/로드 용이
- Codex가 기능을 수정할 때 영향 범위 감소

---

# 8. 게임 시간 시스템

## 8.1 세계 시간

확정 기준:

- ×1에서 현실 1시간 = 게임 1일
- 현실 1초 = 게임 24초
- ×2 / ×4 지원
- 일시정지 지원

계절:

- 봄 30일
- 여름 30일
- 가을 30일
- 겨울 30일
- 120일 = 1년

캐릭터 나이:

- 120게임일마다 +1세

정산:

- 급여/시설 유지비: 7게임일마다

## 8.2 시뮬레이션 Tick

화면 FPS와 게임 로직 Tick을 분리한다.

예시:

- Visual Update: 매 Frame
- Movement: FixedUpdate 또는 별도 Movement Update
- Village AI Decision: 몇 게임 분 단위 + 중요 상태 변화 시 즉시
- Needs: 누적 계산
- Economy: 일정 주기
- Relationship background update: 긴 주기
- Combat: 별도 combat simulation tick

NPC가 매 프레임 전체 AI 점수를 다시 계산하지 않는다.

---

# 9. 여행 시간 최종 기술 방향

과거 초안의:

- 2시간
- 4시간
- 8시간
- 12시간

을 **세계 시계에 그대로 묶는 방식은 폐기 권장**한다.

이유:

게임 하루가 현실 1시간이므로,
게임 8시간 이동은 현실 20분이 되어 플레이 체감이 지나치게 길다.

## 9.1 V1 권장 규칙

게임플레이에서는 **DistanceTier**를 사용한다.

```text
Near
Normal
Far
VeryFar
```

권장 ×1 체감:

- Near: 20~40초
- Normal: 40~70초
- Far: 60~100초
- VeryFar: 90~120초

세계관 문구에는:

- 가까운 지역
- 몇 시간 거리
- 반나절 거리
- 먼 원정

등의 표현을 사용할 수 있으나,
정확한 세계 시계 도착시간과 강제로 일치시키지 않는다.

## 9.2 여행 중 이벤트

권장 최대:

- Near: 0~1
- Normal: 0~1
- Far: 1~2
- VeryFar: 1~2, 드물게 3

여행 이벤트:

- 몬스터 흔적
- 매복
- 부상자/상인 발견
- 길 잃음
- 날씨 악화
- 희귀 장소 발견
- 개인 목표 단서

평상시 여행은 월드맵/원정 화면에서 진행한다.

특별 이벤트가 발생하면 전용 Encounter Map으로 전환 가능하다.

## 9.3 배속

여행에도 ×1 / ×2 / ×4 적용.

중요 이벤트 발생 시 자동 ×1 전환 가능.

---

# 10. 오프라인 진행

최대:

- 현실 8시간
- 기본 세계 시간 기준 게임 8일

허용:

- 수면
- 휴식
- 치료
- 일반 훈련
- 제작
- 저위험 활동
- 일반 관계 변화

온라인 복귀까지 보류:

- 영구 사망
- 5성 각성
- 대가/마스터 돌파
- 주요 개인 스토리
- 레이드
- 웨이브 결말
- 자연사

오프라인 Gold 부족:

- 체불 상태 생성 가능
- 오프라인 상태에서 자동 탈퇴시키지 않음

---

# 11. 마을 맵

## 11.1 기본 철학

고정 슬롯형이 아니라:

**Grid 기반 자유배치**

를 사용한다.

플레이어는 건물을 원하는 위치에 배치할 수 있다.

단:

- 타일 스냅
- 겹침 금지
- 중요 길 차단 방지
- 출입구 접근 가능
- 성벽/금지 구역 건설 불가

## 11.2 초기 마을

권장 시작 모습:

- 목책 성벽
- 성문
- 낡은 여관
- 임시 길드 천막
- 공동 숙영지
- 중앙 모닥불/작은 광장
- 넓은 빈 부지

초반에는 여관이 여러 기능을 임시로 겸한다.

- 모집
- 식사
- 숙박
- 소문
- 방문객
- 술집 기능 일부

이후 정식 시설이 생기며 기능이 분리된다.

## 11.3 BuildingDefinition

필수 데이터:

```text
FootprintWidth
FootprintHeight
EntranceCells
ObstacleCells
BuildCost
BuildTime
Category
Prefab
Icon
MaxLevel
```

프로토타입에서는 건물 Rotation을 제한하거나 비활성화한다.

---

# 12. 건설 배치 검증

건물을 놓을 때 다음을 검사한다.

1. 맵 범위
2. 다른 건물과 겹침
3. 성벽/금지 셀
4. 건물 출입구 접근성
5. 성문에서 핵심 마을 영역까지 연결성
6. 핵심 시설이 고립되지 않는지
7. 필요 시 최소 통로 폭

배치 Preview:

- 초록: 가능
- 빨강: 불가
- 출입구 화살표
- 장애물 영역
- 변경될 주요 동선

건설 확정 전 자유 이동 가능.

건설 시작 직후 짧은 유예 동안 무료 취소를 검토한다.

---

# 13. 길찾기

## 13.1 프로토타입

Grid A*.

셀 정보:

```text
Walkable
MovementCost
TerrainType
BuildingObstacle
Reserved
```

예:

- 돌길: 0.8
- 흙길: 1.0
- 잔디: 1.2
- 진흙: 2.0
- 장애물: 불가

실제 수치는 밸런스 데이터로 이동한다.

## 13.2 동적 건설

건물 건설/철거/파손 등 맵 변화 시:

```text
MapVersion++
```

NPC가:

- 목적지를 새로 선택했거나
- 기존 경로가 MapVersion 이후 막혔을 때

경로를 재계산한다.

매 프레임 재계산 금지.

## 13.3 Debug

개발 모드:

- Walkable Grid
- Movement Cost Heatmap
- 현재 NPC 경로
- 막힌 셀
- Entrance
- 주요 연결성

표시 가능.

---

# 14. 길 시스템

플레이어가 길을 깔 수 있게 확장 가능하다.

종류 예:

- 흙길
- 자갈길
- 돌길

길은 NPC가 절대적으로 따라야 하는 Rails가 아니라,
A*의 이동 비용을 낮춰 자연스럽게 선호하게 한다.

이 시스템은:

"NPC를 직접 움직이지 않고 환경으로 행동을 유도한다"

는 게임 철학과 일치한다.

---

# 15. Scene 구조

권장:

```text
Bootstrap
Town_Lastra
WorldMap
Combat_Belheim_01
Combat_Belheim_02
Combat_GoblinCamp
Combat_Rescue
Combat_Grokan
TravelEncounter_Plains
Test_Sandbox
```

## 15.1 Bootstrap

항상 유지:

- GameClock
- SaveService
- GameState
- SimulationCoordinator
- Audio
- SceneTransition
- Settings
- EventQueue

가능하면 하나의 Composition Root에서 시스템을 조립한다.

Singleton을 무분별하게 늘리지 않는다.

## 15.2 Offscreen Simulation

현재 화면에 없는 마을/원정대도
그래픽이 아니라 State 기반으로 계속 진행 가능하게 설계한다.

프로토타입에서는 기능 범위를 제한할 수 있으나
코어 로직을 Scene GameObject에 묶지 않는다.

---

# 16. 전투 맵

## 16.1 생성 방식

**수제 기본맵 + 제한적 모듈 랜덤화**

프로토타입에서 완전 절차생성은 사용하지 않는다.

벨하임 프로토타입 권장:

- 일반 야외맵 3개
- 고블린 야영지 1개
- 구조 의뢰 맵 1개
- 그로칸 보스맵 1개

## 16.2 전투맵 크기 초안

- 소형: 20×20 ~ 30×30
- 일반: 30×30 ~ 45×45
- 보스: 40×40 ~ 60×60

실제 Pixel Camera 테스트 후 조정.

## 16.3 지역 태그

확장용:

- Walkable
- Blocked
- Cover
- HighGround
- Hazard
- NarrowPath
- OpenArea
- EscapeRoute

프로토타입은:

- Walkable
- Blocked
- Hazard
- EscapeRoute

부터 시작 가능.

## 16.4 Spawn Zone

몬스터를 좌표 Random으로 뿌리지 않는다.

예:

- FrontlineSpawn
- BacklineSpawn
- AmbushSpawn
- RangedSpawn
- BossSpawn

역할 기반 Spawn Zone을 사용한다.

---

# 17. 자동전투 기술 구조

기본 공격/스킬/이동/보호/구조/후퇴를
Action 후보로 평가한다.

## 17.1 중요 원칙

직업:
무엇을 중요하게 생각하는가.

지혜:
그 상황을 얼마나 정확히 판단하는가.

성격:
판단 후 어떤 위험을 감수하는가.

관계:
누구를 더 지키거나 피하는가.

지침:
용병단장이 준 방향.

## 17.2 ActionScore

내부적으로 점수를 계산하되 사용자에게 원점수를 항상 노출하지 않는다.

개발 모드:

```text
ProtectAlly  82
Attack       64
Retreat      30
Skill        76
```

사용자:

```text
현재 행동: 카일 보호
이유:
- 카일이 전투불능 위험 상태
- 기사 역할상 보호 가치가 높음
```

## 17.3 전투시간

전투의 "2초 기본 공격주기"는 **Action Simulation Time**이다.

세계 시계의 2초가 아니다.

×2에서는 실제 애니메이션/행동 시간이 절반,
×4에서는 약 1/4로 진행된다.

세계 시계와 전투 시계를 직접 1:1로 묶지 않는다.

---

# 18. 전투 관전 UX

용병 선택 시:

- HP / MP
- 부상/상태이상
- 현재 대상
- 현재 행동
- 스킬 쿨다운
- 판단 이유 1~2개

전투 종료 후:

**Battle Story Report**

예:

```text
00:22 카일이 레나 대신 공격을 막음
00:31 레나 전투불능
00:33 카일이 레나 구조
00:48 미라가 대치유 사용
01:02 그로칸 처치

새로운 기억:
카일 → 레나: 생명의 은인
```

---

# 19. 생활 Utility AI

행동 후보:

- 식사
- 수면
- 휴식
- 훈련
- 치료
- 사회 활동
- 의뢰 확인
- 장비 점검
- 개인 목표
- 종교 행동
- 자유 행동

점수 입력:

- Needs
- 성격
- 관계
- 시간
- 시설
- 개인 목표
- 건강 상태
- 지침
- 최근 기억
- 긴급 상태

AI는 반드시 **선택 이유를 생성 가능한 형태로 계산**한다.

단순히 최종 점수만 반환하지 않는다.

예:

```text
DecisionResult
- SelectedAction
- Score
- TopPositiveReasons
- TopNegativeReasons
```

---

# 20. AI 설명 시스템

**P0 필수 기능.**

플레이어에게 중요한 행동은 최소 1개 이상의 이유를 제공한다.

예:

```text
레나가 훈련장을 선택했습니다.
- 검 실력을 더 높이고 싶어 합니다.
- 현재 피로가 낮습니다.
```

의뢰 거절:

```text
카일은 이 의뢰에 참가하지 않았습니다.
- 피로가 높습니다.
- 최근 같은 지역에서 크게 다친 기억이 있습니다.
```

이유 문구는 Localization Key 기반으로 설계한다.

---

# 21. 용병 수 / 파티

프로토타입:

- 시작 용병: 5명
- 최대 용병: 8명
- 일반 의뢰 파티: 2~4명
- 보스 의뢰 파티: 3~5명

초기 5명은 UX를 위해 역할군을 반고정 권장:

- 전방 공격 역할 1
- 방어/보호 역할 1
- 원거리 역할 1
- 회복/지원 역할 1
- 자유 역할 1

이름/외형/성격/특성/잠재력/배경은 랜덤 가능.

정확한 직업 고정 여부는 콘텐츠 설계 단계에서 조정 가능.

---

# 22. 원정 AI

순서:

1. 참가 여부 판단
2. 후보 파티 구성
3. 역할/관계/위험 평가
4. 리더 결정
5. 출발
6. 여행
7. Encounter
8. 목적지
9. 전투/의뢰
10. 귀환
11. 결과 처리

원정 정책:

- 보수적
- 균형
- 적극적

추후:

- 구조 우선
- 탐색 우선
- 전투 회피
- 재료 우선

등 확장 가능.

---

# 23. Critical Event Queue

중요 사건이 동시에 발생할 수 있으므로
모든 중요 이벤트를 즉시 팝업으로 띄우지 않는다.

우선순위 예:

1. 생명 위기 / 영구 사망 가능성
2. 5성 각성
3. 대가/마스터 돌파
4. 주요 개인 스토리
5. 웨이브/보스 주요 단계
6. 중요 관계 사건
7. 일반 알림

Queue:

```text
CriticalEvent
Priority
CreatedTime
TargetId
CanAutoResume
```

중요 사건 발생 시 자동 ×1 또는 Pause 정책을 개별 지정한다.

---

# 24. 경제 UX

Gold 숫자만 보여주지 않는다.

상단 Gold 터치 시:

```text
현재 Gold: 4,220
다음 정산까지: 2일 13시간
용병 급여        -1,400
전문 주민          -420
시설 유지비        -310
중앙령 지원        +500
예상 잔액:        2,590
```

건설 화면:

```text
병원 건설비: 1,000G
건설 후 보유: 3,220G
다음 정산 후 예상: 1,590G
```

위험하면 경고하되 건설을 강제로 금지하지 않는다.

---

# 25. 위험 / 죽음 UX

플레이어가 직접 전투를 조작하지 않으므로
사망이 "AI가 멋대로 죽었다"로 느껴지지 않게 해야 한다.

출정 전:

- 위험도
- 회복 수단
- 파티 역할 부족
- 부상자
- 피로
- 용병들의 자체 평가

를 질적으로 보여준다.

정확한 사망 확률은 표시하지 않는다.

---

# 26. UI 기술 방향

## 26.1 Runtime UI

**UI Toolkit 우선 검토/사용**.

이유:

- 데이터 중심 메뉴가 많음
- 리스트/탭/패널이 많음
- 에디터 확장과 기술 스택 통일 가능

단:

월드 위 체력바/간단한 마커 등은 Sprite/World UI 방식과 혼용 가능.

uGUI가 특정 기능에서 명확한 이점이 있을 때만 혼용한다.

## 26.2 메인 네비게이션

하단 4개:

- 마을
- 월드맵
- 용병단
- 기록

시설은 마을에서 직접 선택.

## 26.3 정보 계층화

캐릭터 터치 1단계:

- 이름
- 직업
- 성급/레벨
- 상태
- 현재 행동
- 간단한 이유

상세:

- 기본
- 장비
- 숙련
- 성격/특성
- 관계
- 기록

한 화면에 모든 정보를 노출하지 않는다.

---

# 27. 모바일 UX

필수:

- 충분한 터치 영역
- 드래그와 탭 충돌 방지
- 핀치 줌
- 건설 배치 중 확대/이동 가능
- Undo/Cancel
- 중요 알림 터치 시 대상 위치로 이동
- 색상만으로 위험/등급 구분 금지
- 글씨 크기 옵션
- 진동 ON/OFF
- 화면 흔들림 ON/OFF
- 전투 이펙트 강도 옵션

---

# 28. 첫 플레이 튜토리얼

장문의 팝업 튜토리얼 금지.

첫 플레이에서 실제 행동으로 가르친다.

권장 흐름:

1. 시작 용병 5명 소개
2. 용병 한 명 선택
3. 현재 행동 이유 확인
4. 첫 시설 건설
5. 첫 의뢰 등장
6. 용병들이 스스로 관심 표시
7. 자동 파티 생성
8. 짧은 여행
9. 첫 자동전투
10. 귀환
11. 치료/관계 변화 확인

프로토타입의 핵심 재미를 그대로 튜토리얼로 사용한다.

---

# 29. Save 시스템

## 29.1 원칙

- Definition은 ID만 저장
- Unity Object 직접 직렬화 금지
- SaveVersion 저장
- 버전 Migration 구조 준비
- 저장 중 앱 종료에 대비해 Atomic Write
- 저장 파일 손상 시 이전 AutoSave 복구 가능

## 29.2 저장 시점

- 일정 주기 AutoSave
- 의뢰 출발
- 전투 종료
- 건물 건설 완료
- 중요한 사건 완료
- 앱 Background 진입

## 29.3 슬롯

프로토타입 권장:

- AutoSave 1
- Manual Save 3

Cloud Save는 이후.

---

# 30. 개발자 도구

처음부터 제작한다.

## 30.1 Simulation Control

- Pause
- ×1 / ×2 / ×4
- 게임 시간 +1시간
- +1일
- 계절 변경

## 30.2 Mercenary Debug

- 즉시 생성
- HP 변경
- 피로 변경
- 스트레스 변경
- 관계 변경
- 부상 적용
- 숙련 변경
- 성급/레벨 테스트

잠재력 값은 Developer Mode에서만 확인 가능.

## 30.3 Contract Debug

- 의뢰 즉시 생성
- 만료 강제
- 위험도 변경
- 보스 의뢰 생성

## 30.4 Building Debug

- Gold 무시 건설
- 즉시 완공
- 파손
- 수리
- Placement Grid 표시

## 30.5 AI Debug Overlay

```text
훈련        72
식사        41
휴식        32
의뢰 확인   68
```

Top Reasons 포함.

## 30.6 Combat Debug

- 적 Spawn
- AI Freeze
- Damage
- Hitbox
- Target
- Threat
- Path

표시.

---

# 31. Editor 편의 도구

목표:

**개발자가 아닌 사용자도 숫자/드롭다운/드래그로 콘텐츠를 수정 가능하게 한다.**

우선순위:

1. ScriptableObject Inspector 정리
2. 데이터 생성 메뉴
3. Character Generator Test Window
4. Monster Test Window
5. Building Preview
6. Contract Generator
7. Validation Tool

Validation 예:

- ID 중복
- Building Entrance 없음
- Skill 참조 누락
- Monster Prefab 없음
- Contract Target 누락
- Sprite 누락

---

# 32. 코딩 규칙

- Balance 숫자 하드코딩 금지
- Magic String 최소화
- Stable ID 사용
- `Update()` 안에서 무거운 검색 금지
- `FindObjectOfType` 반복 사용 금지
- Pathfinding 매 Frame 호출 금지
- 시스템 간 직접 참조 최소화
- 기능 변경 시 관련 테스트 추가
- UI 문자열은 Localization Key 고려
- 공용 API에는 XML Summary 권장
- 클래스 하나가 지나치게 많은 책임을 가지지 않게 한다.

---

# 33. 테스트

## EditMode

- Utility AI 점수
- 관계 변화
- 경험치 계산
- 승급
- 경제 정산
- Building Placement Validation
- A* Pathfinding
- Save Migration

## PlayMode

- NPC 이동
- 건물 건설 후 경로 변경
- 의뢰 → 파티 → 원정
- 전투
- 구조
- 귀환
- Scene 전환
- Save/Load

---

# 34. Git / 프로젝트 관리

권장:

- Git
- Force Text Serialization
- Visible Meta Files
- 큰 바이너리는 Git LFS 검토

Codex 작업은 가능하면:

- 한 작업 = 한 논리 변경
- 대규모 일괄 리팩터링 최소화
- 작업 후 compile/test
- 변경 파일과 이유 요약

---

# 35. 프로토타입 구현 단계

## Phase 0 — Project Foundation

- Unity 프로젝트
- 패키지
- 폴더
- Bootstrap
- Save skeleton
- GameClock
- Debug panel

## Phase 1 — Village Sandbox

- 용병 5명
- Needs
- Utility AI
- 이동
- 여관/숙영지/훈련장
- AI Reason
- Grid A*

완료 기준:

용병이 스스로 장소를 고르고
플레이어가 이유를 확인 가능.

## Phase 2 — Free Building

- Grid Placement
- BuildingDefinition
- Obstacle update
- 경로 검사
- 건설
- 길

완료 기준:

건물을 자유 배치해도 NPC가 길을 다시 찾음.

## Phase 3 — Contract / Party

- 의뢰
- 관심
- 참가 판단
- 2~4명 파티
- 리더
- 원정 정책

## Phase 4 — Expedition

- DistanceTier
- 여행 progress
- 이벤트
- 월드맵
- 귀환

## Phase 5 — Combat Vertical Slice

- Warrior/Knight/Archer/Priest
- 몬스터 3~4종
- 기본공격
- 일반/강한 스킬
- 자동 타겟
- 구조
- 후퇴
- 부상
- Battle Report

## Phase 6 — Persistence / Android

- Save/Load
- Android Build
- 터치
- 성능
- UI Scale

---

# 36. 1차 프로토타입 완료 기준

아래 흐름이 하나의 세이브에서 끊김 없이 실행되어야 한다.

1. 라스트라 전초기지 시작
2. 용병 5명 존재
3. 용병들이 각자 생활 AI 행동
4. 플레이어가 건물을 자유배치
5. 길찾기가 건물을 우회
6. 의뢰 발생
7. 용병들이 참가 여부 판단
8. 2~4명 파티 자동 구성
9. 짧은 여행
10. 벨하임 전투
11. 공격/스킬/보호/구조/후퇴 작동
12. 부상 발생 가능
13. 결과에 따라 관계 기억 생성
14. 귀환
15. 치료/휴식/성장
16. 플레이어가 주요 행동 이유 확인
17. 저장 후 앱 재실행
18. 상태 정상 복구
19. Android 기기에서 터치로 조작 가능

프로토타입은 그래픽 완성도가 아니라
이 루프가 **재미있고 이해 가능한가**를 검증한다.

---

# 37. 프로토타입에서 의도적으로 제외

설계 데이터는 고려하되 구현 우선순위에서 제외:

- 레이드
- 대규모 웨이브 완성판
- 연애 심화
- 결혼/자녀
- 완전 절차생성 던전
- 모든 5개 지역
- 모든 시설 Lv.5
- 유물 전체 시스템
- 5성 전체 연출
- 대가/마스터 전체 콘텐츠
- 은퇴/자연사 완성판
- 복잡한 정치/파벌
- 오픈월드
- 멀티플레이

---

# 38. Codex 작업 지시 기본 템플릿

```text
Unity 공식 Codex Plugin을 사용한다.
먼저 현재 프로젝트 구조와 관련 파일을 확인한다.

목표:
[이번 작업의 단일 목표]

제약:
- Unity 6 LTS
- C#
- Android Landscape
- 데이터 하드코딩 금지
- ScriptableObject Definition / Runtime State 분리
- Simulation과 View 분리
- 기존 공개 API를 불필요하게 깨지 않는다.
- Inspector에서 수정 가능한 값은 Inspector/Data로 노출한다.
- 기능 구현 후 Compile 확인
- 관련 EditMode/PlayMode Test 실행

완료 후 보고:
1. 변경 파일
2. 구현 내용
3. Unity Editor에서 내가 수정 가능한 항목
4. 테스트 결과
5. 남은 위험/미구현
```

---

# 39. 기술 설계 v1에서 아직 확정하지 않는 것

- 최종 픽셀 캐릭터 크기
- URP 2D Light 사용 강도
- 실제 Tilemap 크기
- 최종 AI Tick 주기
- 최종 경험치 공식
- 최종 전투 수치
- 모바일 최소 사양
- Addressables 도입 시점
- Unity Behavior 사용 여부
- 실제 배치 통로 최소 폭
- 건물 Rotation 지원 시점
- 오프스크린 고위험 전투의 최종 자동해결 정책

이 항목은 프로토타입 측정 후 확정한다.

---

# 40. 기술 설계 v1 핵심 결론

이 프로젝트는
**Unity Editor를 단순 실행기가 아니라 콘텐츠 제작 도구로 사용한다.**

Codex는 코어 시스템과 편집 도구를 만든다.

사용자는 이후:

- Tilemap을 직접 칠하고
- 건물을 Prefab으로 배치하고
- ScriptableObject 숫자를 바꾸고
- Spawn Point를 움직이고
- 몬스터/장비 데이터를 복제해

코드를 직접 작성하지 않고도
상당 부분을 수정할 수 있어야 한다.

기술적으로 가장 중요한 것은
"기능을 많이 만드는 것"이 아니라

**자율 시뮬레이션이 설명 가능하고,
데이터가 편집 가능하고,
저장이 안전하며,
맵이 자유롭게 성장해도 AI가 깨지지 않는 구조를 만드는 것**이다.
