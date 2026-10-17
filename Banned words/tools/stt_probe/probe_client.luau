-- Banned words STT probe (client). Plays each generated Korean WAV into AudioSpeechToText and records the transcript.
-- Requires: published place, voice chat enabled, VoiceChatService.UseAudioApi = Enabled, WAVs under content/sounds/bannedwords_probe.
local GAP = _G.BW_GAP or 1 -- seconds between requests; free STT quota is 1 + 5 x CCU per minute
local ITEMS = {
	{id = "w01", word = "치킨", sentence = "치킨이 정말 좋아"},
	{id = "w02", word = "피자", sentence = "나는 어제 피자를 봤어"},
	{id = "w03", word = "떡볶이", sentence = "떡볶이는 어디 있어?"},
	{id = "w04", word = "라면", sentence = "라면이 정말 좋아"},
	{id = "w05", word = "김밥", sentence = "나는 어제 김밥을 봤어"},
	{id = "w06", word = "사과", sentence = "사과는 어디 있어?"},
	{id = "w07", word = "바나나", sentence = "바나나가 정말 좋아"},
	{id = "w08", word = "아이스크림", sentence = "나는 어제 아이스크림을 봤어"},
	{id = "w09", word = "햄버거", sentence = "햄버거는 어디 있어?"},
	{id = "w10", word = "초콜릿", sentence = "초콜릿이 정말 좋아"},
	{id = "w11", word = "강아지", sentence = "나는 어제 강아지를 봤어"},
	{id = "w12", word = "고양이", sentence = "고양이는 어디 있어?"},
	{id = "w13", word = "토끼", sentence = "토끼가 정말 좋아"},
	{id = "w14", word = "호랑이", sentence = "나는 어제 호랑이를 봤어"},
	{id = "w15", word = "코끼리", sentence = "코끼리는 어디 있어?"},
	{id = "w16", word = "원숭이", sentence = "원숭이가 정말 좋아"},
	{id = "w17", word = "펭귄", sentence = "나는 어제 펭귄을 봤어"},
	{id = "w18", word = "기린", sentence = "기린은 어디 있어?"},
	{id = "w19", word = "거북이", sentence = "거북이가 정말 좋아"},
	{id = "w20", word = "햄스터", sentence = "나는 어제 햄스터를 봤어"},
	{id = "w21", word = "숙제", sentence = "숙제는 어디 있어?"},
	{id = "w22", word = "선생님", sentence = "선생님이 정말 좋아"},
	{id = "w23", word = "교실", sentence = "나는 어제 교실을 봤어"},
	{id = "w24", word = "시험", sentence = "시험은 어디 있어?"},
	{id = "w25", word = "연필", sentence = "연필이 정말 좋아"},
	{id = "w26", word = "지우개", sentence = "나는 어제 지우개를 봤어"},
	{id = "w27", word = "칠판", sentence = "칠판은 어디 있어?"},
	{id = "w28", word = "급식", sentence = "급식이 정말 좋아"},
	{id = "w29", word = "방학", sentence = "나는 어제 방학을 봤어"},
	{id = "w30", word = "운동장", sentence = "운동장은 어디 있어?"},
	{id = "w31", word = "컴퓨터", sentence = "컴퓨터가 정말 좋아"},
	{id = "w32", word = "핸드폰", sentence = "나는 어제 핸드폰을 봤어"},
	{id = "w33", word = "의자", sentence = "의자는 어디 있어?"},
	{id = "w34", word = "책상", sentence = "책상이 정말 좋아"},
	{id = "w35", word = "우산", sentence = "나는 어제 우산을 봤어"},
	{id = "w36", word = "냉장고", sentence = "냉장고는 어디 있어?"},
	{id = "w37", word = "텔레비전", sentence = "텔레비전이 정말 좋아"},
	{id = "w38", word = "시계", sentence = "나는 어제 시계를 봤어"},
	{id = "w39", word = "안경", sentence = "안경은 어디 있어?"},
	{id = "w40", word = "가방", sentence = "가방이 정말 좋아"},
	{id = "w41", word = "수영장", sentence = "나는 어제 수영장을 봤어"},
	{id = "w42", word = "놀이터", sentence = "놀이터는 어디 있어?"},
	{id = "w43", word = "병원", sentence = "병원이 정말 좋아"},
	{id = "w44", word = "편의점", sentence = "나는 어제 편의점을 봤어"},
	{id = "w45", word = "도서관", sentence = "도서관은 어디 있어?"},
	{id = "w46", word = "바다", sentence = "바다가 정말 좋아"},
	{id = "w47", word = "공원", sentence = "나는 어제 공원을 봤어"},
	{id = "w48", word = "영화관", sentence = "영화관은 어디 있어?"},
	{id = "w49", word = "학원", sentence = "학원이 정말 좋아"},
	{id = "w50", word = "지하철", sentence = "나는 어제 지하철을 봤어"},
	{id = "w51", word = "무지개", sentence = "무지개는 어디 있어?"},
	{id = "w52", word = "눈사람", sentence = "눈사람이 정말 좋아"},
	{id = "w53", word = "장마", sentence = "나는 어제 장마를 봤어"},
	{id = "w54", word = "태풍", sentence = "태풍은 어디 있어?"},
	{id = "w55", word = "여름", sentence = "여름이 정말 좋아"},
	{id = "w56", word = "겨울", sentence = "나는 어제 겨울을 봤어"},
	{id = "w57", word = "봄비", sentence = "봄비는 어디 있어?"},
	{id = "w58", word = "구름", sentence = "구름이 정말 좋아"},
	{id = "w59", word = "번개", sentence = "나는 어제 번개를 봤어"},
	{id = "w60", word = "단풍", sentence = "단풍은 어디 있어?"}
}
local folder = workspace:FindFirstChild("SttProbe") or Instance.new("Folder")
folder.Name = "SttProbe"
folder.Parent = workspace
local results = {}
_G.BW_PROBE = { done = false, results = results, total = #ITEMS }
task.spawn(function()
	for _, item in ipairs(ITEMS) do
		local ap = Instance.new("AudioPlayer")
		ap.Asset = "rbxasset://sounds/bannedwords_probe/" .. item.id .. ".wav"
		ap.Parent = folder
		local stt = Instance.new("AudioSpeechToText")
		stt.Enabled = true
		stt.Parent = folder
		local wire = Instance.new("Wire")
		wire.SourceInstance = ap
		wire.TargetInstance = stt
		wire.Parent = stt
		local t = os.clock()
		while not ap.IsReady and os.clock() - t < 5 do task.wait(0.05) end
		local texts = {}
		stt:GetPropertyChangedSignal("Text"):Connect(function()
			if stt.Text ~= "" then table.insert(texts, stt.Text) end
		end)
		local ended = false
		ap.Ended:Connect(function() ended = true end)
		local t0 = os.clock()
		ap:Play()
		while not ended and os.clock() - t0 < 12 do task.wait(0.05) end
		local tEnd = os.clock()
		while #texts == 0 and os.clock() - tEnd < 6 do task.wait(0.05) end
		local latency = #texts > 0 and (os.clock() - tEnd) or -1
		task.wait(0.5)
		table.insert(results, { id = item.id, word = item.word, sentence = item.sentence, text = table.concat(texts, " "), latency = latency })
		stt:Destroy()
		ap:Destroy()
		task.wait(GAP)
	end
	_G.BW_PROBE.done = true
end)
return "started " .. #ITEMS
