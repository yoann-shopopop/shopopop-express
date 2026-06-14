class_name TurnContext
extends RefCounted
## The mutable state of the current turn that event cards and super-powers act on. Resolvers mutate
## this; [GamePhase] reads it back after resolution (budget via [member movement], plus the flags).
## Keeping the effects pointed at one bundle keeps them data-driven and testable in isolation.

var movement: TurnMovement = null          ## the turn's walk (budget, position, teleport)
var player: Player = null                  ## the acting player (transport, character)
var start_cell: Vector2i = Vector2i.ZERO   ## the player's start (for "return to start")
var current_delivery: Delivery = null      ## the delivery in hand, if any

# Flags read back by GamePhase / GameRoot after an event or power resolves:
var turn_ended: bool = false               ## the turn ends now (Feu Rouge, Panne…)
var replay: bool = false                   ## play another turn (Tous les Feux au Vert)
var score_bonus: int = 0                   ## flat points added to the final score (5/5)
var double_score: bool = false             ## double this player's delivery points (Livraison Écologique)
var extra_dice: int = 0                    ## extra dice to roll (Prime Gouvernementale)
var draw_two: bool = false                 ## draw two event cards, keep one (Carnet d'Adresses)
var shield: bool = false                   ## cancel the next malus that targets the player (Bouclier Vert)
var force_regular_route: bool = false      ## count one delivery as regular-route regardless of color


func _init(p_movement: TurnMovement = null, p_player: Player = null) -> void:
	movement = p_movement
	player = p_player
	if p_movement != null:
		start_cell = p_movement.current()
