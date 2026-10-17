# STT probe — 한국어 받아쓰기 자동 검증

사람 없이 `AudioSpeechToText`의 한국어 인식률을 재는 도구. Windows 한국어 음성(Microsoft Heami)으로 문장 WAV를 만들고,
스튜디오 클라이언트에서 `AudioPlayer → Wire → AudioSpeechToText`로 넣어 받아쓴 문장을 기록한다.

## 결과 (2026-10-17)

- 60문장 중 54개 확정 판정 성공(90%), 지연 평균 0.76초 / 최대 0.81초. 원본: `results_2026-10-17.json`, 채점: `python -I analyze.py`
- 놓친 것: 기린→"길이", 시계→"시기"(오인식), 코끼리·숙제·칠판·봄비 "~는 어디 있어?" 문장은 소리는 감지(VoiceDetected)됐는데 글자가 빔
- 단어만 단독으로 말하면 언어 감지가 틀림: 코끼리→"小キリ", 봄비→"Humbi", 칠판→"7판"
- 영어 문장은 한국어로 번역돼 나옴(플레이어 언어 기준으로 보임)

## 재현 순서

1. 테스트 플레이스는 **게시돼 있어야** 한다(로컬 파일 PlaceId 0에서는 빈 결과). 현재: placeId 84102094280848 / universe 10771466383
   (dogyes03 계정, 비공개). 열기: `RobloxStudioBeta.exe -task EditPlace -placeId 84102094280848 -universeId 10771466383`
2. 게임 설정 → 커뮤니케이션 → **음성 채팅 활성화** 켜기.
3. **`VoiceChatService.UseAudioApi = Enabled`** (Edit 데이터모델). "Automatic"이면 오류 없이 빈 결과만 나온다 — 이게 가장 오래 막힌 부분.
   스튜디오를 껐다 켜면 사라질 수 있으니 플레이스에 저장할 것.
4. `make_audio.ps1 -StudioVersionDir <%LOCALAPPDATA%\Roblox\Versions\version-xxxx>` → `content\sounds\bannedwords_probe\wNN.wav` + `manifest.json`.
   스튜디오 설치 폴더의 content는 `rbxasset://sounds/...`로 업로드 없이 읽힌다(스튜디오 업데이트 때 지워짐).
   스크립트는 UTF-8 **BOM 필수**(PowerShell 5.1이 BOM 없으면 한글을 깨뜨림).
5. 플레이 시작 → `probe_client.luau`를 Client 데이터모델에서 실행(백그라운드로 돌고 `_G.BW_PROBE`에 결과) →
   끝나면 `HttpService:JSONEncode(_G.BW_PROBE.results)`를 받아 `results_<날짜>.json`으로 저장 → `analyze.py`.

## 막혔던 것

- 로블록스 `AudioTextToSpeech`는 한글 텍스트를 "InvalidText"로 거부(일본어·중국어도). 영어·스페인어·프랑스어만 됨. 그래서 Windows TTS 사용.
- 짧은 시간에 TTS 로드를 많이 하면 HTTP 429.
- `AudioPlayer`에는 `LoadAsync`가 없다(`IsReady`를 기다림). `AudioTextToSpeech`에는 있다.
- 사용자 PC 화면 캡처로 GUI를 조작하려 했지만 사용자가 게임·디스코드를 쓰는 중이라 중단. 게시와 설정은 사용자가 직접 함.
