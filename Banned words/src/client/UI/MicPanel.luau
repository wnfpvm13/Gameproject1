--!strict
-- Voice connection and mic test lines (rows 0 and 1 under the status board), plus the earphone tip.
-- Both are empty while I play with a working mic, so nothing covers the chair row.
local Style = require(script.Parent:WaitForChild("Style"))

local MicPanel = {}

local voiceL: TextLabel
local testL: TextLabel

function MicPanel.build()
	voiceL = Style.line(0, Style.RED)
	testL = Style.line(1, Style.AMBER)
end

function MicPanel.setVoice(status: string)
	if status == "NoVoice" then
		voiceL.Text = "음성 채팅을 쓸 수 없는 계정이에요 (만 13세 이상 + 연령 인증 필요)"
	elseif status == "Disconnected" then
		voiceL.Text = "음성 채팅 연결 필요 · 왼쪽 위 ≡ 메뉴(또는 ESC) → 설정 → 음성 채팅 연결"
	elseif status == "Muted" then
		voiceL.Text = "마이크가 꺼져 있어요"
	else
		voiceL.Text = ""
	end
end

-- What the player should do next to take a seat. `inMyRound` hides it while I'm playing.
function MicPanel.setTest(status: string, micTested: boolean, inMyRound: boolean, readyCount: number?)
	local text, done = "", false
	if inMyRound then
		text = ""
	elseif status == "NoVoice" then
		text = "음성 채팅을 쓸 수 없는 계정이라 관전만 할 수 있어요"
	elseif status == "Disconnected" then
		text = "음성을 연결하면 다음 판부터 참가할 수 있어요"
	elseif status == "Muted" then
		text = "마이크를 켜 주세요"
	elseif not micTested then
		text = "마이크 테스트 · 아무 말이나 해 보세요"
	else
		done = true
		local ready = if readyCount then string.format("준비 완료! (준비된 사람 %d명)", readyCount) else "준비 완료!"
		-- Speakers can feed other people's voices back into my mic, and others say my words on purpose.
		text = ready .. " · 이어폰을 쓰면 억울한 탈락을 막을 수 있어요"
	end
	testL.Text = text
	testL.TextColor3 = if done then Style.GREEN else Style.AMBER
end

return MicPanel
