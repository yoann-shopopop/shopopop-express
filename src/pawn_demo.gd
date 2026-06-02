extends Node3D
## Standalone, interactive 3D demo for the Pawn feature — NO board involved.
##
## Spawns three poker-chip pawns (a cotransporter and two fixed pawns) with their images. You can
## GRAB a chip with the mouse and rotate it (tumble it in 3D); dragging the empty background orbits
## the camera, and the wheel zooms. Imagery is placeholder (assets/trades/), pending the final map.

const _IMG_COTRANSPORTER := preload("res://assets/trades/CHAREFOUR.webp")
const _IMG_DRIVE := preload("res://assets/trades/IKEO.webp")
const _IMG_RECIPIENT := preload("res://assets/trades/BELLE_FLEUR.webp")

# Orbit camera state — drag the background to rotate, wheel to zoom.
var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 25.0
var _orbit_pitch := -35.0
var _orbit_distance := 7.0
var _orbiting := false

# Grab-and-rotate state.
var _tokens: Array[PawnView] = []
var _grabbed: PawnView = null


func _ready() -> void:
	_build_camera()
	_build_light()
	_build_environment()
	_build_hint()

	_spawn(_make_def(&"axelle", "Axel·le", PawnDefinition.PawnType.COTRANSPORTER, _IMG_COTRANSPORTER), Vector2i(0, 0))
	_spawn(_make_def(&"drive_ikeo", "Drive IKEO", PawnDefinition.PawnType.DRIVE, _IMG_DRIVE), Vector2i(2, 0))
	_spawn(_make_def(&"recipient_fleur", "Belle Fleur", PawnDefinition.PawnType.RECIPIENT, _IMG_RECIPIENT), Vector2i(1, 1))


func _make_def(id: StringName, label: String, type: PawnDefinition.PawnType, tex: Texture2D) -> PawnDefinition:
	var d := PawnDefinition.new()
	d.id = id
	d.display_name = label
	d.type = type
	d.texture = tex
	return d


func _spawn(def: PawnDefinition, cell: Vector2i) -> void:
	var pawn := Pawn.new(def)
	var view := PawnView.new()
	add_child(view)
	view.bind(pawn)
	pawn.place(cell)
	_tokens.append(view)


# --- Input: grab a chip to rotate it, or drag the background to orbit -------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_grabbed = _pick_token(event.position)
					_orbiting = _grabbed == null
				else:
					_grabbed = null
					_orbiting = false
			MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(2.5, _orbit_distance - 0.5)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(20.0, _orbit_distance + 0.5)
				_update_camera()
	elif event is InputEventMouseMotion:
		if _grabbed != null:
			# Tumble the grabbed chip around world axes through its center.
			_grabbed.global_rotate(Vector3.UP, deg_to_rad(-event.relative.x * 0.5))
			_grabbed.global_rotate(Vector3.RIGHT, deg_to_rad(-event.relative.y * 0.5))
		elif _orbiting:
			_orbit_yaw -= event.relative.x * 0.4
			_orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.4, -85.0, -5.0)
			_update_camera()


# Returns the chip under [param screen_pos], or null. Treats each chip as a sphere of CHIP_RADIUS,
# so picking keeps working however the chip is tumbled.
func _pick_token(screen_pos: Vector2) -> PawnView:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var nearest: PawnView = null
	var nearest_along := INF
	for view in _tokens:
		var to_center := view.global_position - origin
		var along := to_center.dot(dir)
		if along <= 0.0:
			continue  # behind the camera
		var closest := origin + dir * along
		if closest.distance_to(view.global_position) <= PawnView.CHIP_RADIUS and along < nearest_along:
			nearest_along = along
			nearest = view
	return nearest


# --- Scene scaffolding -----------------------------------------------------------------------

func _build_camera() -> void:
	# Pivot at the rough center of the pawns; the camera sits back along the pivot's local +Z and
	# faces the pivot. Rotating the pivot orbits the camera around the scene.
	_camera_pivot = Node3D.new()
	_camera_pivot.position = Vector3(1.7, 0.2, 0.6)
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
	env.ambient_light_energy = 0.8
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "Glisser un jeton : le faire tourner   •   Glisser le fond : orbiter   •   Molette : zoom"
	label.position = Vector2(16, 12)
	layer.add_child(label)
	add_child(layer)
