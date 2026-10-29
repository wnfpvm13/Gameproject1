--!strict
-- Who is blocking, on the server (decision 11's hold-to-block, persona fix 4). A player's client says when its block
-- control goes down and up (Names.BlockRemote, true/false). A fighter blocks while it holds the control, may fight
-- (hooks.canBlock: on the trains in a running fight) and its guard is not broken (a blocked string finisher breaks it
-- for Config.Block.BreakSeconds: breakGuard); it starts blocking again by itself after that if it still holds it. The
-- block is published as the model's Names.Blocking for every screen and for the attack judging (WeaponService asks
-- blocking()), and the fighter's walk is set again when it starts or stops (hooks.repace: the weapons slow a blocker).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local Guarding = {}

export type Hooks = {
	canBlock: (model: Model) -> boolean, -- on the trains in a running fight
	repace: (model: Model) -> (), -- sets the model's walk again for what it holds and whether it blocks
}
export type Service = {
	blocking: (model: Model) -> boolean,
	breakGuard: (model: Model, now: number) -> (), -- a blocked finisher: no blocking for a while
	stop: () -> (),
}

function Guarding.start(remote: RemoteEvent, hooks: Hooks): Service
	-- held: the fighters holding the control; brokenUntil: no blocking before this (server time).
	local held: { [Model]: boolean? } = setmetatable({}, { __mode = "k" }) :: any
	local brokenUntil: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local shown: { [Model]: boolean? } = setmetatable({}, { __mode = "k" }) :: any -- Names.Blocking set

	local function set(model: Model, on: boolean)
		if (shown[model] == true) == on then
			return
		end
		shown[model] = if on then true else nil
		model:SetAttribute(Names.Blocking, if on then true else nil)
		if model.Parent then
			hooks.repace(model)
		end
	end

	local function refresh(model: Model, now: number)
		local on = held[model] == true and model.Parent ~= nil and now >= (brokenUntil[model] or -math.huge) and hooks.canBlock(model)
		set(model, on)
	end

	local received = remote.OnServerEvent:Connect(function(player: Player, down: unknown)
		local model = player.Character
		if not model or typeof(down) ~= "boolean" then
			return
		end
		held[model] = if down then true else nil
		refresh(model, Workspace:GetServerTimeNow())
	end)
	-- The block also ends (and comes back) by itself: the fight ending, the fighter falling off, a guard break running out.
	local ticking = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for model in held do
			refresh(model, now)
		end
		for model in shown do
			if not held[model] then
				set(model, false)
			end
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		local model = player.Character
		if model then
			held[model] = nil
		end
	end)

	return {
		blocking = function(model: Model): boolean
			return shown[model] == true
		end,
		breakGuard = function(model: Model, now: number)
			brokenUntil[model] = now + Config.Block.BreakSeconds
			set(model, false)
		end,
		stop = function()
			received:Disconnect()
			ticking:Disconnect()
			leaving:Disconnect()
		end,
	}
end

return Guarding
