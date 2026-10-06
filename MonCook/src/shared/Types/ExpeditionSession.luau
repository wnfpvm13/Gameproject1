--!strict
-- Runtime activity identity only; Expedition never owns Restaurant escrow/economy.
export type State = "Preparing" | "Teleporting" | "Active" | "Result" | "Returning" | "Closed"
export type ReturnDestination = "Repeat" | "HostRestaurant" | "Hearthcross"
export type Session = {
	SessionId: string, PartyId: string, HostUserId: number, MemberUserIds: { number },
	RegionId: string, TargetId: string, State: State, CreatedAt: number,
	DestinationPrivateServerId: string?, ResultAt: number?, ClosedAt: number?,
	ReturnDestination: ReturnDestination?, ReturnActionId: string?,
}
export type Receipt = {
	SessionId: string, HostUserId: number, ActionId: string,
	Kind: "Return" | "Cancel" | "Abandon", Destination: ReturnDestination?, ClosedAt: number,
}
return {}
