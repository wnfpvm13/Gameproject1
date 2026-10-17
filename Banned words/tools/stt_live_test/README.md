# STT live test — 사람 목소리 인식률

테스트 플레이스(placeId 84102094280848)에 설치하는 간단한 화면. 문장을 보여주고, 본인 마이크를 `AudioSpeechToText`로 받아써서
`src/shared/Judge.luau`(실제 게임에서도 쓸 판정 모듈)로 채점한다. 80문항 = 문장 60 + 단어 하나만 20.

- 설치: `python -I build_installer.py` → `install.luau` 생성 → 스튜디오 Edit 데이터모델에서 실행
  (18KB라 `moncook-claude/MonCook/tools/studio_mcp_client.py call execute_luau '{"studio_id":..,"datamodel_type":"Edit"}' install.luau`로 넘김).
  설치 스크립트가 `VoiceChatService.UseAudioApi = Enabled`도 같이 설정한다.
- 이후 **Roblox에 게시**해야 실제 서버에 반영된다.
- 결과: 화면에 성공/아슬/실패/빈 결과 집계. 서버가 문항마다 DataStore `SttLiveTest_v1`(키 `u<UserId>_<시각>`)에 저장.
  스튜디오에서 읽으려면 게임 설정 → 보안 → "Studio에서 API 서비스 접근 허용"을 켜야 한다(스튜디오 플레이 중엔 쓰기도 막힘).
- 판정 규칙 단위 확인(2026-10-17): 치킨이/7판이→칠판/선생님께 확정, 길이는(기린) 없음, 아이스 크림(띄어씀)·치킨집 아슬아슬.
