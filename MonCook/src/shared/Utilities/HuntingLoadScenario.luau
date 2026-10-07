--!strict
-- Studio-only caller chooses these bounded load scenarios; no remote can set count.
local Scenario = {}
function Scenario.zone(original: any, count: number): any
	assert(table.find({1,5,10,25,50},count),"Unsupported QA spawn count")
	local zone=table.clone(original)
	zone.MaxAlive,zone.Center,zone.Offsets = count,{X=0,Y=0,Z=-14},{}
	local width=math.ceil(math.sqrt(count))
	zone.Radius=math.max(original.Radius,math.ceil((width-1)*12/math.sqrt(2)))
	for index=1,count do
		local column,row=(index-1)%width,math.floor((index-1)/width)
		table.insert(zone.Offsets,{X=(column-(width-1)/2)*12,Y=0,Z=(row-(width-1)/2)*12})
	end
	return zone
end
return table.freeze(Scenario)
