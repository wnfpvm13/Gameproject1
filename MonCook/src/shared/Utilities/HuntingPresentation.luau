--!strict
local Presentation = {}
function Presentation.layout(width: number, height: number, style: any): any
	local narrow = width < 460
	local button = if narrow then style.NarrowButton else style.TouchButton
	local panelWidth = math.max(style.MinimumTouch, math.min(style.PanelWidth, width-24))
	local combatBottom = math.min(if height < 430 then 72 else 116, math.max(44, height*0.3))
	return { Button = math.max(style.MinimumTouch, button), ButtonGap = 8, CombatBottom = combatBottom,
		PanelWidth = panelWidth, PanelHeight = math.max(1, math.min(style.PanelHeight, height-combatBottom-12)),
		NoticeWidth = math.max(120, math.min(320, width-32)), Narrow = narrow }
end
function Presentation.canAct(state: any, inventoryOpen: boolean): boolean
	return type(state) == "table" and state.Ready == true and state.Location == "World" and not state.Traveling
		and type(state.Health) == "number" and state.Health > 0 and state.WeaponId ~= nil and not inventoryOpen
end
function Presentation.input(key: string, inputType: string): string?
	if inputType == "MouseButton1" or key == "ButtonR2" then return "Basic" end
	if key == "Q" or key == "ButtonX" then return "Heavy" end
	if key == "F" or key == "ButtonB" then return "Dodge" end
	return nil
end
function Presentation.notice(receipt: any, definitions: any): (string, boolean)
	local lines, rare = {}, false
	if receipt.Kind == "PartBroken" then table.insert(lines, "✓ 뿔 파괴 · Horn Core 획득") end
	for _, item in receipt.Items do
		local definition = definitions.Ingredient[item.IngredientId]
		if definition then
			if definition.Rarity == "Rare" then rare = true; table.insert(lines, "✨ RARE INGREDIENT") end
			table.insert(lines, definition.DisplayName .. " ×" .. tostring(item.Quantity))
		end
	end
	return table.concat(lines, "\n"), rare
end
return table.freeze(Presentation)
