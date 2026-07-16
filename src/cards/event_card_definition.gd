class_name EventCardDefinition
extends CardDefinition
## An event card as data: a structured effect (an [enum Effect] plus an [member amount]) resolved by
## [EventResolver], an optional [enum Condition] (e.g. "only on a bike"), and whether it is a malus.
## Modeling effects as data — not a giant if — keeps the ~22 cards declarative ([code].tres[/code]).

## The catalog of effects, covering the Notion event cards. Board-dependent ones (TELEPORT_QUARTIER,
## TELEPORT_PARALLELE, BUDGET_UN_DE, ROUTE_BLOQUEE, PONTS_FERMES) resolve in
## [method GamePhase._apply_spatial_event] with simplified V1 semantics (noted below).
enum Effect {
	NONE,
	BONUS_CASES,            ## +amount steps this turn
	MALUS_CASES,            ## -amount steps this turn
	EXTRA_DIE,              ## roll one more die (cyclists)
	DOUBLE_DICE,            ## double the remaining movement
	REJOUER,                ## play again immediately
	TELEPORT_QUARTIER,      ## V1: teleport to the farthest drive
	TELEPORT_DESTINATION,   ## go straight to the drive/recipient
	TELEPORT_PARALLELE,     ## V1: teleport to the nearest available drive
	RETOUR_DRIVE,           ## return to the pickup point
	RETOUR_DEPART,          ## return to the start point
	FIN_TOUR,               ## the turn ends now
	BUDGET_UN_DE,           ## V1: lose half the remaining budget
	ROUTE_BLOQUEE,          ## V1: a 3-step detour
	PONTS_FERMES,           ## V1: a 2-step detour (bridges are setup-only)
	BONUS_SCORE,            ## +amount to the final score
	DOUBLE_SCORE_LIVRAISON, ## double delivery points (cyclists)
}

## A precondition gating the effect.
enum Condition { NONE, VELO }

## The structured effect.
@export var effect: Effect = Effect.NONE
## Numeric parameter for the effect (number of cases, bonus points…).
@export var amount: int = 0
## A precondition that must hold for the effect to apply.
@export var condition: Condition = Condition.NONE
## Whether the card is a malus (penalty) — relevant to the Bouclier Vert shield.
@export var is_malus: bool = false
