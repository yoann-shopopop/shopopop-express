class_name MovementController
extends Node
## Turns a click/tap on the board into a movement step. Casts a ray from the camera onto the board
## plane, converts the hit to an axial cell (same picking as [PlacementController]), and asks the
## [GamePhase] to step the current pawn there. The phase rejects illegal steps, so this stays dumb.

const BOARD_PLANE := Plane(Vector3.UP, 0.0)

var _camera: Camera3D
var _phase: GamePhase


func setup(camera: Camera3D, phase: GamePhase) -> void:
	_camera = camera
	_phase = phase


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null or _phase == null:
		return
	var pressed_left: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var pressed_touch: bool = event is InputEventScreenTouch and event.pressed
	if not (pressed_left or pressed_touch):
		return
	var hit = BOARD_PLANE.intersects_ray(
		_camera.project_ray_origin(event.position),
		_camera.project_ray_normal(event.position))
	if hit == null:
		return
	_phase.try_step(HexUtils.world_to_axial(hit, GameConfig.HEX_SIZE))
