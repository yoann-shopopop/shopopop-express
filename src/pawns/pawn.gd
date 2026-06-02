class_name Pawn
extends RefCounted
## A pawn's runtime state: where it is, and how many cells it still has to travel.
##
## Pure logic — no [Node], no [Texture2D] — so it stays unit-testable in isolation, like [Board].
## It deliberately knows nothing about the board's topology: [method move_to] accepts any cell.
## Spatial legality (cell exists, path is reachable) belongs to the future movement system.

## Emitted on the first successful [method place].
signal placed(cell: Vector2i)
## Emitted whenever a placed, mobile pawn changes cell via [method move_to].
signal moved(from: Vector2i, to: Vector2i)
## Emitted when the number of cells to travel changes via [method set_steps].
signal steps_changed(value: int)

## This pawn's identity (name, image, type). Set once at construction.
var definition: PawnDefinition
## Current cell — meaningful only while [member is_placed] is true.
var position: Vector2i = Vector2i.ZERO
## Whether the pawn has been placed yet. Guards [member position] against being read too early.
var is_placed: bool = false
## Number of cells the pawn can/must still travel (cotransporter only).
var steps: int = 0


func _init(pawn_definition: PawnDefinition) -> void:
	assert(pawn_definition != null, "a pawn requires a PawnDefinition")
	definition = pawn_definition


## Places the pawn at [param cell] for the first time. Returns false (no-op) if already placed.
func place(cell: Vector2i) -> bool:
	if is_placed:
		return false
	position = cell
	is_placed = true
	placed.emit(cell)
	return true


## Moves a placed, mobile pawn to [param cell]. Returns false if unplaced or not mobile.
## Does NOT check board topology — that is the movement system's responsibility.
func move_to(cell: Vector2i) -> bool:
	if not can_move():
		return false
	var previous := position
	position = cell
	moved.emit(previous, cell)
	return true


## Sets the number of cells to travel. Returns false for a negative value or a fixed pawn.
func set_steps(value: int) -> bool:
	if value < 0 or not definition.is_mobile():
		return false
	steps = value
	steps_changed.emit(value)
	return true


## True when the pawn is both placed and mobile.
func can_move() -> bool:
	return is_placed and definition.is_mobile()
