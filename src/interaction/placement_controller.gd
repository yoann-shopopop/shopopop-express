class_name PlacementController
extends Node
## Turns pointer input (mouse OR touch) into block placement on the board.
##
## Projects the pointer onto the board plane, snaps to the hovered cell, drives the ghost, and
## commits a placement on click/tap. Rotation is exposed as a method so both the UI button and
## the keyboard action can trigger it. Knows nothing about how things are drawn.

signal block_placed(id: StringName)

const BOARD_PLANE := Plane(Vector3.UP, 0.0)

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _block: BlockDefinition
var _rotation: int = 0


func setup(camera: Camera3D, board: Board, ghost: BlockGhost) -> void:
	_camera = camera
	_board = board
	_ghost = ghost


## Selects the block to place and refreshes the ghost.
func select_block(block: BlockDefinition) -> void:
	_block = block
	_ghost.set_block(block)
	_ghost.set_rotation_steps(_rotation)
	_revalidate()


## Moves the ghost to [param cell] and refreshes its validity, without committing.
## Useful for scripted previews, replays or AI players that bypass pointer input.
func preview_at(cell: Vector2i) -> void:
	_ghost.set_anchor(cell)
	_revalidate()


## Rotates the current block by one 60-degree step.
func rotate_current() -> void:
	_rotation = (_rotation + 1) % 6
	_ghost.set_rotation_steps(_rotation)
	_revalidate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_pointer(event.position)
	elif event is InputEventScreenDrag:
		_update_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_update_pointer(event.position)
		_try_place()
	elif event is InputEventScreenTouch and event.pressed:
		_update_pointer(event.position)
		_try_place()
	elif event.is_action_pressed(&"rotate_block"):
		rotate_current()


# Projects [param screen_pos] onto the board plane and moves the ghost to the hovered cell.
func _update_pointer(screen_pos: Vector2) -> void:
	if _camera == null or _block == null:
		return
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit = BOARD_PLANE.intersects_ray(origin, dir)
	if hit == null:
		return
	_ghost.set_anchor(HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE))
	_revalidate()


func _revalidate() -> void:
	if _block == null:
		return
	_ghost.set_valid(_board.can_place(_block, _ghost.current_anchor(), _rotation))


func _try_place() -> void:
	if _block == null:
		return
	if _board.place(_block, _ghost.current_anchor(), _rotation):
		block_placed.emit(_block.id)
		_revalidate()
