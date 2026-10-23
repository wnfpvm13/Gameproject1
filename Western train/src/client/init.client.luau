--!strict
-- Western train client entry point (squash prototype): only wiring. Every locomotive gets an animator and a steam
-- puff; the player's own locomotive follows the squash key at once (and tells the server), other locomotives follow
-- their Squashed attribute.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Names = require(shared:WaitForChild("Names"))
local LocomotiveAnimator = require(script:WaitForChild("LocomotiveAnimator"))
local SquashInput = require(script:WaitForChild("SquashInput"))
local SteamPuff = require(script:WaitForChild("SteamPuff"))
local DriverCamera = require(script:WaitForChild("DriverCamera"))

local player = Players.LocalPlayer
local remote = shared:WaitForChild(Names.RemotesFolder):WaitForChild(Names.SquashRemote) :: RemoteEvent

type Tracked = {
	animator: LocomotiveAnimator.Animator,
	puff: SteamPuff.Puff?,
	squashed: boolean,
	connection: RBXScriptConnection?, -- following the Squashed attribute (other players' locomotives)
}
local tracked: { [Model]: Tracked } = {}
local mine: Model? = nil
local inputDown = false -- still held when a new locomotive arrives (respawn), so it starts flat

local function setSquashed(locomotive: Model, squashed: boolean)
	local entry = tracked[locomotive]
	if not entry or entry.squashed == squashed then
		return
	end
	entry.squashed = squashed
	entry.animator:setTarget(squashed)
	if entry.puff then
		entry.puff:burst()
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local locomotive = instance
	locomotive:WaitForChild(Names.BasePart, 10)
	if tracked[locomotive] or not locomotive.Parent or not CollectionService:HasTag(locomotive, Names.LocomotiveTag) then
		return -- tracked meanwhile by a second signal, or gone / untagged while waiting
	end
	local animator = LocomotiveAnimator.new(locomotive)
	if not animator then
		return
	end
	local entry: Tracked = { animator = animator, puff = SteamPuff.new(locomotive), squashed = false, connection = nil }
	tracked[locomotive] = entry
	if locomotive:GetAttribute(Names.OwnerUserId) == player.UserId then
		mine = locomotive
		DriverCamera.follow(locomotive)
		setSquashed(locomotive, inputDown)
		remote:FireServer(inputDown) -- also replaces a state the server still holds back from the old locomotive
	else
		local function follow()
			setSquashed(locomotive, locomotive:GetAttribute(Names.Squashed) == true)
		end
		entry.connection = locomotive:GetAttributeChangedSignal(Names.Squashed):Connect(follow)
		follow()
	end
end

CollectionService:GetInstanceAddedSignal(Names.LocomotiveTag):Connect(function(instance)
	task.spawn(track, instance)
end)
CollectionService:GetInstanceRemovedSignal(Names.LocomotiveTag):Connect(function(instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = tracked[instance]
	tracked[instance] = nil
	if entry and entry.connection then
		entry.connection:Disconnect()
	end
	if entry and entry.puff then
		entry.puff:destroy()
	end
	if mine == instance then
		mine = nil
	end
end)
for _, instance in CollectionService:GetTagged(Names.LocomotiveTag) do
	task.spawn(track, instance)
end

SquashInput.bind(function(isDown: boolean)
	inputDown = isDown
	local own = mine
	if own then
		setSquashed(own, isDown)
	end
	remote:FireServer(isDown) -- even without a locomotive, so the server's latest state is never a stale one
end)

RunService.RenderStepped:Connect(function(dt: number)
	for _, entry in tracked do
		entry.animator:update(dt)
	end
end)
