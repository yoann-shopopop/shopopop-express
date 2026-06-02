extends Node3D
## Standalone interactive 3D demo for the DiceRoller feature.
##
## ←/→ choose how many D6 (1–6, default 2); Space rolls them. The dice tumble and settle showing
## the rolled values; the HUD records values + total (DiceRoller is the source of truth). Drag the
## background to orbit, wheel to zoom.

const _MIN_DICE := 1
const _MAX_DICE := 6
const _SPACING := 1.3

var _roller: DiceRoller
var _count := 2
var _dice: Array[DieView] = []
var _status_label: Label

# Orbit camera state.
var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 0.0
var _orbit_pitch := -40.0
var _orbit_distance := 7.0
var _orbiting := false


func _ready() -> void:
	_roller = DiceRoller.new()
	_build_camera()
	_build_light()
	_build_environment()
	_build_hud()
	_rebuild_dice()
	_refresh_status()


# --- Interaction -------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_roll()
			KEY_RIGHT:
				_set_count(_count + 1)
			KEY_LEFT:
				_set_count(_count - 1)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_orbiting = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(3.0, _orbit_distance - 0.6)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(22.0, _orbit_distance + 0.6)
				_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		_orbit_yaw -= event.relative.x * 0.4
		_orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.4, -85.0, -10.0)
		_update_camera()


func _set_count(value: int) -> void:
	var clamped := clampi(value, _MIN_DICE, _MAX_DICE)
	if clamped == _count:
		return
	_count = clamped
	_rebuild_dice()
	_refresh_status()


func _roll() -> void:
	var values := _roller.roll(_count)
	for i in values.size():
		_dice[i].roll_to(values[i])
	_refresh_status()


# --- Dice + HUD --------------------------------------------------------------------------------

func _rebuild_dice() -> void:
	for die in _dice:
		die.queue_free()
	_dice.clear()
	for i in _count:
		var die := DieView.new()
		add_child(die)
		var x := (i - (_count - 1) * 0.5) * _SPACING
		die.position = Vector3(x, 0.0, 0.0)
		die.show_value(1)
		_dice.append(die)


func _refresh_status() -> void:
	if _roller.has_result():
		_status_label.text = "Dés : %d   Résultat : %s   Total : %d" % [
			_count, str(_roller.values()), _roller.total(),
		]
	else:
		_status_label.text = "Dés : %d   (Espace pour lancer)" % _count


# --- Scene scaffolding -------------------------------------------------------------------------

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.position = Vector3(0.0, 0.0, 0.0)
	add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 50.0
	_camera_pivot.add_child(_camera)
	_camera.current = true
	_update_camera()


func _update_camera() -> void:
	_camera_pivot.rotation_degrees = Vector3(_orbit_pitch, _orbit_yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _orbit_distance)
	_camera.rotation = Vector3.ZERO


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.shadow_enabled = true
	add_child(light)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2330")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a0")
	env.ambient_light_energy = 0.9
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = "Espace : lancer   •   ←/→ : nombre de dés (1–6)   •   Glisser le fond : orbiter   •   Molette : zoom"
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_status_label = Label.new()
	_status_label.position = Vector2(16, 36)
	layer.add_child(_status_label)
	add_child(layer)
