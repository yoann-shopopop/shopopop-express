class_name Delivery
extends RefCounted
## A delivery links a drive (pickup, on a grey/urban cell) to a recipient (on a green cell). It spans
## one or two tiles ([member tiles]); scoring rewards tiles whose color belongs to the carrier. Pure
## data — no nodes. [ScoreCalculator] reads it; [GamePhase] tracks pickup/delivery state.

var drive_cell: Vector2i
var recipient_cell: Vector2i
var tiles: Array[PlacedPiece]          ## the 1 or 2 placed pieces this delivery covers
var enseigne: EnseigneDefinition       ## the pickup brand at the drive (fixed per tile)
var destinataire: DestinataireDefinition  ## the current recipient at the green cell (recycled on delivery)
var picked_up: bool = false
var delivered: bool = false
var carrier_index: int = -1            ## seat index of the player currently carrying it, or -1


func _init(p_drive: Vector2i, p_recipient: Vector2i, p_tiles: Array[PlacedPiece]) -> void:
	drive_cell = p_drive
	recipient_cell = p_recipient
	tiles = p_tiles


## Clips a new recipient and makes the delivery available again (used when recycling after delivery).
func recycle(p_destinataire: DestinataireDefinition) -> void:
	destinataire = p_destinataire
	picked_up = false
	delivered = false
	carrier_index = -1


## True when the drive and recipient sit on the same single tile.
func is_single_tile() -> bool:
	return tiles.size() == 1


## The district color (PlayerColor.Kind) of each tile this delivery covers.
func tile_owners() -> Array[int]:
	var result: Array[int] = []
	for tile in tiles:
		result.append(tile.owner)
	return result
