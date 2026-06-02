class_name PlacementController
extends Node
## Pointer-driven placement with a road magnet. Pick a piece (from the UI preview), move the pointer
## over the board: the magnet snaps the ghost to the nearest legal cell+rotation (auto-rotation);
## the rotate action cycles between the legal candidates. Clicking places it. Dropping one cell too
## far auto-inserts the player's bridge (consumed) when one would link the roads, else the ghost is
## red. Touch and mouse share the same path.

const BOARD_PLANE := Plane(Vector3.UP, 0.0)
const MAGNET_RADIUS := 2

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _phase: SetupPhase
var _selected_index: int = 0
var _rotation: int = 0                 # manual rotation used when no magnet candidate applies

var _candidates: Array = []            # [{ "cell": Vector2i, "rot": int }], nearest first
var _choice: int = 0
var _raw_cell: Vector2i = Vector2i.ZERO


func setup(camera: Camera3D, board: Board, ghost: BlockGhost, phase: SetupPhase) -> void:
	_camera = camera
	_board = board
	_ghost = ghost
	_phase = phase
	select_piece(0)


func select_piece(index: int) -> void:
	_selected_index = index
	_rotation = 0
	_ghost.set_block(_selected_block())
	_ghost.set_rotation_steps(_rotation)


## Cycles between legal magnet candidates, or rotates the free piece when none apply.
func rotate_current() -> void:
	if _candidates.is_empty():
		_rotation = (_rotation + 1) % 6
		_ghost.set_rotation_steps(_rotation)
		_ghost.set_valid(false)
	else:
		_choice = (_choice + 1) % _candidates.size()
		_apply_choice()


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
	var block := _selected_block()
	if _camera == null or block == null:
		return
	var hit = BOARD_PLANE.intersects_ray(_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	if hit == null:
		return
	_raw_cell = HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE)
	_recompute_candidates(block, hit)
	if _candidates.is_empty():
		_ghost.set_rotation_steps(_rotation)
		_ghost.set_anchor(_raw_cell)
		_ghost.set_valid(false)
	else:
		_choice = mini(_choice, _candidates.size() - 1)
		_apply_choice()


# Legal (cell, rotation) placements near the pointer, sorted by distance to the pointer.
func _recompute_candidates(block: BlockDefinition, hit: Vector3) -> void:
	_candidates.clear()
	for dq in range(-MAGNET_RADIUS, MAGNET_RADIUS + 1):
		for dr in range(-MAGNET_RADIUS, MAGNET_RADIUS + 1):
			var cell := _raw_cell + Vector2i(dq, dr)
			for rot in 6:
				if _board.can_place(block, cell, rot):
					var d := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE).distance_to(hit)
					_candidates.append({"cell": cell, "rot": rot, "d": d})
	_candidates.sort_custom(func(a, b): return a["d"] < b["d"])


func _apply_choice() -> void:
	var c: Dictionary = _candidates[_choice]
	_ghost.set_rotation_steps(c["rot"])
	_ghost.set_anchor(c["cell"])
	_ghost.set_valid(true)


func _try_place() -> void:
	var block := _selected_block()
	if block == null:
		return
	if not _candidates.is_empty():
		var c: Dictionary = _candidates[_choice]
		if _phase.try_place(_selected_index, c["cell"], c["rot"]):
			_after_place()
		return
	# No direct fit — try to bridge across a one-cell gap using the player's bridge.
	var bridge := _player_bridge()
	if bridge != null:
		var found := BridgeFinder.find(_board, block, _raw_cell, _rotation, bridge)
		if not found.is_empty() and _phase.try_place_with_bridge(_selected_index, _raw_cell, _rotation, found["anchor"], found["rotation"]):
			_after_place()


func _player_bridge() -> BlockDefinition:
	for piece in _phase.current_player().pieces:
		if piece.id == &"bridge":
			return piece
	return null


func _after_place() -> void:
	_candidates.clear()
	_choice = 0
	_rotation = 0
	select_piece(0)
