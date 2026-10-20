# 금칙어 게임 Korean — 그래픽 개선안 (2026-10-21)

상태: **계획만 있음 — 오너의 방향 결정 대기.** 코드·맵·게시된 장소는 아직 바꾸지 않았다.
계기: 오너 질문(2026-10-21) "게임 안의 디자인 그래픽을 좀 더 높일 순 없겠어?"
검토: Codex 1번 + Claude 검토자 1번 + Codex 재확인 1번 (맨 아래 "검토 기록").

## 1. 진단

- **조명 설정이 꺼져 있다시피 하다.** QA 장소 저장본(`.qa/v2_mp1.rbxlx`)과 Studio MCP로 읽은 값:
  `LightingStyle = Soft`(공식 설명 "flat, retro look"), `GlobalShadows = false`, `PrioritizeLightingQuality = false`,
  `EnvironmentDiffuseScale = 0`, `EnvironmentSpecularScale = 0`, 하늘(Sky)·후처리 효과 없음,
  `Technology = Compatibility`(사용 중단된 옛 설정).
  `tools/build_lounge_map.luau`는 `ClockTime`·`Ambient`·`OutdoorAmbient`·`Brightness`만 정하고, 나머지는 장소 파일의 기본값이다.
- **가구가 상자 몇 개를 붙인 모양이다.** 의자 = 상자 5개(Base·Seat·Back·ArmL·ArmR), 소파 = 상자 2개, 테이블 = 원판 + 기둥 + 네온 공.
  조명과 모양은 따로 봐야 한다. 조명은 코드 몇 줄로 바뀌고, 모양은 다시 만들어야 한다.
- **조명 설정은 스크립트로 바꿀 수 있다.** 공식 문서(creator-docs `Lighting.yaml`)에서 `LightingStyle`·`PrioritizeLightingQuality`·
  `GlobalShadows`·`Environment*Scale`의 보안 등급은 None이다. Studio MCP(Edit)에서도 써지는 것을 확인했고, 확인 뒤 원래 값으로 되돌렸다.
  → 맵 생성 스크립트에 넣으면 되고, 오너가 손으로 바꿀 것은 없다. `Technology`는 RobloxScriptSecurity라 스크립트로 못 바꾸지만,
  사용 중단된 설정이라 바꿀 필요도 없다.
- **조명만 바꾼 미리보기 사진은 아직 없다.** QA Studio 창(`v21_check.rbxlx`)이 최소화돼 있으면 `screen_capture`가 흰 화면만 준다
  (원래 설정에서도 흰 화면이었으니 조명 탓이 아니다). 창을 띄우는 것은 데스크톱 조작이라 오너 허락을 받은 뒤 찍는다.
  미리보기로 바꾼 값은 전부 되돌렸다. 앞서 찍은 미리보기 1번(Realistic 없이 시각·Atmosphere 등만 바꿈)은 차이가 작았다.

## 2. 앉은 시점에서 보이는 것 (화면 비중·중요도 순)

카메라(`LoungeMap.CameraRig`): 의자 뒤 9, 높이 11에서 원 중심 높이 6을 본다. 의자는 반지름 10, 맞은편 얼굴까지 약 29~30.

1. **맞은편 사람들의 얼굴과 금칙어 말풍선** — 가장 중요하다. 맞은편 바깥 램프(반지름 22, 네온 갓 높이 6.6~8.2)가
   말풍선과 같은 띠(수평선 아래 약 2~10°)에 겹쳐 글자를 방해한다 → 램프를 옮기거나 빛나지 않게 하고, 그 띠는 어둡고 단순하게 둔다.
   강한 Bloom은 이 문제를 키운다.
2. **링 안 바닥·카펫** — 화면 아래 약 1/3로 가장 큰 면.
3. **의자** — 양옆 의자의 등·옆면이 화면 아래 양쪽에 크게 보인다 → 사방을 다듬되, 등받이는 낮게 유지(얼굴을 가리지 않게).
4. **맞은편 바깥 라운지(소파·바)** — 맞은편 얼굴 바로 뒤 배경이다("관전자만 본다"는 틀림). 어둡고 차분하게.
5. **가운데 테이블·센터피스** — 폰에서는 하단 UI(미션 카드·투표판) 뒤에 가려지기 쉽다. 센터피스 높이는 약 6 미만(맞은편 얼굴을 가리지 않게).
6. **천장** — 화면 위쪽 띠(폰 약 8%, 16:9 약 15%)뿐 → 어두운 하늘이나 간단한 천장이면 충분하다.

## 3. 조명·효과

- `LightingStyle = Realistic`, `GlobalShadows = true`, 환경 반사 켜기(값은 실측으로 정함), 어두운 Sky, 가벼운 `ColorCorrectionEffect`.
- `BloomEffect`는 약하게만(말풍선이 번진다). `Atmosphere`는 반지름 42 실내라 효과가 작아 뺀다.
  `DepthOfFieldEffect`는 넣지 않는다(볼 대상이 모두 19~30 거리에 있어 얻는 게 없고, 비용과 얼굴 식별 저하만 생긴다).
- **얼굴 정면광**: 원 중심 쪽에서 앉은 사람 얼굴로. 지금 센터피스 조명(높이 2.45)은 얼굴을 아래에서 비춘다.
  어두운 스튜디오(A안)는 얼굴이 어두워질 위험이 있다.
- 조명 수: 지금 PointLight 9개(범위 18~20)가 링까지 겹친다 → 개수·범위를 줄인다.

## 4. 저사양·성능

- 저사양 기기에서는 그래픽 품질이 자동으로 내려가 일부 효과가 줄어든다(어디까지 줄어드는지는 실기기에서 확인)
  → 그림자·Bloom 없이도 색·재질·네온만으로 괜찮아 보이는 기본 외형이 필요하다. Studio에서 그래픽 품질을 낮춰 먼저 확인한다.
- 휴대폰 시뮬레이터는 화면비·터치 확인용이다. 메모리·성능은 정확하지 않다(공식 문서 "Test on hardware").
  성능은 실기기에서 잰다(오너가 나중에 하기로 한 실기기 테스트에 포함).
- **기준 기기**: 고사양 = Galaxy S23+(60fps, 프레임당 16.7ms). **저사양 기준 기기는 아직 없다 → 오너가 정한다.**
  공식 문서의 예: Infinix Smart 9, Motorola Moto G05, Oppo A18 같은 보급형 Android.
- **합격선(제안, 첫 측정 뒤 조정)**: 10명·음성·말풍선·투표·연출을 켠 한 판 전체와 10~15분 연속 플레이에서
  - 저사양 30fps(프레임당 33.3ms) 유지, 시간이 갈수록 프레임이 꾸준히 떨어지지 않을 것(발열로 느려지는 신호)
  - 메모리: 판을 반복해도 계속 늘지 않고, 강제 종료(메모리 부족)가 없을 것
  - 처음 잰 draw call·삼각형 수(Shift+F2의 Render 통계)를 이후 예산으로 기록
  - 공식 문서는 고정된 메모리 숫자를 주지 않고 "기준 기기에서 재서 한계를 정하라"고 한다 → 숫자는 첫 측정 뒤 정한다.
- **휴대폰에서 재는 법**: 설정 메뉴에서 Performance Stats 켜기(FPS·메모리·핑 표시). Developer Console은 설정 메뉴에서 열어 Memory 탭 확인.
  MicroProfiler는 설정에서 켠 뒤, 같은 와이파이에 있는 PC 브라우저로 화면에 나온 IP:포트에 접속해 본다. PC에서는 F9·Shift+F2.
- **효과 비용 정책**: 그림자를 내는 조명은 1~3개로 시작하고(경험칙일 뿐 보장 아님), 작은 소품은 `CastShadow`를 끈다.
  Bloom·그림자는 같은 장면에서 켠 상태/끈 상태를 MicroProfiler로 비교해 비싸면 줄이거나 뺀다.
  ("Bloom 약하게"는 보기 좋게 하려는 기준이지 성능 기준이 아니다.)

## 5. 방향 (오너가 하나 고름)

- **A. 예능 토크 스튜디오**: 트러스 조명·스포트라이트·네온 로고. 주의: 얼굴이 어두워지지 않게 정면광 필수.
  벽 LED 화면은 원형 배치라 맞은편 약 3자리만 정면으로 보므로, 정보는 UI로 보여 주고 벽 장식은 사방에 반복한다.
- **B. 아늑한 라운지**: 따뜻한 나무·식물·펜던트 조명. 지금 방향을 다듬는 안.
- **C. 파티룸**: 네온·미러볼. 주의: 말풍선 띠가 산만해지기 쉽다.
- 공통: Roblox에는 실시간 장면 반사가 없어 "광택 바닥"은 환경맵 반사·하이라이트 수준으로 기대치를 낮춘다.

## 6. 제작 방법 (섞어 써도 됨)

- Studio에서 직접(둥근 모서리·유니온·재질), Blender 직접 모델링(무료, MCP 있음, MonCook에서 쓰던 방식),
  Creator Store 무료 모델(숨은 스크립트 검사 필수), Roblox 자체 생성(MCP `generate_mesh`·`generate_material` — 이용 조건 확인),
  AI 3D(Meshy/Tripo — 크레딧이 들어 오너 승인 필요).
- 의자는 화면 폭의 약 8~18%라 텍스처는 512px 이하면 충분하다.

## 7. 만드는 방식 (다시 만들어도 같은 결과)

- `tools/build_lounge_map.luau`는 실행할 때마다 `LoungeMap`을 지우고 `Terrain`도 비운다 → 가져온 모델은 `LoungeMap` 밖
  (예: ServerStorage의 템플릿 폴더)에 두고 빌더가 복제한다. 조명·효과 설정도 빌더에 넣는다.
- 코드가 기대하는 구조를 지킨다: `Chairs` 아래 각 의자의 `Seat`와 `SeatIndex` 속성(SeatService), `Center`와 `CameraRig` 속성
  (RingCamera, SeatService, GhostService), `RingBarrier`의 `Radius` 속성과 `Spawn`(GhostService).
- MaterialVariant는 모바일에서도 쓸 수 있다. MaterialService에 두고 BaseMaterial을 맞추고 파트에 변형 이름을 지정한다.
  텍스처 속성 작성은 플러그인 권한이라 한 번 만들어 장소에 저장한다. 환경 반사(`EnvironmentSpecularScale`)가 0이면 재질이 밋밋해 보인다.

## 8. UI

- 공통 폰트·색·둥근 모서리는 이미 있다(`src/client/UI/Style.luau`) → 휴대폰 최소 글자 크기, 말풍선·패널 겹침,
  좁은 화면의 시야각 제한(좌우 42°가 보장되지 않음)을 먼저 본다.

## 9. 순서

1. **1단계(돈 안 들고 효과 큼)**: 조명 설정 + 얼굴 정면광 + 맞은편 램프 정리(말풍선 띠 비우기) + 바닥·카펫 + 의자 사방 다듬기.
   전부 `tools/build_lounge_map.luau`에 넣는다.
2. **2단계**: 의자·테이블 등 핵심 소품 교체(고른 제작 방법), 배경(맞은편 라운지) 정돈.
3. **3단계**: 연출·UI 세부, 실기기 성능 측정.

## 검토 기록

- **Codex(gpt-6.1-sol xhigh) 1차, 04:27 — 지적 10건, 모두 반영.** `Technology=Future` 대신 `LightingStyle=Realistic`·
  `PrioritizeLightingQuality` 기준으로 갱신 / "Future가 아니라 효과가 약했다"는 인과 미입증 / 그림자 조명 1~3개는 성능 보장 아님,
  PointLight 9개 포함 예산 / 효과별 비용(Bloom·Atmosphere·ColorCorrection), DepthOfField 기본 제외 / 시뮬레이터로 FPS 검증 불가
  / "바깥 라운지는 관전자만 본다" 틀림(앉은 시점 재평가) / UI 목표가 기존 구현과 겹침 / MaterialVariant 조건 / 빌더가 LoungeMap을
  지우므로 자산 복제 경로·구조 유지 조건 / 제작 방법 혼합 허용.
- **Claude 검토자 1명(새로 띄움) — 지적 14건, 13건 반영.** 저장본에서 현재 조명값 확인(Compatibility·Soft·그림자 꺼짐·반사 0),
  램프 네온이 말풍선 띠와 겹침, 바닥·카펫 누락, 테이블이 폰 하단 UI에 가려짐, 천장은 상단 띠뿐, 의자 사방 다듬기,
  A안 벽 LED는 약 3자리만 정면, 실시간 반사 없음, 빌더가 Terrain도 비움, Blender·Roblox 자체 생성 선택지, 텍스처 512px 등.
  **반영하지 않은 1건**: "LightingStyle·PrioritizeLightingQuality는 PluginOrOpenCloud 권한이라 게임 스크립트로 못 바꾼다"는
  공식 문서(보안 등급 None)·MCP 쓰기 성공과 달라서 문서와 실측을 따랐다(어느 쪽이든 빌더는 Studio에서 플러그인 권한으로 실행된다).
- **Codex 재확인, 04:46 — 기존 지적 반영 확인, 새로 틀린 사실 없음, 중간 3건.** 저사양 기준 기기·메모리·발열 합격선,
  휴대폰 측정 절차(Performance Stats·Developer Console·MicroProfiler 원격 보기), 그림자·Bloom 비용 정책.
  공식 문서(Test on hardware, MicroProfiler, Design for performance)로 확인한 뒤 4절에 반영했다.
  재확인은 규칙상 1번이라 추가 재확인은 돌리지 않았다.
