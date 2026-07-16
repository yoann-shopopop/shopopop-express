class_name MovementController
extends Node
## Turns pointer input on the board into cell hover/click intents. Casts a ray from the camera onto
## the board plane, converts the hit to an axial cell (same picking as [PlacementController]), and
## emits a signal — it does not touch [GamePhase] itself; GameRoot resolves a signal into a
## [method TurnMovement.path_to] preview or an animated multi-cell walk. Stays dumb: no game rules,
## no rendering.

signal cell_hovered(cell: Vector2i)  ## the pointer moved onto a different cell (mouse only)
signal hover_cleared                 ## nothing is hovered anymore
signal cell_clicked(cell: Vector2i)  ## a click/tap resolved to this cell

const BOARD_PLANE := Plane(Vector3.UP, 0.0)

var _camera: Camera3D
var _hovering: bool = false
var _last_hover: Vector2i


func setup(camera: Camera3D) -> void:
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseMotion:
		_handle_hover(event.position)
		return
	var pressed_left: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var pressed_touch: bool = event is InputEventScreenTouch and event.pressed
	if not (pressed_left or pressed_touch):
		return
	var cell = _cell_at(event.position)
	if cell != null:
		cell_clicked.emit(cell)


func _handle_hover(screen_pos: Vector2) -> void:
	var cell = _cell_at(screen_pos)
	if cell == null:
		if _hovering:
			_hovering = false
			hover_cleared.emit()
		return
	if _hovering and cell == _last_hover:
		return  # unchanged: don't spam the (potentially expensive) BFS preview every mouse-motion event
	_hovering = true
	_last_hover = cell
	cell_hovered.emit(cell)


# Resolves a screen position to the axial cell it projects onto, or null if the ray misses the board
# plane (near-parallel rays only — practically always hits under the fixed top-down camera).
func _cell_at(screen_pos: Vector2) -> Variant:
	var hit = BOARD_PLANE.intersects_ray(
		_camera.project_ray_origin(screen_pos),
		_camera.project_ray_normal(screen_pos))
	if hit == null:
		return null
	return HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE)
