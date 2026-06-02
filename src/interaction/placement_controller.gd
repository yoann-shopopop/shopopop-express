class_name PlacementController
extends Node
## Drag-and-drop placement with a road magnet. The UI starts a drag (pressing a piece preview);
## while dragging, the ghost follows the pointer and the magnet snaps it to the nearest legal
## cell+rotation (auto-rotation); the rotate action cycles candidates. Releasing places the piece —
## or, if it landed one cell too far, auto-inserts the player's bridge (consumed) to link the roads.
## When not dragging, the ghost is hidden. Mouse and touch share the same path.

const BOARD_PLANE := Plane(Vector3.UP, 0.0)
const MAGNET_RADIUS := 1  # gentle snap; leaves real gaps open so the auto-bridge can kick in

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _phase: SetupPhase

var _dragging: bool = false
var _selected_index: int = 0
var _rotation: int = 0                 # manual rotation, used when no magnet candidate applies
var _candidates: Array = []            # [{ "cell": Vector2i, "rot": int }], nearest first
var _choice: int = 0
var _raw_cell: Vector2i = Vector2i.ZERO
var _over_board: bool = false          # whether the pointer currently projects onto the board


func setup(camera: Camera3D, board: Board, ghost: BlockGhost, phase: SetupPhase) -> void:
	_camera = camera
	_board = board
	_ghost = ghost
	_phase = phase
	_ghost.visible = false


## Starts dragging the current player's piece [param index] (called when a preview is pressed).
func begin_drag(index: int) -> void:
	_selected_index = index
	_rotation = 0
	_candidates.clear()
	_choice = 0
	_dragging = true
	_ghost.set_block(_selected_block())
	_ghost.set_rotation_steps(0)
	_ghost.set_valid(false)
	_ghost.visible = true


## Cycles between legal magnet candidates, or rotates the free piece when none apply.
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


func _selected_block() -> BlockDefinition:
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
	_candidates.clear()
	_choice = 0
	_rotation = 0
	_ghost.visible = false
	_ghost.set_block(null)


func _update_pointer(screen_pos: Vector2) -> void:
	var block := _selected_block()
	if _camera == null or block == null:
		return
	var hit = BOARD_PLANE.intersects_ray(_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	if hit == null:
		_over_board = false
		_candidates.clear()
		_ghost.set_valid(false)
		return
	_over_board = true
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
	if block == null or not _over_board:
		return  # released off the board — cancel
	if not _candidates.is_empty():
		var c: Dictionary = _candidates[_choice]
		_phase.try_place(_selected_index, c["cell"], c["rot"])
		return
	# No direct fit — try to bridge across the gap with the player's (free) bridge. Search every
	# block rotation so the auto-bridge "just works" without the player pre-orienting the block.
	var bridge := _phase.current_player().bridge
	if bridge == null:
		return
	for rot in 6:
		var found := BridgeFinder.find(_board, block, _raw_cell, rot, bridge)
		if not found.is_empty():
			_phase.try_place_with_bridge(_selected_index, _raw_cell, rot, found["anchor"], found["rotation"])
			return
