--!strict
-- Foundation's MonCookNetwork is unchanged. Hunting uses a separate transport.
return table.freeze({
	Hunting = table.freeze({ Folder = "MonCookHuntingNetwork", Intent = "Intent", State = "State", Changed = "Changed",
		Actions = table.freeze({ "Basic", "Heavy", "Dodge" }) }),
})
