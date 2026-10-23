--!strict
-- Where one locomotive's run is on this client: its distance from the run the server keeps on the locomotive
-- (Names.RunStart/RunFrom/RunSpeed, read when Names.RunVersion changes) and the shared server clock. For the player's
-- own locomotive it also judges each low bridge from the real squash shape (the animator's top height) the moment it
-- is decided; after a hit it holds the run where the face met the bridge until the server's crash arrives, so the
-- bridge does not slide on through the face meanwhile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local TrainState = require(shared:WaitForChild("TrainState"))

local RunTracker = {}
RunTracker.__index = RunTracker

export type Event = { kind: "pass" | "hit", index: number, distance: number }

type Fields = {
	locomotive: Model,
	front: number, -- the locomotive's ends in its own Z (Names.SpanFront/SpanBack)
	back: number,
	run: CourseMath.Run?, -- nil until the server starts the run
	next: number?, -- own locomotive: the bridge waiting to be decided (nil = find it from the distance)
	held: number?, -- the distance held after a local hit
	heldIndex: number, -- the bridge of that hit
	heldUntil: number,
	waiting: boolean, -- after a local hit: no more judging until the server's run changes
	connection: RBXScriptConnection,
}
export type Tracker = typeof(setmetatable({} :: Fields, RunTracker))

local function readRun(locomotive: Model): CourseMath.Run?
	return (TrainState.run(locomotive))
end

function RunTracker.new(locomotive: Model): Tracker
	local fields: Fields = {
		locomotive = locomotive,
		front = PartUtil.number(locomotive, Names.SpanFront) or 0,
		back = PartUtil.number(locomotive, Names.SpanBack) or 0,
		run = readRun(locomotive),
		next = nil,
		held = nil,
		heldIndex = 0,
		heldUntil = 0,
		waiting = false,
		connection = nil :: any,
	}
	local self = setmetatable(fields, RunTracker)
	-- The server writes the three run values, then bumps the version: reading on the version sees all three new.
	self.connection = locomotive:GetAttributeChangedSignal(Names.RunVersion):Connect(function()
		self.run = readRun(locomotive)
		self.next = nil
		self.held = nil
		self.waiting = false
	end)
	return self
end

-- Run distance at server time `now`; nil before the server has started the run.
function RunTracker.distance(self: Tracker, now: number): number?
	local held = self.held
	if held and now < self.heldUntil then
		return held
	end
	if held and self.waiting then
		-- The server never sent a crash for our hit (it judged that bridge already): carry on from the next one.
		self.waiting = false
		self.next = self.heldIndex + 1
	end
	self.held = nil
	local run = self.run
	return if run then CourseMath.distance(run, now) else nil
end

-- How fast the world moves past the locomotive right now (0 while held, crashed or waiting to start; nil before the
-- server has set up the run at all).
function RunTracker.speed(self: Tracker, now: number): number?
	local run = self.run
	if not run then
		return nil
	end
	if self.held or now < run.start then
		return 0
	end
	return run.speed
end

-- Own locomotive only, every frame after the animator: the bridge just decided, if any. `top` is the locomotive's
-- current height above the rails.
function RunTracker.judge(self: Tracker, now: number, top: number): Event?
	local run = self.run
	if not run or run.speed <= 0 or self.waiting then
		return nil
	end
	local b = Config.Bridge
	local distance = CourseMath.distance(run, now)
	local index = self.next or CourseMath.nextBridge(distance, b.FirstAt, b.Gaps, b.Depth, self.back)
	self.next = index
	local enter, exit = CourseMath.under(CourseMath.bridgeAt(index, b.FirstAt, b.Gaps), b.Depth, self.front, self.back)
	if distance >= enter and distance <= exit and top > b.Clearance then
		self.waiting = true
		self.held = distance
		self.heldIndex = index
		self.heldUntil = now + Config.Run.HoldSeconds
		return { kind = "hit", index = index, distance = distance }
	elseif distance > exit then
		self.next = index + 1
		return { kind = "pass", index = index, distance = distance }
	end
	return nil
end

function RunTracker.destroy(self: Tracker)
	self.connection:Disconnect()
end

return RunTracker
