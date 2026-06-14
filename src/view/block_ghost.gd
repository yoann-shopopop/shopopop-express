class_name BlockGhost
extends Node3D
## A hovering preview of the block to place, drawn with the real tile textures (so roads are
## visible), tinted red when the placement is illegal. Driven by the controller.

const HOVER_Y := 0.6
const TINT_VALID := Color(1, 1, 1, 0.8)
const TINT_INVALID := Color(1.0, 0.35, 0.35, 0.85)

var _block: BlockDefinition
var _rotation: int = 0
var _anchor: Vector2i = Vector2i.ZERO
var _valid: bool = true


func set_block(block: BlockDefinition) -> void:
	_block = block
	_rebuild()


func set_rotation_steps(steps: int) -> void:
	_rotation = steps
	_rebuild()


func set_anchor(cell: Vector2i) -> void:
	if cell == _anchor:
		return
	_anchor = cell
	_rebuild()


func set_valid(valid: bool) -> void:
	_valid = valid
	var tint := _tint()
	for child in get_children():
		if child is Sprite3D:
			child.modulate = tint


func current_anchor() -> Vector2i:
	return _anchor


func current_rotation() -> int:
	return _rotation


func _tint() -> Color:
	return TINT_VALID if _valid else TINT_INVALID


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	position.y = HOVER_Y
	if _block == null:
		return
	var typed := _block.get_typed_cells(_anchor, _rotation)
	var road_cells := TileSprite.road_cells_of(typed)
	var piece_cells := TileSprite.cells_of(typed)
	var tint := _tint()
	for i in typed.size():
		var tc: Dictionary = typed[i]
		var sprite := TileSprite.make(tc["cell"], tc["type"], road_cells, GameConfig.HEX_SIZE, _block.cells[i], piece_cells)
		sprite.modulate = tint
		add_child(sprite)
