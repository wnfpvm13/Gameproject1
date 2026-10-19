--!strict
-- Chairs in a ring around the lounge centre: seat participants (spread evenly), keep them seated during a round,
-- and launch whoever says a word: up and outward over the ring, then "펑" (hidden + killed at the top of the arc).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local SeatService = {}

local DEFAULT_JUMP_HEIGHT = 7.2
local LAUNCH_UP = 80 -- studs/s upward (top of the arc after ~0.4 s, about 16 studs high)
local LAUNCH_OUT = 16 -- studs/s away from the centre

local assigned: { [Seat]: Humanoid } = {}
local locked = false

local function map(): Instance
	return workspace:WaitForChild("LoungeMap")
end

-- Seats ordered by SeatIndex (1..N clockwise around the ring).
function SeatService.getSeats(): { Seat }
	local seats = {}
	for _, chair in map():WaitForChild("Chairs"):GetChildren() do
		local seat = chair:FindFirstChildWhichIsA("Seat")
		if seat then
			table.insert(seats, seat)
		end
	end
	table.sort(seats, function(a, b)
		return (a:GetAttribute("SeatIndex") or 0) < (b:GetAttribute("SeatIndex") or 0)
	end)
	return seats
end

function SeatService.center(): Vector3
	local marker = map():FindFirstChild("Center") :: BasePart?
	return if marker then marker.Position else Vector3.zero
end

local function sit(seat: Seat, humanoid: Humanoid)
	local character = humanoid.Parent :: Model
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
end

-- Only the assigned humanoid may occupy a chair; anyone else is ejected, and a locked participant is re-seated.
local function watch(seat: Seat)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local owner = assigned[seat]
		if occupant and occupant ~= owner then
			occupant.Sit = false
		elseif not occupant and owner and locked and owner.Health > 0 then
			task.defer(function()
				if assigned[seat] == owner and locked and owner.Parent then
					sit(seat, owner)
				end
			end)
		end
	end)
end

function SeatService.init()
	for _, seat in SeatService.getSeats() do
		seat.Disabled = true
		watch(seat)
	end
end

-- Spread n players evenly around the ring (2 players sit opposite each other). Returns the seat per player.
function SeatService.seatPlayers(players: { Player }): { [Player]: Seat }
	local seats = SeatService.getSeats()
	local result: { [Player]: Seat } = {}
	local n = math.min(#players, #seats)
	for i = 1, n do
		local player = players[i]
		local seat = seats[math.floor((i - 1) * #seats / n) + 1]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if seat and humanoid and humanoid.Health > 0 then
			assigned[seat] = humanoid
			seat.Disabled = false
			humanoid.UseJumpPower = false
			humanoid.JumpHeight = 0
			sit(seat, humanoid)
			result[player] = seat
		end
	end
	locked = true
	return result
end

function SeatService.releaseAll()
	locked = false
	for seat, humanoid in assigned do
		if humanoid.Parent then
			humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
			humanoid.Sit = false
		end
		seat.Disabled = true
	end
	table.clear(assigned)
end

local function hide(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

-- Up and outward from the chair; at LAUNCH_POP_TIME the body vanishes (clients play the "펑") and dies.
function SeatService.launch(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root) then
		return
	end
	for seat, owner in assigned do
		if owner == humanoid then
			assigned[seat] = nil
			seat.Disabled = true
			-- The seat weld must be gone before the impulse, or the chair absorbs most of it.
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
	end
	humanoid.Sit = false
	humanoid.PlatformStand = true
	root:SetNetworkOwner(nil)

	task.spawn(function()
		RunService.Heartbeat:Wait()
		local outward = root.Position - SeatService.center()
		outward = Vector3.new(outward.X, 0, outward.Z)
		outward = if outward.Magnitude > 0.1 then outward.Unit else Vector3.new(0, 0, 1)
		root.AssemblyLinearVelocity = outward * LAUNCH_OUT + Vector3.new(0, LAUNCH_UP, 0)
		root.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		task.wait(Config.LAUNCH_POP_TIME)
		if humanoid.Parent then
			root.Anchored = true
			hide(character)
			humanoid.Health = 0
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	for seat, humanoid in assigned do
		if humanoid.Parent == player.Character then
			assigned[seat] = nil
			seat.Disabled = true
		end
	end
end)

return SeatService
