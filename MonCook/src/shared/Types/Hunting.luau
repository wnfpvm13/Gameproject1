--!strict
export type Point = { X: number, Y: number, Z: number }
export type AttackIntent = { Sequence: number, AttackType: "Basic" | "Heavy" | "Dodge", Facing: Point?, TargetHint: string? }
export type RewardItem = { IngredientId: string, Quantity: number }
export type HuntingReceipt = { GrantedAt: number, Items: { RewardItem }, Kind: string, MonsterId: string,
	FirstIngredient: boolean, FirstHornboar: boolean }
export type MonsterState = "Idle" | "Roam" | "Alert" | "Chase" | "Windup" | "Attack" | "Recover" | "Stagger" | "Dead"
return {}
