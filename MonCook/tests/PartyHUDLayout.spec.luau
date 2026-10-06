--!strict
local Layout = require(script.Parent.Parent.src.shared.Utilities.PartyHUDLayout)

local function input(width: number, height: number, expanded: boolean): any
	return { Width = width, Height = height, Expanded = expanded, TopbarBottom = 0,
		PlayerListEnabled = true, PlayerCount = 20, ChatBounds = {} }
end

local function usable(value: any, request: any)
	assert(value.Width >= 180 and value.Width <= math.min(320, request.Width - 24))
	assert(value.Height > 0 and value.BodyHeight >= 42, "a full Activated button must fit in the scroll viewport")
	assert(value.Top + value.Height <= request.Height - 12, "HUD must remain inside the safe area")
	assert(value.Right + value.Width <= request.Width - 12)
end

return function(): number
	local passed = 0
	local function check(callback: () -> ()) callback(); passed += 1 end
	check(function()
		local request = input(390, 500, true)
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.Policy == "CompactFallback")
	end)
	check(function()
		local request = input(390, 300, true)
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.Policy == "CompactFallback")
	end)
	check(function()
		local request = input(390, 500, true)
		request.ChatBounds = { { Left = 0, Right = 195, Bottom = 250 } }
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.Top >= 262, "the actual chat rectangle still has priority over the list estimate")
	end)
	check(function()
		local request = input(390, 300, true)
		request.ChatBounds = { { Left = 0, Right = 195, Bottom = 150 } }
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.SmallHeader and value.Top >= 162)
	end)
	check(function()
		for _, height in { 500, 300 } do
			local request = input(390, height, false)
			request.ChatBounds = { { Left = 0, Right = 195, Bottom = height * 0.5 } }
			local value = Layout.calculate(request)
			assert(value.Height == 74 and not value.SmallHeader, "collapsed faces/names must remain visible")
			assert(value.Top + value.Height <= height - 12)
		end
	end)
	check(function()
		local request = input(1024, 700, true)
		request.ChatBounds = { { Left = 0, Right = 400, Bottom = 220 } }
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.Policy == "BesidePlayerList" and value.Right >= 332)
		assert(value.Top >= 232, "chat and PlayerList reservations must both apply")
	end)
	check(function()
		local request = input(1024, 700, true)
		request.PlayerListEnabled = false
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.Right == 12 and value.Top == 12, "disabled CoreUI must not consume the HUD column")
	end)
	check(function()
		local request = input(390, 300, true)
		request.TopbarBottom = 30
		request.ChatBounds = { { Left = 0, Right = 195, Bottom = 145 }, { Left = 0, Right = 195, Bottom = 170 } }
		local value = Layout.calculate(request)
		usable(value, request)
		assert(value.Top >= 182, "the chat input bar is a separate rectangle")
	end)
	return passed
end
