extends Node3D
## Standalone, interactive 3D demo for the Pawn feature — NO board involved.
##
## Spawns four cotransporter figures (the classic cone-with-ball pawn) in the player colors, plus a
## drive and a recipient shown as image chips. You can GRAB a pawn with the mouse and rotate it;
## dragging the empty background orbits the camera, and the wheel zooms. Imagery is placeholder.

const _IMG_DRIVE := preload("res://assets/trades/IKEO.webp")
const _IMG_RECIPIENT := preload("res://assets/trades/BELLE_FLEUR.webp")

# Player colors for the cotransporter figures.
const _PLAYER_COLORS: Array[Color] = [
	Color("d64545"), Color("e3c64b"), Color("8e5bd0"), Color("4a78d6"),
]

# Orbit camera state — drag the background to rotate, wheel to zoom.
var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 20.0
var _orbit_pitch := -30.0
var _orbit_distance := 9.0
var _orbiting := false

# Grab-and-rotate state.
var _tokens: Array[PawnView] = []
var _grabbed: PawnView = null


func _ready() -> void:
	_build_camera()
	_build_light()
	_build_environment()
	_build_hint()

	# Four colored player pawns in a row...
	for i in _PLAYER_COLORS.size():
		var player := _make_def(StringName("player_%d" % i), "Joueur %d" % i, PawnDefinition.PawnType.COTRANSPORTER)
		player.color = _PLAYER_COLORS[i]
		_spawn(player, Vector2i(i, 0))
	# ...plus a drive and a recipient as image chips.
	var drive := _make_def(&"drive_ikeo", "Drive IKEO", PawnDefinition.PawnType.DRIVE)
	drive.texture = _IMG_DRIVE
	_spawn(drive, Vector2i(0, 1))
	var recipient := _make_def(&"recipient_fleur", "Belle Fleur", PawnDefinition.PawnType.RECIPIENT)
	recipient.texture = _IMG_RECIPIENT
	_spawn(recipient, Vector2i(2, 1))


func _make_def(id: StringName, label: String, type: PawnDefinition.PawnType) -> PawnDefinition:
	var d := PawnDefinition.new()
	d.id = id
	d.display_name = label
	d.type = type
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
