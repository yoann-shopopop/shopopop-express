class_name PlacementController
extends Node
## Drag-and-drop placement with a road magnet. The UI starts a drag by pressing a piece preview:
## a BLOCK (ends the turn) or the BRIDGE (free; connects to a road via its central road cell only).
## While dragging, the ghost follows the pointer and the magnet snaps it to the nearest legal
## cell+rotation; the rotate action cycles candidates. Releasing where nothing is legal places
## nothing. Mouse and touch share the same path.

const BOARD_PLANE := Plane(Vector3.UP, 0.0)
const MAGNET_RADIUS := 1

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _phase: SetupPhase

var _dragging: bool = false
var _dragging_bridge: bool = false
var _selected_index: int = 0
var _rotation: int = 0
var _candidates: Array = []            # legal placements [{ "cell", "rot" }], nearest first
var _choice: int = 0
var _raw_cell: Vector2i = Vector2i.ZERO
var _over_board: bool = false
var _has_pointer: bool = false


func setup(camera: Camera3D, board: Board, ghost: BlockGhost, phase: SetupPhase) -> void:
	_camera = camera
	_board = board
	_ghost = ghost
	_phase = phase
	_ghost.visible = false


## Starts dragging the current player's block [param index].
func begin_drag(index: int) -> void:
	_start_drag(false, index)


## Starts dragging the current player's (free) bridge.
func begin_bridge_drag() -> void:
	_start_drag(true, 0)


func _start_drag(bridge: bool, index: int) -> void:
	_dragging_bridge = bridge
	_selected_index = index
	_rotation = 0
	_candidates.clear()
	_choice = 0
	_has_pointer = false
	_dragging = true
	_ghost.set_block(_dragged_piece())
	_ghost.set_rotation_steps(0)
	_ghost.set_valid(false)
	_ghost.visible = true


func rotate_current() -> void:
	if not _dragging:
		return
	if _candidates.is_empty():
		_rotation = (_rotation + 1) % 6
		_ghost.set_rotation_steps(_rotation)
		_ghost.set_valid(false)
	else:
		_choice = (_choice + 1) % _candidates.size()
		_apply_choice()


func _dragged_piece() -> BlockDefinition:
	if _dragging_bridge:
		return _phase.current_player().bridge
	var pieces := _phase.current_player().pieces
	if _selected_index < 0 or _selected_index >= pieces.size():
		return null
	return pieces[_selected_index]


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_update_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_release(event.position)
	elif event.is_action_pressed(&"rotate_block"):
		rotate_current()


func _release(screen_pos: Vector2) -> void:
	_update_pointer(screen_pos)
	_try_place()
	_end_drag()


func _end_drag() -> void:
	_dragging = false
	_dragging_bridge = false
	_candidates.clear()
	_choice = 0
	_rotation = 0
	_ghost.visible = false
	_ghost.set_block(null)


func _update_pointer(screen_pos: Vector2) -> void:
	var piece := _dragged_piece()
	if _camera == null or piece == null:
		return
	var hit = BOARD_PLANE.intersects_ray(_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	if hit == null:
		_over_board = false
		_candidates.clear()
		_ghost.set_valid(false)
		return
	var cell := HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE)
	if _over_board and _has_pointer and cell == _raw_cell:
		return
	_over_board = true
	_has_pointer = true
	_raw_cell = cell
	_recompute_candidates(piece, hit)

	if _candidates.is_empty():
		_ghost.set_rotation_steps(_rotation)
		_ghost.set_anchor(_raw_cell)
		_ghost.set_valid(false)
	else:
		_choice = mini(_choice, _candidates.size() - 1)
		_apply_choice()


func _recompute_candidates(piece: BlockDefinition, hit: Vector3) -> void:
	_candidates.clear()
	for dq in range(-MAGNET_RADIUS, MAGNET_RADIUS + 1):
		for dr in range(-MAGNET_RADIUS, MAGNET_RADIUS + 1):
			var cell := _raw_cell + Vector2i(dq, dr)
			for rot in 6:
				if _board.can_place(piece, cell, rot):
					var d := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE).distance_to(hit)
					_candidates.append({"cell": cell, "rot": rot, "d": d})
	_candidates.sort_custom(func(a, b): return a["d"] < b["d"])


func _apply_choice() -> void:
	var c: Dictionary = _candidates[_choice]
	_ghost.set_rotation_steps(c["rot"])
	_ghost.set_anchor(c["cell"])
	_ghost.set_valid(true)


func _try_place() -> void:
	if _dragged_piece() == null or not _over_board or _candidates.is_empty():
		return
	var c: Dictionary = _candidates[_choice]
	if _dragging_bridge:
		_phase.try_place_bridge(c["cell"], c["rot"])
	else:
		_phase.try_place(_selected_index, c["cell"], c["rot"])
