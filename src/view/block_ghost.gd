class_name BlockGhost
extends Node3D
## A translucent preview of the block about to be placed, snapped to the hovered cell and
## tinted green/red depending on whether the move is legal. Driven entirely by the controller.

const TILE_YAW: float = 0.0  # mesh is already pointy-top; see HexGridView.TILE_YAW
const HOVER_Y: float = GameConfig.TILE_HEIGHT + 0.05

var _mm_instance: MultiMeshInstance3D
var _block: BlockDefinition
var _rotation: int = 0
var _anchor: Vector2i = Vector2i.ZERO
var _valid: bool = true


func _ready() -> void:
	_mm_instance = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = HexMeshFactory.create_tile(GameConfig.HEX_SIZE * 0.96, GameConfig.TILE_HEIGHT)
	_mm_instance.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mm_instance.material_override = mat
	add_child(_mm_instance)


## Sets which block is previewed (re-sizes the instance pool).
func set_block(block: BlockDefinition) -> void:
	_block = block
	if _block != null:
		_mm_instance.multimesh.instance_count = _block.cells.size()
	_refresh()


func set_rotation_steps(steps: int) -> void:
	_rotation = steps
	_refresh()


func set_anchor(cell: Vector2i) -> void:
	if cell == _anchor:
		return
	_anchor = cell
	_refresh()


func set_valid(valid: bool) -> void:
	if valid == _valid and visible:
		return
	_valid = valid
	_refresh()


func current_anchor() -> Vector2i:
	return _anchor


func current_rotation() -> int:
	return _rotation


func _refresh() -> void:
	if _block == null:
		return
	var color := GameConfig.GHOST_VALID if _valid else GameConfig.GHOST_INVALID
	var cells := _block.get_cells(_anchor, _rotation)
	for i in cells.size():
		var pos := HexUtils.axial_to_world(cells[i], GameConfig.HEX_SIZE)
		pos.y = HOVER_Y
		_mm_instance.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, TILE_YAW), pos))
		_mm_instance.multimesh.set_instance_color(i, color)
