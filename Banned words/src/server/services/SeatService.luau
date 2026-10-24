--!strict
-- Flying chairs in a row at the near edge of the pool (docs/DESIGN_V3.md §9-10): seat the players of a round in the
-- middle chairs, keep them seated, and launch a failed player. A launch is an explosion in front of the chair (owner
-- 2026-10-24: no flight path, the blast's force): the character turns into a ragdoll and the blast throws it backward
-- over the pool, a little differently each time, and physics does the rest. The clients draw the explosion, the seat
-- flap snapping back and the splash from the "Fling" / "Splash" signals. SeatService only says when the player is due
-- back (FLING_RETURN_SECONDS after the launch, with the character that flew); RoundService then calls endFling() and
-- picks reseat() or the stands.
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

local function landingZone(): BasePart?
	return hall():FindFirstChild("Landing") :: BasePart?
end

-- The water level of the pool (for the splash).
local function waterY(): number
	local landing = landingZone()
	return if landing then (landing:GetAttribute("WaterY") or landing.Position.Y) :: number else 0
end

-- The farthest a blast carries a body over flat ground (the fastest speed at the pitch, within the range, that goes
-- farthest); a little more from the seat's height.
local function farthest(): number
	local best = 0
	for _, degrees in { Config.BLAST_PITCH_MIN, Config.BLAST_PITCH_MAX } do
		best = math.max(best, math.sin(2 * math.rad(degrees)))
	end
	return Config.BLAST_SPEED_MAX ^ 2 / workspace.Gravity * best
end

-- The blast's push: backward from the chair (the chairs face away from the pool) and up, turned a little at random so
-- no two launches look alike. A speed, not an aim: where the body comes down is up to physics. Sideways it is kept
-- so that even the farthest throw stays above the landing zone's width (the end chairs only fly straight or inward;
-- 15 degrees either way took their players onto the deck beside the pool).
local function blastVelocity(seat: Seat): Vector3
	local back = -seat.CFrame.LookVector
	back = Vector3.new(back.X, 0, back.Z).Unit
	local side = Vector3.new(back.Z, 0, -back.X) -- (up x back: positive yaw turns `back` toward this)
	local spread = math.sin(math.rad(Config.BLAST_SPREAD))
	local low, high = -spread, spread
	local landing = landingZone()
	if landing then
		local offset = (seat.Position - landing.Position):Dot(side) -- the seat's distance from the zone's middle line
		local half = math.abs(landing.CFrame.RightVector:Dot(side)) * landing.Size.X / 2
			+ math.abs(landing.CFrame.LookVector:Dot(side)) * landing.Size.Z / 2
		local reach = farthest()
		low = math.max(low, math.clamp((-half - offset) / reach, -1, 1))
		high = math.min(high, math.clamp((half - offset) / reach, -1, 1))
		if low > high then
			low, high = 0, 0
		end
	end
	local pitch = math.rad(rng:NextNumber(Config.BLAST_PITCH_MIN, Config.BLAST_PITCH_MAX))
	local yaw = math.asin(rng:NextNumber(low, high))
	local direction = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(back) * math.cos(pitch)
		+ Vector3.yAxis * math.sin(pitch)
	return direction * rng:NextNumber(Config.BLAST_SPEED_MIN, Config.BLAST_SPEED_MAX)
end

-- Whether a point is over the pool (the splash): within the landing zone's width plus the attribute PoolMargin (the
-- pool is that much wider on each side, map contract) and not in front of the chairs.
local function overPool(position: Vector3): boolean
	local landing = landingZone()
	if not landing then
		return true
	end
	local margin = (landing:GetAttribute("PoolMargin") or 0) :: number
	local localPoint = landing.CFrame:PointToObjectSpace(position)
	return math.abs(localPoint.X) <= landing.Size.X / 2 + margin
end

-- A random tumble (the blast hits the body unevenly).
local function blastSpin(): Vector3
	local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return (if axis.Magnitude > 0.1 then axis.Unit else Vector3.xAxis) * Config.BLAST_SPIN
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
	-- The blast goes off just in front of the seated body, low (the clients draw it there).
	local blastAt = root.Position + seat.CFrame.LookVector * Config.BLAST_FORWARD - Vector3.yAxis * Config.BLAST_BELOW
	Net.toAll("Fling", { userId = player.UserId, seatIndex = seatIndex, blastAt = blastAt })
	task.spawn(function()
		-- The throw waits one frame: the humanoid must already be PlatformStanding, or its walking controller brakes
		-- the first step (Studio test 2026-10-22: ~6 studs/s of the horizontal speed lost).
		RunService.Heartbeat:Wait()
		if flights[player] ~= flight then
			return
		end
		local velocity = blastVelocity(seat :: Seat)
		local spin = blastSpin()
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
		-- The splash: the first moment the body comes down to the water, over the pool, after leaving the chair.
		local water = waterY()
		local started = os.clock()
		while flights[player] == flight and os.clock() - started < Config.FLING_RETURN_SECONDS do
			if root.Parent and root.Position.Y < water + 1.5 and overPool(root.Position) then
				Net.toAll("Splash", { userId = player.UserId, position = Vector3.new(root.Position.X, water, root.Position.Z) })
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
