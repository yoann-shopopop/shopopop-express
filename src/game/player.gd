class_name Player
extends RefCounted
## A player in the setup phase: a color, the pieces they still have to place (3 patterns + 1 bridge),
## and where their start point sits (a green cell of one of their blocks, fixed before placement).

var index: int = 0                              ## seat index (turn identity), distinct from color
var color: int                                  ## PlayerColor.Kind — the player's district color
var character: CharacterDefinition = null       ## character card: transport, regular-route colors, power
var is_ai: bool = false                         ## true for a seat GameRoot auto-plays (see AutoPilot)
var power_used: bool = false                    ## true once the one-shot super-power has been spent
var pieces: Array[BlockDefinition] = []         ## the blocks left to place (one per turn)
var bridge: BlockDefinition = null              ## the player's single free bridge (null once placed)
var done: bool = false                          ## true once this player has finished placing
var start_block: BlockDefinition = null         ## the block (by reference) carrying the start point
var start_cell: Vector2i = Vector2i.ZERO        ## offset of the start cell within that block

# Persistent benefits armed by a one-shot super-power. They outlive the turn (the power may pay off
# later) so the power is never wasted: it stays armed until the matching moment actually arrives.
var bonus_capacity: int = 0                     ## Chargement Pro (Margot): extra in-flight slots
var pending_draw_two: bool = false              ## Carnet d'Adresses (Charlie): next event drawn 2-keep-1
var shield_charged: bool = false                ## Bouclier Vert (Axel·le): the next malus is cancelled
var regular_route_charge: bool = false          ## Habitué·e (Camille): next delivery scores full

## Coup de pouce tokens (dice-luck mitigation): spend one, before taking a first step this turn, to
## reroll all dice or fix one die to its max face. A resource pool, not a one-shot power — 2 per
## player, granted once per game (not replenished per turn).
var boost_tokens: int = 2


func _init(p_color: int) -> void:
	color = p_color
