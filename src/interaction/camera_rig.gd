class_name CameraRig
extends Camera3D
## Pan & zoom for the orthographic top-down camera, on mouse and touch.
##
## Mouse: wheel zooms, right-drag pans. Touch: two fingers pinch-zoom and pan together
## (a single finger is left for the placement controller). Trackpad: pinch (magnify) zooms,
## two-finger swipe (pan gesture) pans. On-screen +/- buttons drive zoom via [method zoom_in] /
## [method zoom_out]. Movement stays on the XZ plane.

@export var min_size: float = 4.0
@export var max_size: float = 60.0
@export var zoom_step: float = 0.1
## Step applied by the on-screen +/- buttons (one click ≈ 20% zoom).
@export var button_zoom_factor: float = 1.2
## Trackpad two-finger swipe speed: the gesture delta is tiny, so scale it up to pixel-like motion.
@export var pan_gesture_speed: float = 12.0

var _mouse_panning: bool = false
var _touches: Dictionary = {}  # touch index -> Vector2 position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_panning:
		_pan_by_pixels(event.relative)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMagnifyGesture:
		# Trackpad pinch: factor > 1 means fingers spread → zoom in (smaller ortho size).
		_zoom(1.0 / event.factor)
	elif event is InputEventPanGesture:
		# Trackpad two-finger swipe: the board follows the fingers.
		_pan_by_pixels(event.delta * pan_gesture_speed)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(1.0 - zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(1.0 + zoom_step)
		MOUSE_BUTTON_RIGHT:
			_mouse_panning = event.pressed


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Dictionary = _touches.duplicate()
	_touches[event.index] = event.position
	if _touches.size() != 2:
		return  # single finger belongs to the placement controller
	var keys := _touches.keys()
	var prev_a: Vector2 = previous[keys[0]]
	var prev_b: Vector2 = previous[keys[1]]
	var cur_a: Vector2 = _touches[keys[0]]
	var cur_b: Vector2 = _touches[keys[1]]
	# Pan by the midpoint movement.
	_pan_by_pixels((cur_a + cur_b - prev_a - prev_b) * 0.5)
	# Zoom by the change in finger spacing.
	var prev_dist := prev_a.distance_to(prev_b)
	var cur_dist := cur_a.distance_to(cur_b)
	if prev_dist > 0.0 and cur_dist > 0.0:
		_zoom(prev_dist / cur_dist)
	get_viewport().set_input_as_handled()


## Zooms in one button step (closer view, smaller ortho size).
func zoom_in() -> void:
	_zoom(1.0 / button_zoom_factor)


## Zooms out one button step (wider view, larger ortho size).
func zoom_out() -> void:
	_zoom(button_zoom_factor)


func _zoom(factor: float) -> void:
	size = clampf(size * factor, min_size, max_size)


# Moves the camera opposite to a screen-space drag so the world appears to follow the pointer.
func _pan_by_pixels(delta_px: Vector2) -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0:
		return
	var units_per_px := size / viewport_height
	position.x -= delta_px.x * units_per_px
	position.z -= delta_px.y * units_per_px
