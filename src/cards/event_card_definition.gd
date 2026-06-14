class_name EventCardDefinition
extends CardDefinition
## An event card as data: a structured effect (an [enum Effect] plus an [member amount]) resolved by
## [EventResolver], an optional [enum Condition] (e.g. "only on a bike"), and whether it is a malus.
## Modeling effects as data — not a giant if — keeps the ~22 cards declarative ([code].tres[/code]).

## The catalog of effects, covering the Notion event cards. Interactive/positional ones
## (TELEPORT_QUARTIER, TELEPORT_PARALLELE, BUDGET_UN_DE, ROUTE_BLOQUEE, PONTS_FERMES) are stubbed in V1.
enum Effect {
	NONE,
	BONUS_CASES,            ## +amount steps this turn
	MALUS_CASES,            ## -amount steps this turn
	EXTRA_DIE,              ## roll one more die (cyclists)
	DOUBLE_DICE,            ## double the dice result
	REJOUER,                ## play again immediately
	TELEPORT_QUARTIER,      ## move to any district (stub V1)
	TELEPORT_DESTINATION,   ## go straight to the drive/recipient
	TELEPORT_PARALLELE,     ## move to a parallel road (stub V1)
	RETOUR_DRIVE,           ## return to the pickup point
	RETOUR_DEPART,          ## return to the start point
	FIN_TOUR,               ## the turn ends now
	BUDGET_UN_DE,           ## roll a single die until someone passes (stub V1)
	ROUTE_BLOQUEE,          ## a route is blocked for a turn (stub V1)
	PONTS_FERMES,           ## bridges closed for a turn (stub V1)
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
