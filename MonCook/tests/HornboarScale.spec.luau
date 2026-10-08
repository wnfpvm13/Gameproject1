--!strict
local Scenario=require(script.Parent.Parent.src.shared.Utilities.HuntingLoadScenario)
local Monsters=require(script.Parent.Parent.src.server.Services.MonsterService)
local Registry=require(script.Parent.Parent.src.shared.Config.Registry)
local Math=require(script.Parent.Parent.src.shared.Utilities.HuntingMath)
return function(): number
	local groups=0
	for _,count in {1,5,10,25,50} do
		local definitions=table.clone(Registry.Definitions);definitions.Spawn=table.clone(definitions.Spawn)
		local original=definitions.Spawn.GreenwoodOutskirts
		definitions.Spawn.GreenwoodOutskirts=Scenario.zone(original,count)
		assert(Registry.validate(definitions) and original.MaxAlive==2)
		local clock,id=0,0
		local monsters=Monsters.new({Definitions=definitions,Geometry=Math,Now=function()return clock end,
			NewId=function()id+=1;return "scale-"..tostring(id)end})
		monsters:Tick({},.05);assert(#monsters:List()==count)
		local seen={};for _,m in monsters:List() do assert(not seen[m.EncounterId]);seen[m.EncounterId]=true end
		local started=os.clock()
		for _=1,200 do clock+=.05;monsters:Tick({},.05) end
		print(string.format("Host-only pure AI: %d monsters / mean %.4f ms per tick (no Studio/render/network)",count,(os.clock()-started)*5))
		local victim=monsters:List()[1]
		monsters:ApplyHit(victim.EncounterId,1,{AttackId="kill",Damage=1000,PartPower=0,Horn=false})
		assert(monsters:Get(victim.EncounterId).State=="Dead")
		clock+=3;monsters:Tick({},.05);assert(#monsters:List()==count-1)
		clock+=5;monsters:Tick({},.05);assert(#monsters:List()==count)
		groups+=1
	end
	return groups
end
