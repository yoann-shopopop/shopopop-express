class_name PlacementController
extends Node
## Drag-and-drop placement with a road magnet, plus in-turn adjustment of the piece just placed.
##
## The UI starts a drag by pressing a tray preview: a BLOCK or the free BRIDGE. While dragging, the
## ghost follows the pointer and the magnet snaps it to the nearest legal cell+rotation; the rotate
## action cycles candidates. Releasing on a legal spot places the piece (the turn does NOT advance).
##
## After a piece is placed it becomes the [b]active[/b] piece: a floating toolbar (rotate left /
## remove / rotate right) hovers above it, and pressing the board over it picks it back up to
## re-position it (an invalid drop restores its previous spot). Mouse and touch share one path; board
## interaction uses [method _unhandled_input] so UI button presses never reach it.

signal controls_changed(shown: bool, screen_pos: Vector2)  # floating toolbar follow / show-hide
signal drag_changed(active: bool)          # drag started / ended — for drag-only UI affordances

const BOARD_PLANE := Plane(Vector3.UP, 0.0)
const MAGNET_RADIUS := 1
const CONTROLS_OFFSET := 70.0  # pixels above the active piece's centre

var _camera: Camera3D
var _board: Board
var _ghost: BlockGhost
var _phase: SetupPhase

var _dragging: bool = false
var _dragging_bridge: bool = false
var _selected_index: int = 0
var _rotation: int = 0
var _candidates: Array = []            # legal placements [{ "cell", "rot", "d" }], nearest first
var _choice: int = 0
var _raw_cell: Vector2i = Vector2i.ZERO
var _over_board: bool = false
var _has_pointer: bool = false

# Re-positioning: when the active piece is picked back up, restore this transform on an invalid drop.
var _reposition: bool = false
var _repo_anchor: Vector2i = Vector2i.ZERO
var _repo_rotation: int = 0

# The piece placed this turn that carries the floating controls (block or bridge).
var _active: PlacedPiece = null
var _active_is_bridge: bool = false


func setup(camera: Camera3D, board: Board, ghost: BlockGhost, phase: SetupPhase) -> void:
	_camera = camera
	_board = board
	_ghost = ghost
	_phase = phase
	_ghost.visible = false
	_phase.turn_changed.connect(_on_turn_changed)


# A fresh turn clears any active piece and ends any drag.
func _on_turn_changed(_player: Player) -> void:
	_active = null
	_end_drag()


## Starts dragging the current player's block [param index] from the tray. Ignored if a block is
## already placed this turn (one block per turn).
func begin_drag(index: int) -> void:
	if _phase.block_placed_this_turn():
		return
	_reposition = false
	_start_drag(false, index)


## Starts dragging the current player's free bridge from the tray.
func begin_bridge_drag() -> void:
	if _phase.current_player().bridge == null:
		return
	_reposition = false
	_start_drag(true, 0)


## Rotates the active (just-placed) piece one step in [param dir] (+1 / -1), via the floating toolbar.
func rotate_active(dir: int) -> void:
	if _active == null:
		return
	if _active_is_bridge:
		_phase.rotate_bridge(dir)
		_active = _phase.placed_bridge()
	else:
		_phase.rotate_block(dir)
		_active = _phase.placed_block()


## Removes the active piece, returning it to the tray. The other in-turn piece (if any) becomes active.
func remove_active() -> void:
	if _active == null:
		return
	if _active_is_bridge:
		_phase.remove_bridge()
	else:
		_phase.remove_block()
	if _phase.placed_block() != null:
		_active = _phase.placed_block()
		_active_is_bridge = false
	elif _phase.placed_bridge() != null:
		_active = _phase.placed_bridge()
		_active_is_bridge = true
	else:
		_active = null


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
	drag_changed.emit(true)


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


func _unhandled_input(event: InputEvent) -> void:
	if _dragging:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			_update_pointer(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release(event.position)
		elif event is InputEventScreenTouch and not event.pressed:
			_release(event.position)
		elif event.is_action_pressed(&"rotate_block"):
			rotate_current()
		return
	# Not dragging: a press on the board over the active piece picks it back up to re-position it.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_begin_reposition(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_try_begin_reposition(event.position)


func _try_begin_reposition(screen_pos: Vector2) -> void:
	if _active == null or _camera == null:
		return
	var hit = BOARD_PLANE.intersects_ray(_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	if hit == null:
		return
	var cell := HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE)
	if not _active.cells().has(cell):
		return
	# Take the piece off the board (back into the tray) and start dragging it, remembering its spot.
	_repo_anchor = _active.anchor
	_repo_rotation = _active.rotation
	_reposition = true
	if _active_is_bridge:
		_phase.remove_bridge()
		_start_drag(true, 0)
	else:
		_phase.remove_block()
		_start_drag(false, _selected_index)
	_update_pointer(screen_pos)


func _release(screen_pos: Vector2) -> void:
	_update_pointer(screen_pos)
	_try_place()
	_end_drag()


func _end_drag() -> void:
	var was_dragging := _dragging
	_dragging = false
	_dragging_bridge = false
	_reposition = false
	_candidates.clear()
	_choice = 0
	_rotation = 0
	_ghost.visible = false
	_ghost.set_block(null)
	if was_dragging:
		drag_changed.emit(false)


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
		# Nothing legal under the pointer. If we were re-positioning, put the piece back where it was.
		if _reposition:
			_restore_repositioned()
		return
	var c: Dictionary = _candidates[_choice]
	if _dragging_bridge:
		if _phase.try_place_bridge(c["cell"], c["rot"]):
			_active = _phase.placed_bridge()
			_active_is_bridge = true
	else:
		if _phase.try_place(_selected_index, c["cell"], c["rot"]):
			_active = _phase.placed_block()
			_active_is_bridge = false


func _restore_repositioned() -> void:
	if _dragging_bridge:
		if _phase.try_place_bridge(_repo_anchor, _repo_rotation):
			_active = _phase.placed_bridge()
			_active_is_bridge = true
	else:
		if _phase.try_place(_selected_index, _repo_anchor, _repo_rotation):
			_active = _phase.placed_block()
			_active_is_bridge = false


func _process(_delta: float) -> void:
	if _active != null and not _dragging:
		controls_changed.emit(true, _active_screen_pos())
	else:
		controls_changed.emit(false, Vector2.ZERO)


# Screen position a little above the active piece's centre, for the floating toolbar.
func _active_screen_pos() -> Vector2:
	var sum := Vector3.ZERO
	var cells := _active.cells()
	for cell in cells:
		sum += HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	var centre: Vector3 = sum / float(maxi(cells.size(), 1))
	return _camera.unproject_position(centre) - Vector2(0, CONTROLS_OFFSET)
