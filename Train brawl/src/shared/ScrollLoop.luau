--!strict
-- Slides drawn parts backward along the track (+Z) and wraps each one around, so the standing-still trains look like
-- they run: a part whose anchor (its middle, unless given) passes `behind` comes back in at `ahead`; parts sharing an
-- anchor (a canyon stretch's pieces) wrap together. Scenery's sleepers, roadside props and telegraph poles share one
-- loop, the canyon has a longer one of its own. Used on the clients only.
-- (The wrap-around scroll follows Western train's TrackScroll.)
local Workspace = game:GetService("Workspace")

local ScrollLoop = {}
ScrollLoop.__index = ScrollLoop

type Fields = {
	ahead: number,
	behind: number,
	parts: { BasePart },
	rest: { CFrame }, -- each part's place at offset 0
	anchors: { number }, -- where along the track each part counts as being, for the wrap
	cframes: { CFrame },
	offset: number,
}
export type Loop = typeof(setmetatable({} :: Fields, ScrollLoop))

-- For parts laid out from `ahead` studs in front of the middle (-Z) to `behind` studs behind it.
function ScrollLoop.new(ahead: number, behind: number): Loop
	local fields: Fields = { ahead = ahead, behind = behind, parts = {}, rest = {}, anchors = {}, cframes = {}, offset = 0 }
	return setmetatable(fields, ScrollLoop)
end

-- A part to slide, standing at `cframe` before the first slide; it wraps when `anchor` (along the track, default its
-- middle) passes the loop's end.
function ScrollLoop.add(self: Loop, part: BasePart, cframe: CFrame, anchor: number?)
	part.CFrame = cframe
	table.insert(self.parts, part)
	table.insert(self.rest, cframe)
	table.insert(self.anchors, anchor or cframe.Position.Z)
	table.insert(self.cframes, cframe)
end

-- Slides everything backward by this frame's run: `speed` studs per second for `dt` seconds.
function ScrollLoop.update(self: Loop, dt: number, speed: number)
	local loop = self.ahead + self.behind
	self.offset = (self.offset + speed * dt) % loop
	for i, cframe in self.rest do
		local shift = self.offset
		if self.anchors[i] + shift > self.behind then
			shift -= loop
		end
		self.cframes[i] = cframe + Vector3.new(0, 0, shift)
	end
	Workspace:BulkMoveTo(self.parts, self.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

return ScrollLoop
