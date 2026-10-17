--!strict
-- Chairs around the pool: seat participants, keep them seated during a round, and launch the loser into the pool.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local SeatService = {}

local DEFAULT_JUMP_HEIGHT = 7.2

local assigned: { [Seat]: Humanoid } = {}
local locked = false

local function poolMap(): Folder
	return workspace:WaitForChild("PoolMap") :: Folder
end

function SeatService.getSeats(): { Seat }
	local seats = {}
	for _, chair in poolMap():WaitForChild("Chairs"):GetChildren() do
		local seat = chair:FindFirstChildWhichIsA("Seat")
		if seat then
			table.insert(seats, seat)
		end
	end
	-- Middle chairs first, so a small group still sits in the centre of the show camera.
	local middle = (#seats + 1) / 2
	local function rank(seat: Seat): number
		local index = seat:GetAttribute("SeatIndex") or 0
		return math.abs(index - middle) * 2 + (if index < middle then 0 else 1)
	end
	table.sort(seats, function(a, b)
		return rank(a) < rank(b)
	end)
	return seats
end

function SeatService.poolCenter(): Vector3
	local marker = poolMap():FindFirstChild("PoolCenter") :: BasePart?
	return if marker then marker.Position else Vector3.new(0, -1, 0)
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

local function guestSeat(): Seat?
	local raft = poolMap():FindFirstChild("GuestRaft")
	return raft and raft:FindFirstChild("GuestSeat") :: Seat?
end

-- The guest raft only shows up in talk-show rounds (in classic it would block the show camera's lower centre).
function SeatService.setGuestRaftVisible(visible: boolean)
	local raft = poolMap():FindFirstChild("GuestRaft")
	if not raft then
		return
	end
	for _, part in raft:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if visible then 0 else 1
			part.CanCollide = visible
			part.CanQuery = visible
		end
	end
end

function SeatService.init()
	for _, seat in SeatService.getSeats() do
		seat.Disabled = true
		watch(seat)
	end
	local guest = guestSeat()
	if guest then
		guest.Disabled = true
		watch(guest)
	end
	SeatService.setGuestRaftVisible(false)
end

-- Talk-show mode: the guest sits on the raft facing the panel.
function SeatService.seatGuest(player: Player): boolean
	local seat = guestSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (seat and humanoid and humanoid.Health > 0) then
		return false
	end
	SeatService.setGuestRaftVisible(true)
	assigned[seat] = humanoid
	seat.Disabled = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	sit(seat, humanoid)
	locked = true
	return true
end

-- Returns the seat per player (players beyond the chair count are left out by the caller).
function SeatService.seatPlayers(players: { Player }): { [Player]: Seat }
	local seats = SeatService.getSeats()
	local result: { [Player]: Seat } = {}
	for i, player in players do
		local seat = seats[i]
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
	SeatService.setGuestRaftVisible(false)
end

-- Throws the player from their chair in an arc into the pool, then kills them.
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
		-- Straight ahead from the chair row into the pool, so the show camera sees the whole flight.
		local start = root.Position
		local center = SeatService.poolCenter()
		-- Keep the landing well inside the water (pool half-width 22, end chairs sit at x = +-22.5).
		local landingX = math.clamp(start.X + math.random(-3, 3), center.X - 17, center.X + 17)
		local target = Vector3.new(landingX, center.Y, center.Z + math.random(-4, 4))
		local t = Config.LAUNCH_FLIGHT_TIME
		local g = workspace.Gravity
		local horizontal = Vector3.new(target.X - start.X, 0, target.Z - start.Z) / t
		local vertical = (target.Y - start.Y + 0.5 * g * t * t) / t
		root.AssemblyLinearVelocity = horizontal + Vector3.new(0, vertical, 0)
		root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		task.wait(Config.DEATH_DELAY)
		if humanoid.Parent then
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
