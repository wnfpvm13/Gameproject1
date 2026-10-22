--!strict
-- Flying chairs in a row at the near edge of the pool (docs/DESIGN_V3.md §9-10): seat the players of a round in the
-- middle chairs, keep them seated, and launch a failed player. A launch turns the character into a ragdoll and throws
-- it far into the pool's landing zone; the clients draw the seat flap snapping back, the bang and the splash from the
-- "Fling" / "Splash" signals. SeatService only says when the player is due back (FLING_RETURN_SECONDS after the
-- launch, with the character that flew); RoundService then calls endFling() and picks reseat() or the stands.
-- A flight whose character dies or leaves the world is undone at once and never comes back.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local SeatService = {}

local DEFAULT_JUMP_HEIGHT = 7.2
local FLYING_GROUP = "BW_Flying" -- flying bodies: no chairs, no other flying bodies, no own limbs
local CHAIR_GROUP = "BW_Chairs"

type Flight = {
	character: Model,
	humanoid: Humanoid,
	token: number,
	requiresNeck: boolean,
	breakJoints: boolean,
	motors: { Motor6D },
	added: { Instance }, -- ragdoll attachments and sockets
	parts: { [BasePart]: { group: string, collide: boolean, physics: PhysicalProperties? } },
	body: { BasePart }, -- body parts that collide once the body is off the chair
	watches: { RBXScriptConnection }, -- the character dying or leaving undoes the flight
}

local rng = Random.new()
local assigned: { [Seat]: Humanoid } = {}
local homeSeat: { [Player]: Seat } = {}
local locked = false
local flights: { [Player]: Flight } = {}
local nextToken = 0
local returnDue: ((Player, any, Model) -> ())? = nil

local function hall(): Instance
	return workspace:WaitForChild("PoolHall")
end

-- Seats ordered by SeatIndex (1..10 from the show camera's left).
function SeatService.getSeats(): { Seat }
	local seats = {}
	for _, chair in hall():WaitForChild("Chairs"):GetChildren() do
		local seat = chair:FindFirstChild("Seat")
		if seat and seat:IsA("Seat") then
			table.insert(seats, seat)
		end
	end
	table.sort(seats, function(a, b)
		return (a:GetAttribute("SeatIndex") or 0) < (b:GetAttribute("SeatIndex") or 0)
	end)
	return seats
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

-- returnDue(player, tag, character): FLING_RETURN_SECONDS after a launch (tag = what the caller passed to fling,
-- character = the one that flew).
function SeatService.init(onReturnDue: (Player, any, Model) -> ())
	returnDue = onReturnDue
	PhysicsService:RegisterCollisionGroup(FLYING_GROUP)
	PhysicsService:RegisterCollisionGroup(CHAIR_GROUP)
	PhysicsService:CollisionGroupSetCollidable(FLYING_GROUP, FLYING_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(FLYING_GROUP, CHAIR_GROUP, false)
	for _, chair in hall():WaitForChild("Chairs"):GetChildren() do
		for _, d in chair:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = CHAIR_GROUP
			end
		end
	end
	for _, seat in SeatService.getSeats() do
		seat.Disabled = true
		watch(seat)
	end
end

local function lockJump(humanoid: Humanoid, on: boolean)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if on then 0 else DEFAULT_JUMP_HEIGHT
end

-- Seats n players in the middle n chairs (the show camera always frames the whole row). Returns the seat per player.
function SeatService.seatPlayers(players: { Player }): { [Player]: Seat }
	local seats = SeatService.getSeats()
	local result: { [Player]: Seat } = {}
	local n = math.min(#players, #seats)
	local first = math.floor((#seats - n) / 2) + 1
	for i = 1, n do
		local player = players[i]
		local seat = seats[first + i - 1]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if seat and humanoid and humanoid.Health > 0 then
			assigned[seat] = humanoid
			homeSeat[player] = seat
			seat.Disabled = false
			lockJump(humanoid, true)
			sit(seat, humanoid)
			result[player] = seat
		end
	end
	locked = true
	return result
end

function SeatService.isFlying(player: Player): boolean
	return flights[player] ~= nil
end

function SeatService.anyFlying(): boolean
	return next(flights) ~= nil
end

local function isRootJoint(motor: Motor6D, root: BasePart): boolean
	return motor.Part0 == root or motor.Part1 == root
end

-- Ragdoll (docs/DESIGN_V3.md §10 step 1): no death on a loose neck, PlatformStand (replicates), every joint but the
-- root one swapped for a ball socket, body parts colliding with the pool but not with chairs or each other, and
-- light enough to float on the water where it lands (Studio test 2026-10-22: avatars sank to the pool floor).
local function ragdoll(flight: Flight, root: BasePart)
	local character, humanoid = flight.character, flight.humanoid
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.PlatformStand = true
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Enabled and motor.Part0 and motor.Part1 and not isRootJoint(motor, root) then
			local a0 = Instance.new("Attachment")
			a0.Name = "BW_RagdollA"
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "BW_RagdollB"
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "BW_RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = 70
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -60
			socket.TwistUpperAngle = 60
			socket.Parent = motor.Part0
			table.insert(flight.added, a0)
			table.insert(flight.added, a1)
			table.insert(flight.added, socket)
			motor.Enabled = false
			table.insert(flight.motors, motor)
		end
	end
	local float = PhysicalProperties.new(Config.FLING_FLOAT_DENSITY, 0.3, 0.2)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			flight.parts[part] = { group = part.CollisionGroup, collide = part.CanCollide, physics = part.CustomPhysicalProperties }
			part.CollisionGroup = FLYING_GROUP
			if part.Parent == character then
				part.CustomPhysicalProperties = float
				-- Body parts must hit the pool floor and walls (from FLING_COLLIDE_DELAY on); accessories and the
				-- root box stay soft.
				if part ~= root then
					table.insert(flight.body, part)
				end
			end
		end
	end
end

-- A random point on the water of the landing zone (several flying players land apart).
local function landingTarget(): Vector3
	local landing = hall():WaitForChild("Landing") :: BasePart
	local waterY = (landing:GetAttribute("WaterY") or landing.Position.Y) :: number
	local half = landing.Size / 2
	return Vector3.new(
		landing.Position.X + rng:NextNumber(-half.X, half.X),
		waterY,
		landing.Position.Z + rng:NextNumber(-half.Z, half.Z)
	)
end

-- Initial velocity of a ballistic arc from `from` to `target` whose top (plus the body's own height) stays under the
-- hall's CeilingY. Returns the velocity and the flight time. (The arc always rises at least 4 studs: only a seat
-- higher than CeilingY - FLING_BODY_TOP - 4 could break the ceiling rule, which no chair of the map is.)
local function arcVelocity(from: Vector3, target: Vector3): (Vector3, number)
	local ceiling = (hall():GetAttribute("CeilingY") or 40) :: number
	local gravity = workspace.Gravity
	local apexY = math.max(from.Y + 4, math.min(from.Y + Config.FLING_APEX_HEIGHT, ceiling - Config.FLING_BODY_TOP))
	local up = math.sqrt(2 * gravity * (apexY - from.Y))
	local flightTime = up / gravity + math.sqrt(2 * (apexY - target.Y) / gravity)
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	return flat / flightTime + Vector3.new(0, up, 0), flightTime
end

local function setOwner(root: BasePart, owner: Player?)
	local ok, why = root:CanSetNetworkOwnership()
	if ok then
		root:SetNetworkOwner(owner)
	else
		warn("[BannedWords] flying chair: cannot set network ownership:", why)
	end
end

-- Launches a player off their chair (no-op unless they are alive, seated on a chair we gave them and not flying).
-- `tag` comes back with the return signal (RoundService passes the round id). Returns whether a launch started.
function SeatService.fling(player: Player, tag: any): boolean
	if flights[player] then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root and humanoid.Health > 0) then
		return false
	end
	local seat: Seat? = nil
	for candidate, owner in assigned do
		if owner == humanoid then
			seat = candidate
		end
	end
	if not seat then
		return false
	end
	assigned[seat] = nil
	local seatIndex = seat:GetAttribute("SeatIndex") :: number?
	seat.Disabled = true
	-- The seat weld must be gone before the impulse (and before taking ownership: a body welded to an anchored seat
	-- is part of an anchored assembly).
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	humanoid.Sit = false
	nextToken += 1
	local flight: Flight = {
		character = character,
		humanoid = humanoid,
		token = nextToken,
		requiresNeck = humanoid.RequiresNeck,
		breakJoints = humanoid.BreakJointsOnDeath,
		motors = {},
		added = {},
		parts = {},
		body = {},
		watches = {},
	}
	flights[player] = flight
	-- A death or a character leaving the world (reset, respawn, removal) undoes the flight right away, so the return
	-- signal can never move the next character.
	local function abandon()
		if flights[player] == flight then
			SeatService.endFling(player)
		end
	end
	table.insert(flight.watches, humanoid.Died:Connect(abandon))
	table.insert(flight.watches, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			abandon()
		end
	end))
	ragdoll(flight, root)
	setOwner(root, nil)
	local landAt = landingTarget()
	local _, flightTime = arcVelocity(root.Position, landAt)
	Net.toAll("Fling", { userId = player.UserId, seatIndex = seatIndex, flightTime = flightTime, landAt = landAt })
	task.spawn(function()
		-- The throw waits one frame: the humanoid must already be PlatformStanding, or its walking controller brakes
		-- the first step (Studio test 2026-10-22: ~6 studs/s of the horizontal speed lost, landings 5 studs short).
		RunService.Heartbeat:Wait()
		if flights[player] ~= flight then
			return
		end
		local velocity = arcVelocity(root.Position, landAt)
		-- A backflip: about the seated body's right axis, head going back toward the pool (like the flap).
		local spin = root.CFrame.RightVector * Config.FLING_SPIN
		for part in flight.parts do
			if not part.Anchored then
				part.AssemblyLinearVelocity = velocity
				part.AssemblyAngularVelocity = spin
			end
		end
	end)
	task.delay(Config.FLING_COLLIDE_DELAY, function()
		if flights[player] == flight then
			for _, part in flight.body do
				part.CanCollide = true
			end
		end
	end)

	local token = flight.token
	task.spawn(function()
		-- The splash: the first moment the body reaches the water after leaving the chair.
		local waterY = landAt.Y
		local started = os.clock()
		while flights[player] == flight and os.clock() - started < Config.FLING_RETURN_SECONDS do
			if os.clock() - started > flightTime * 0.5 and root.Parent and root.Position.Y < waterY + 1.5 then
				Net.toAll("Splash", { userId = player.UserId, position = Vector3.new(root.Position.X, waterY, root.Position.Z) })
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	task.delay(Config.FLING_RETURN_SECONDS, function()
		local current = flights[player]
		if current and current.token == token and returnDue then
			returnDue(player, tag, character)
		end
	end)
	return true
end

-- Undoes a launch (docs/DESIGN_V3.md §10 step 5): joints back (neck first), no leftover speed, collisions and humanoid
-- settings back (jumping too: a player sent to the stands must be able to climb), network ownership back to the
-- player while the body is still free. The caller then reseats the player or moves them. Safe to call when the
-- player is not flying.
function SeatService.endFling(player: Player)
	local flight = flights[player]
	if not flight then
		return
	end
	flights[player] = nil
	for _, connection in flight.watches do
		connection:Disconnect()
	end
	local character, humanoid = flight.character, flight.humanoid
	table.sort(flight.motors, function(a, b)
		return a.Name == "Neck" and b.Name ~= "Neck"
	end)
	for _, motor in flight.motors do
		if motor.Parent then
			motor.Enabled = true
		end
	end
	for _, instance in flight.added do
		instance:Destroy()
	end
	for part, saved in flight.parts do
		if part.Parent then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CollisionGroup = saved.group
			part.CanCollide = saved.collide
			-- nil puts the material's own physics back; the API type does not allow nil, hence the cast.
			local untyped: any = part
			untyped.CustomPhysicalProperties = saved.physics
		end
	end
	if humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid.RequiresNeck = flight.requiresNeck
		humanoid.BreakJointsOnDeath = flight.breakJoints
		lockJump(humanoid, false) -- reseat() locks it again
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and player.Parent and player.Character == character and character:IsDescendantOf(workspace) then
		setOwner(root, player)
	end
end

-- Puts a player back on the chair they had this round (after endFling) and locks it again.
function SeatService.reseat(player: Player): boolean
	local seat = homeSeat[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (seat and humanoid and humanoid.Health > 0) or flights[player] then
		return false
	end
	assigned[seat] = humanoid
	seat.Disabled = false
	lockJump(humanoid, true)
	sit(seat, humanoid)
	return true
end

-- Round over: every flight undone, everyone off the chairs, jumping back on.
function SeatService.releaseAll()
	locked = false
	for player in flights do
		SeatService.endFling(player)
	end
	for seat, humanoid in assigned do
		if humanoid.Parent then
			humanoid.Sit = false
		end
		seat.Disabled = true
	end
	for player in homeSeat do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lockJump(humanoid, false)
		end
	end
	table.clear(assigned)
	table.clear(homeSeat)
end

Players.PlayerRemoving:Connect(function(player)
	SeatService.endFling(player)
	homeSeat[player] = nil
	for seat, humanoid in assigned do
		if humanoid.Parent == player.Character then
			assigned[seat] = nil
			seat.Disabled = true
		end
	end
end)

return SeatService
