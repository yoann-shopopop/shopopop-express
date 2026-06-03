class_name Delivery
extends RefCounted
## A delivery links a drive (pickup, on a grey/urban cell) to a recipient (on a green cell). It spans
## one or two tiles ([member tiles]). Its lifecycle is the 4-status cycle ([DeliveryStatus]); scoring
## rewards the drive tile and the recipient tile when they are the carrier's color. Pure data — no
## nodes. [ScoreCalculator] reads it; [GamePhase] drives its status.

var drive_cell: Vector2i
var recipient_cell: Vector2i
var tiles: Array[PlacedPiece]          ## the 1 or 2 placed pieces this delivery covers
var enseigne: EnseigneDefinition       ## the pickup brand at the drive (fixed per tile)
var destinataire: DestinataireDefinition  ## the current recipient at the green cell (recycled on delivery)
var status: int = DeliveryStatus.Kind.DISPONIBLE  ## DeliveryStatus.Kind
var reserved_by: int = -1              ## seat index of the player who reserved/carries it, or -1


func _init(p_drive: Vector2i, p_recipient: Vector2i, p_tiles: Array[PlacedPiece]) -> void:
	drive_cell = p_drive
	recipient_cell = p_recipient
	tiles = p_tiles


## Clips a new recipient and makes the delivery available again (used at setup and when recycling after
## delivery). A null recipient leaves the drive "free" (inactive — nothing left to deliver).
func recycle(p_destinataire: DestinataireDefinition) -> void:
	destinataire = p_destinataire
	status = DeliveryStatus.Kind.DISPONIBLE
	reserved_by = -1


## True when the delivery can be reserved: available and still carrying a recipient.
func is_reservable() -> bool:
	return status == DeliveryStatus.Kind.DISPONIBLE and destinataire != null


## True when the drive and recipient sit on the same single tile.
func is_single_tile() -> bool:
	return tiles.size() == 1


## District color (PlayerColor.Kind) of the tile holding the drive (first tile), or -1.
func drive_tile_owner() -> int:
	return tiles[0].owner if not tiles.is_empty() else -1


## District color (PlayerColor.Kind) of the tile holding the recipient (last tile), or -1.
func recipient_tile_owner() -> int:
	return tiles[tiles.size() - 1].owner if not tiles.is_empty() else -1
