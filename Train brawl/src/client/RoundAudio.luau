--!strict
-- The round's sound on this client: the train's steady chuff all the time, western music (calm while waiting, faster
-- during the count-down and the fight), a tick for each count-down second, the whistle when the fight starts, and a
-- ding with a cheer for a winner (one cheer: not again over a home run's). A small button at the bottom right, above
-- the touch "때리기" button, turns the music off and on (the effects stay). Reads the Workspace round attributes each
-- frame; sounds come from Config.Sounds through SoundBank.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local RoundAudio = {}
RoundAudio.__index = RoundAudio

type Fields = {
	train: Sound?,
	waiting: Sound?,
	fight: Sound?,
	phase: string?,
	lastTick: number?, -- the count-down second last ticked
	musicOn: boolean,
	button: TextButton,
}
export type Audio = typeof(setmetatable({} :: Fields, RoundAudio))

local function setMusicLabel(button: TextButton, on: boolean)
	button.Text = if on then "♪ 음악 켬" else "♪ 음악 끔"
	button.BackgroundTransparency = if on then 0.35 else 0.6
end

function RoundAudio.new(playerGui: Instance): Audio
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlAudio"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local button = Instance.new("TextButton")
	button.Name = "Music"
	-- Above the touch "때리기" button, whose top is 230 above the bottom (SwingInput).
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -20, 1, -240)
	button.Size = UDim2.fromOffset(104, 32)
	button.BackgroundColor3 = Color3.fromRGB(40, 32, 26)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 18
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Parent = gui

	local fields: Fields = {
		train = SoundBank.loop("Train"),
		waiting = SoundBank.loop("MusicWaiting"),
		fight = SoundBank.loop("MusicFight"),
		phase = nil,
		lastTick = nil,
		musicOn = true,
		button = button,
	}
	local self = setmetatable(fields, RoundAudio)
	setMusicLabel(button, true)
	button.Activated:Connect(function()
		self.musicOn = not self.musicOn
		SoundBank.setMusic(self.musicOn)
		setMusicLabel(button, self.musicOn)
	end)
	if self.train then
		self.train:Play()
	end
	return self
end

-- Plays one of the two music loops and stops the other.
local function music(self: Audio, fightMusic: boolean)
	local on, off = if fightMusic then self.fight else self.waiting, if fightMusic then self.waiting else self.fight
	if off and off.IsPlaying then
		off:Stop()
	end
	if on and not on.IsPlaying then
		on:Play()
	end
end

-- Every frame. now: server time.
function RoundAudio.update(self: Audio, now: number)
	local phase = Workspace:GetAttribute(Names.Phase)
	local current = if typeof(phase) == "string" then phase else "Waiting"
	if current ~= self.phase then
		local before = self.phase
		self.phase = current
		music(self, current == "Countdown" or current == "Fight")
		if current == "Fight" and before == "Countdown" then
			SoundBank.play("Whistle")
		elseif current == "Ended" and before ~= nil then -- not for someone who joins during the result
			local winner = Workspace:GetAttribute(Names.Winner)
			if typeof(winner) == "string" and winner ~= "" then
				SoundBank.play("Win")
				if not SoundBank.playing("Cheer") then -- a home run's cheer may be on already
					SoundBank.play("Cheer")
				end
			end
		end
	end
	if current == "Countdown" then
		local left = math.ceil((PartUtil.number(Workspace, Names.PhaseEndsAt) or now) - now)
		if left >= 1 and left ~= self.lastTick then
			self.lastTick = left
			SoundBank.play("Tick")
		end
	else
		self.lastTick = nil
	end
end

return RoundAudio
