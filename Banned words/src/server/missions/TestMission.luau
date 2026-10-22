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
	fail: (players: { Player }, key: string) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	wait: (seconds: number) -> boolean,
}

local TestMission = {
	id = "test",
	expectedSeconds = Config.TEST_MISSION_SECONDS,
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
