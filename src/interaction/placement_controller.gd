class_name PlacementController
extends Node
## Drag-and-drop placement with a road magnet. The UI starts a drag by pressing a piece preview:
## a BLOCK (ends the turn) or the BRIDGE (free, must connect to a road). While dragging, the ghost
## follows the pointer and the magnet snaps it to the nearest legal cell+rotation; the rotate action
## cycles candidates. For a BLOCK dropped one cell too far, the player's bridge is previewed and
## placed with it (auto-bridge). Releasing where nothing is legal places nothing. Mouse and touch
## share the same path.

const BOARD_PLANE := Plane(Vector3.UP, 0.0)
const MAGNET_RADIUS := 1

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _bridge_ghost: BlockGhost
var _phase: SetupPhase

var _dragging: bool = false
var _dragging_bridge: bool = false
var _selected_index: int = 0
var _rotation: int = 0
var _candidates: Array = []            # direct legal placements [{ "cell", "rot" }], nearest first
var _choice: int = 0
var _bridge_plan: Dictionary = {}      # auto-bridge for a block: { block_rot, bridge_anchor, bridge_rot }
var _raw_cell: Vector2i = Vector2i.ZERO
var _over_board: bool = false
var _has_pointer: bool = false


func setup(camera: Camera3D, board: Board, ghost: BlockGhost, bridge_ghost: BlockGhost, phase: SetupPhase) -> void:
	_camera = camera
	_board = board
	_ghost = ghost
	_bridge_ghost = bridge_ghost
	_phase = phase
	_ghost.visible = false
	_bridge_ghost.visible = false


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
	_bridge_plan = {}
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
	_bridge_plan = {}
	_rotation = 0
	_ghost.visible = false
	_ghost.set_block(null)
	_bridge_ghost.visible = false
	_bridge_ghost.set_block(null)


func _update_pointer(screen_pos: Vector2) -> void:
	var piece := _dragged_piece()
	if _camera == null or piece == null:
		return
	var hit = BOARD_PLANE.intersects_ray(_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	if hit == null:
		_over_board = false
		_candidates.clear()
		_bridge_plan = {}
		_bridge_ghost.visible = false
		_ghost.set_valid(false)
		return
	var cell := HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE)
	if _over_board and _has_pointer and cell == _raw_cell:
		return
	_over_board = true
	_has_pointer = true
	_raw_cell = cell
	_recompute_candidates(piece, hit)

	if not _candidates.is_empty():
		_bridge_plan = {}
		_bridge_ghost.visible = false
		_choice = mini(_choice, _candidates.size() - 1)
		_apply_choice()
	elif _dragging_bridge:
		# A manually-dragged bridge with no legal spot here: just show it red.
		_bridge_ghost.visible = false
		_ghost.set_rotation_steps(_rotation)
		_ghost.set_anchor(_raw_cell)
		_ghost.set_valid(false)
	else:
		_bridge_plan = _find_bridge_plan(piece)
		if _bridge_plan.is_empty():
			_bridge_ghost.visible = false
			_ghost.set_rotation_steps(_rotation)
			_ghost.set_anchor(_raw_cell)
			_ghost.set_valid(false)
		else:
			_preview_bridge(piece)


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


func _find_bridge_plan(block: BlockDefinition) -> Dictionary:
	var bridge := _phase.current_player().bridge
	if bridge == null:
		return {}
	for rot in 6:
		var found := BridgeFinder.find(_board, block, _raw_cell, rot, bridge)
		if not found.is_empty():
			return {"block_rot": rot, "bridge_anchor": found["anchor"], "bridge_rot": found["rotation"]}
	return {}


func _preview_bridge(block: BlockDefinition) -> void:
	_ghost.set_rotation_steps(_bridge_plan["block_rot"])
	_ghost.set_anchor(_raw_cell)
	_ghost.set_valid(true)
	_bridge_ghost.set_block(_phase.current_player().bridge)
	_bridge_ghost.set_rotation_steps(_bridge_plan["bridge_rot"])
	_bridge_ghost.set_anchor(_bridge_plan["bridge_anchor"])
	_bridge_ghost.set_valid(true)
	_bridge_ghost.visible = true


func _try_place() -> void:
	if _dragged_piece() == null or not _over_board:
		return
	if _dragging_bridge:
		if not _candidates.is_empty():
			var b: Dictionary = _candidates[_choice]
			_phase.try_place_bridge(b["cell"], b["rot"])
		return
	if not _candidates.is_empty():
		var c: Dictionary = _candidates[_choice]
		_phase.try_place(_selected_index, c["cell"], c["rot"])
	elif not _bridge_plan.is_empty():
		_phase.try_place_with_bridge(_selected_index, _raw_cell, _bridge_plan["block_rot"], _bridge_plan["bridge_anchor"], _bridge_plan["bridge_rot"])
