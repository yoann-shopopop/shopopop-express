class_name Player
extends RefCounted
## A player in the setup phase: a color, the pieces they still have to place (3 patterns + 1 bridge),
## and where their start point sits (a green cell of one of their blocks, fixed before placement).

var index: int = 0                              ## seat index (turn identity), distinct from color
var color: int                                  ## PlayerColor.Kind — the player's district color
var character: CharacterDefinition = null       ## character card: transport, regular-route colors, power
var power_used: bool = false                    ## true once the one-shot super-power has been spent
var pieces: Array[BlockDefinition] = []         ## the blocks left to place (one per turn)
var bridge: BlockDefinition = null              ## the player's single free bridge (null once placed)
var done: bool = false                          ## true once this player has finished placing
var start_block: BlockDefinition = null         ## the block (by reference) carrying the start point
var start_cell: Vector2i = Vector2i.ZERO        ## offset of the start cell within that block


func _init(p_color: int) -> void:
	color = p_color
