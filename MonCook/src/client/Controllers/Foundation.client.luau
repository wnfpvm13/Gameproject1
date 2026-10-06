--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("MonCookNetwork", 30)
if not network then warn("[MonCook] Foundation server is not configured; inspect server Output."); return end
local command = network:WaitForChild("Command") :: RemoteFunction
local changed = network:WaitForChild("Changed") :: RemoteEvent
local Presentation = require(ReplicatedStorage:WaitForChild("Shared").Utilities.PartyPresentation)
local PartyHUD = require(script.Parent.PartyHUD)
local DebugUI = require(script.Parent.FoundationDebugUI)
local pending = false
local hud: any
local debugUI: any

local function render(state: any)
	if type(state) ~= "table" then return end
	hud:Render(state)
	debugUI:Render(state, Presentation.debugVisible(RunService:IsStudio(), state.Features))
end

local function send(action: string, payload: any?)
	if pending then return end
	pending = true
	hud:SetPending(true)
	local ok, response = pcall(function() return command:InvokeServer(action, payload) end)
	pending = false
	if ok and response and response.State then render(response.State) end
	hud:SetPending(false)
	if not ok or not response or not response.Ok then
		local details = if ok and response then response.Error or "다시 시도하세요." else "연결을 확인하세요."
		warn("[MonCook] " .. tostring(details))
		debugUI:SetStatus(tostring(details))
		hud:SetStatus(if ok then "요청을 완료하지 못했어요. 상태를 확인하고 다시 시도해 주세요." else "연결을 확인하고 다시 시도해 주세요.")
	else debugUI:SetStatus(""); hud:SetStatus("") end
end

local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
hud, debugUI = PartyHUD.new(playerGui, send), DebugUI.new(playerGui, send)
hud:Render({ Ready = false, Location = "World" })
changed.OnClientEvent:Connect(render)
send("State", nil)
