--!strict
-- The Studio-only test mission (bundle 2b): stands in for the real missions until bundle 4, so the round flow (lives,
-- launches, the final, the time budget) can be tried in Studio. In the main game every alive player fails with
-- TEST_FAIL_CHANCE; as a final question it knocks out each finalist with TEST_FINAL_FAIL_CHANCE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

-- MissionRunner.MissionCtx (missions cannot require services, so the shape is repeated here).
type Ctx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	stopped: () -> boolean,
	wait: (seconds: number) -> boolean,
	reveal: (seconds: number) -> (),
	flying: (player: Player) -> boolean,
	answers: (answered: { Player }, missed: { Player }) -> (),
	screen: (payload: { [string]: any }?) -> (),
	ask: (payload: { [string]: any }, choices: number, seconds: number, from: { Player }) -> { [Player]: number },
	canFling: (player: Player) -> boolean,
	presenterPick: (options: { { id: string, title: string, recommended: boolean } }, seconds: number) -> string?,
	lever: () -> (),
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
	bell: (from: { Player }, seconds: number, firstOnly: boolean,
		enough: (({ Player }, { [Player]: number }) -> boolean)?) -> ({ Player }, { [Player]: number }),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
}

local TestMission = {
	id = "test",
	title = Config.TEXT.TEST_MISSION_TITLE,
	expectedSeconds = Config.TEST_MISSION_SECONDS,
	maxPerRound = nil :: number?, -- like the quiz: no limit
	minPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

function TestMission.available(_final: boolean): boolean
	return RunService:IsStudio()
end

function TestMission.run(ctx: Ctx)
	ctx.show(if ctx.final then Config.TEXT.FINAL else Config.TEXT.TEST_MISSION)
	if not ctx.wait(Config.TEST_MISSION_SECONDS) then
		return
	end
	local chance = if ctx.final then Config.TEST_FINAL_FAIL_CHANCE else Config.TEST_FAIL_CHANCE
	local failed = {}
	for _, player in ctx.players() do
		if ctx.rng:NextNumber() < chance then
			table.insert(failed, player)
		end
	end
	ctx.fail(failed, "result")
end

return TestMission
