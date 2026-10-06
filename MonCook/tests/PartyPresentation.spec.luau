--!strict
local Presentation = require(script.Parent.Parent.src.shared.Utilities.PartyPresentation)

return function(): number
	local passed = 0
	local function check(callback: () -> ()) callback(); passed += 1 end
	check(function()
		assert(Presentation.debugVisible(true, { ShowFoundationDebugUI = true }))
		assert(not Presentation.debugVisible(false, { ShowFoundationDebugUI = true }))
		assert(not Presentation.debugVisible(true, { ShowFoundationDebugUI = false }))
		assert(not Presentation.debugVisible(true, {}) and not Presentation.debugVisible(true, nil))
		assert(not Presentation.debugVisible(true, { ShowFoundationDebugUI = "true" }))
	end)
	check(function()
		local party = { MemberUserIds = { 12, 24, 36, 48 }, ReadyStates = { ["12"] = "Joined", ["24"] = "Joined", ["36"] = "Waiting", ["48"] = "Stayed" } }
		local summary = Presentation.summary(party, nil)
		assert(summary.Total == 4 and summary.Moving == 2 and summary.Waiting == 1 and summary.Staying == 1)
		assert(Presentation.readyLabel("Joined") == "✓ 함께 이동")
		assert(Presentation.readyLabel("Waiting") == "… 응답 중")
		assert(Presentation.readyLabel("Stayed") == "— 이번엔 남음")
	end)
	check(function()
		local party = { MemberUserIds = { 1, 2, 3 } }
		local proposal = { Responses = { ["1"] = true, ["2"] = false } }
		local summary = Presentation.summary(party, proposal)
		assert(summary.Moving == 1 and summary.Staying == 1 and summary.Waiting == 1)
		assert(Presentation.readyState(party, nil, 1) == "Idle")
		assert(Presentation.summary(nil, nil).Total == 0)
	end)
	check(function()
		local rows = Presentation.memberRows({
			Party = { LeaderUserId = 2, MemberUserIds = { 2, 1, 3 } },
			Members = { { ActorId = 1, UserId = 9001, DisplayName = "요리사" }, { ActorId = 2, UserId = 9002, Name = "Host" } },
		})
		assert(#rows == 3 and rows[1].IsLeader and rows[1].Name == "Host")
		assert(rows[2].UserId == 9001 and rows[2].Name == "요리사" and not rows[2].IsLeader)
		assert(rows[3].Name == "플레이어" and rows[3].ActorId == 3)
	end)
	check(function()
		local directory = {
			{ PartyId = "open", Visibility = "Public", Status = "Forming" },
			{ PartyId = "private", Visibility = "Private", Status = "Forming" },
			{ PartyId = "closed", Visibility = "Public", Status = "Closed" },
		}
		local visible = Presentation.publicDirectory({ Directory = directory })
		assert(#visible == 1 and visible[1].PartyId == "open" and #directory == 3)
		assert(#Presentation.publicDirectory(nil) == 0)
	end)
	check(function()
		assert(Presentation.shortName("ABC", 3) == "ABC")
		assert(Presentation.shortName("ABCDEFG", 3) == "ABC…")
		assert(Presentation.shortName("한글요리사이름", 4) == "한글요리…")
	end)
	return passed
end
