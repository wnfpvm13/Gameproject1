--!strict
-- Flying chairs in a row at the near edge of the pool (docs/DESIGN_V3.md §9-10): seat the players of a round in the
-- middle chairs, keep them seated, and launch a failed player. A launch is an explosion in front of the chair (owner
-- 2026-10-24: no flight path, the blast's force): the character turns into a ragdoll and the blast throws it backward
-- and up, anywhere behind or beside the chair (owner 2026-10-25: faster, harder, unpredictable), and physics does the
-- rest. The clients draw the explosion, the seat
-- flap snapping back and the splash from the "Fling" / "Splash" signals. SeatService only says when the player is due
-- back (FLING_RETURN_SECONDS after the launch, with the character that flew); RoundService then calls endFling() and
-- picks reseat() or the stands. Since 2026-10-24 a launch may wait its turn in a chain (fling's `delay`) and reports
-- where it first came down (onLanded, for the round's flight record).
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
-- Every character's parts (2026-10-25): a flying body passes through people — seated players and spectators in the
-- stands are not pushed by a 200 studs/s throw (Codex 9a) — but still hits the walls, the floor and the water.
local CHARACTER_GROUP = "BW_Characters"

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
	launched: boolean, -- false while it waits for its turn in a chain (still seated, nothing changed yet)
}

local rng = Random.new()
local assigned: { [Seat]: Humanoid } = {}
local homeSeat: { [Player]: Seat } = {}
local locked = false
local flights: { [Player]: Flight } = {}
local nextToken = 0
local returnDue: ((Player, any, Model) -> ())? = nil
local landed: ((Player, number, number) -> ())? = nil

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

-- (Not for a body that died or left the world meanwhile: Seat:Sit errors on it, seen in the owner's test 2026-10-25.)
local function sit(seat: Seat, humanoid: Humanoid)
	local character = humanoid.Parent
	if humanoid.Health <= 0 or not character or not character:IsA("Model") or not character:IsDescendantOf(workspace) then
		return
	end
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
-- character = the one that flew). onLanded(player, distance, airTime): where a flight first came down (studs from
-- the chair along the ground, seconds in the air; the round's flight record, owner 2026-10-24).
function SeatService.init(onReturnDue: (Player, any, Model) -> (), onLanded: ((Player, number, number) -> ())?)
	returnDue = onReturnDue
	landed = onLanded
	PhysicsService:RegisterCollisionGroup(FLYING_GROUP)
	PhysicsService:RegisterCollisionGroup(CHAIR_GROUP)
	PhysicsService:CollisionGroupSetCollidable(FLYING_GROUP, FLYING_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(FLYING_GROUP, CHAIR_GROUP, false)
	PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(FLYING_GROUP, CHARACTER_GROUP, false)
	local function grouped(character: Model)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = CHARACTER_GROUP
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and d.CollisionGroup ~= FLYING_GROUP then
				d.CollisionGroup = CHARACTER_GROUP
			end
		end)
	end
	local function watchCharacters(player: Player)
		if player.Character then
			grouped(player.Character)
		end
		player.CharacterAdded:Connect(grouped)
	end
	for _, player in Players:GetPlayers() do
		watchCharacters(player)
	end
	Players.PlayerAdded:Connect(watchCharacters)
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

-- Seats n players in the middle n chairs (the show camera frames them, client ShowCamera). Returns the seat per player.
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

-- The chair number (SeatIndex, 1..10 from the show camera's left) a player sits on this round, or nil.
function SeatService.seatIndexOf(player: Player): number?
	local seat = homeSeat[player]
	return if seat then seat:GetAttribute("SeatIndex") :: number? else nil
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

-- The blast's push: backward from the chair (the chairs face away from the pool) and up, turned at random up to
-- BLAST_SPREAD to either side, so no two launches look alike. A speed, not an aim: where the body comes down is up to
-- physics (owner 2026-10-25: faster and anywhere; it may bounce off the walls and the ceiling and land outside the
-- pool; it is back on the chair FLING_RETURN_SECONDS after the launch anyway).
local function blastVelocity(seat: Seat): Vector3
	local back = -seat.CFrame.LookVector
	back = Vector3.new(back.X, 0, back.Z).Unit
	local pitch = math.rad(rng:NextNumber(Config.BLAST_PITCH_MIN, Config.BLAST_PITCH_MAX))
	local yaw = math.rad(rng:NextNumber(-Config.BLAST_SPREAD, Config.BLAST_SPREAD))
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
-- `tag` comes back with the return signal (RoundService passes the round id). `delay`: the blast goes off this many
-- seconds later (chain explosions, owner 2026-10-24) — the player counts as flying from now on, so nothing else can
-- hit them meanwhile; a death, a new character or the end of the round meanwhile calls it off with the chair
-- untouched. `size`: how big the clients draw the blast (1 = normal). Returns whether a launch started (or waits).
function SeatService.fling(player: Player, tag: any, delay: number?, size: number?): boolean
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
		launched = false,
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
	table.insert(flight.watches, player:GetPropertyChangedSignal("Character"):Connect(abandon))
	local function launch()
		if flights[player] ~= flight then
			return -- (undone while waiting for its turn in a chain)
		end
		-- (still the same body, alive, on the chair we gave it: else the waiting launch is off)
		if player.Character ~= character or humanoid.Health <= 0 or assigned[seat :: Seat] ~= humanoid then
			abandon()
			return
		end
		flight.launched = true
		local chair = seat :: Seat
		if assigned[chair] == humanoid then
			assigned[chair] = nil
		end
		local seatIndex = chair:GetAttribute("SeatIndex") :: number?
		chair.Disabled = true
		-- The seat weld must be gone before the impulse (and before taking ownership: a body welded to an anchored
		-- seat is part of an anchored assembly).
		local weld = chair:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
		ragdoll(flight, root)
		setOwner(root, nil)
		-- The blast goes off just in front of the seated body, low (the clients draw it there).
		local from = root.Position
		local blastAt = from + chair.CFrame.LookVector * Config.BLAST_FORWARD - Vector3.yAxis * Config.BLAST_BELOW
		Net.toAll("Fling", { userId = player.UserId, seatIndex = seatIndex, blastAt = blastAt, size = size or 1 })
		task.spawn(function()
			-- The throw waits one frame: the humanoid must already be PlatformStanding, or its walking controller
			-- brakes the first step (Studio test 2026-10-22: ~6 studs/s of the horizontal speed lost).
			RunService.Heartbeat:Wait()
			if flights[player] ~= flight then
				return
			end
			local velocity = blastVelocity(chair)
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
		task.spawn(function()
			-- Where it first comes down: the water over the pool (a splash), or anywhere it stops falling after
			-- FLIGHT_SETTLE_SECONDS (the deck) — the flight record, once. The depth watch goes on until the flight
			-- ends (a body may still roll through a wall after it came down, Codex 9a re-check).
			local water = waterY()
			local started = os.clock()
			local recorded = false
			while flights[player] == flight and os.clock() - started < Config.FLING_RETURN_SECONDS do
				if root.Parent and root.Position.Y < water - Config.FLIGHT_LOST_DEPTH then
					-- (out of the hall after all — through a thin wall or the floor: back over the pool, not into the
					-- void, where the body would be destroyed and the player respawn)
					local landing = landingZone()
					local body = root.Parent
					if landing and body and body:IsA("Model") then
						for part in flight.parts do
							part.AssemblyLinearVelocity = Vector3.zero
							part.AssemblyAngularVelocity = Vector3.zero
						end
						body:PivotTo(CFrame.new(landing.Position + Vector3.new(0, Config.FLIGHT_LOST_DROP, 0)))
					end
				end
				if root.Parent and not recorded then
					local inWater = root.Position.Y < water + 1.5 and overPool(root.Position)
					local stopped = os.clock() - started > Config.FLIGHT_SETTLE_SECONDS
						and root.AssemblyLinearVelocity.Magnitude < Config.FLIGHT_STOPPED_SPEED
					if inWater or stopped then
						if inWater then
							Net.toAll("Splash", { userId = player.UserId, position = Vector3.new(root.Position.X, water, root.Position.Z) })
						end
						if landed then
							local flat = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
							landed(player, flat.Magnitude, os.clock() - started)
						end
						recorded = true
					end
				end
				RunService.Heartbeat:Wait()
			end
		end)
		local token = flight.token
		task.delay(Config.FLING_RETURN_SECONDS, function()
			local current = flights[player]
			if current and current.token == token and returnDue then
				returnDue(player, tag, character)
			end
		end)
	end
	if delay and delay > 0 then
		task.delay(delay, launch)
	else
		launch()
	end
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
	if not flight.launched then
		return -- (it never left the chair: nothing to undo)
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
