-- 금칙어 게임 Korean server entry point: remotes, then RoundService starts every service and runs rounds forever.
local Net = require(script.Parent:WaitForChild("Net"))
Net.init()
require(script.Parent:WaitForChild("RoundService")).start()
