class_name PlacementController
extends Node
## Turns pointer input (mouse OR touch) into setup placements: previews the current player's selected
## piece under the pointer and commits it through the [SetupPhase] on click/tap. Knows nothing about
## how things are drawn nor about the turn order beyond asking the phase whose turn it is.

const BOARD_PLANE := Plane(Vector3.UP, 0.0)

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _phase: SetupPhase
var _selected_index: int = 0
var _rotation: int = 0


func setup(camera: Camera3D, board: Board, ghost: BlockGhost, phase: SetupPhase) -> void:
	_camera = camera
	_board = board
	_ghost = ghost
	_phase = phase
	select_piece(0)


## Selects which of the current player's remaining pieces to place.
func select_piece(index: int) -> void:
	_selected_index = index
	_ghost.set_block(_selected_block())
	_ghost.set_rotation_steps(_rotation)
	_revalidate()


## Rotates the previewed piece by one 60-degree step.
func rotate_current() -> void:
	_rotation = (_rotation + 1) % 6
	_ghost.set_rotation_steps(_rotation)
	_revalidate()


func _selected_block() -> BlockDefinition:
	var pieces := _phase.current_player().pieces
	if _selected_index < 0 or _selected_index >= pieces.size():
		return null
	return pieces[_selected_index]


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


func _update_pointer(screen_pos: Vector2) -> void:
	if _camera == null or _selected_block() == null:
		return
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit = BOARD_PLANE.intersects_ray(origin, dir)
	if hit == null:
		return
	_ghost.set_anchor(HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE))
	_revalidate()


func _revalidate() -> void:
	var block := _selected_block()
	if block == null:
		return
	_ghost.set_valid(_board.can_place(block, _ghost.current_anchor(), _rotation))


func _try_place() -> void:
	if _selected_block() == null:
		return
	if _phase.try_place(_selected_index, _ghost.current_anchor(), _rotation):
		# Default back to the first remaining piece of whoever plays next.
		_rotation = 0
		select_piece(0)
