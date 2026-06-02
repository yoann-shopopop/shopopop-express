extends Node3D
## Standalone interactive 3D demo for the Movement feature — no Board, no Pawn.
##
## A region of hex cells, a marker on the current cell, and a fixed dice budget. Legal next cells
## are highlighted green: click one to advance. The full budget must be spent; visited cells can't
## be re-entered; if you trap yourself the movement ends (stuck). Drag the background to orbit,
## wheel to zoom, press R to roll a fresh budget and restart.

const _REGION_SIDE := 4  # side-4 hex disk = 37 cells
const _BUDGET := 6
const _MARKER_LIFT := 0.18

const _COLOR_BASE := Color("3a4658")
const _COLOR_VISITED := Color("5b6b86")
const _COLOR_LEGAL := Color("4caf50")
const _COLOR_CURRENT := Color("ffd54f")

var _walkable: Dictionary = {}
var _tiles: Dictionary = {}  # Vector2i -> MeshInstance3D
var _movement: Movement
var _marker: Node3D
var _status_label: Label

# Orbit camera state.
var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 0.0
var _orbit_pitch := -55.0
var _orbit_distance := 13.0
var _orbiting := false


func _ready() -> void:
	_build_camera()
	_build_light()
	_build_environment()
	_build_hud()
	_build_region()
	_build_marker()
	_restart()


func _build_region() -> void:
	for cell in BlockDefinition.make_hexagon_cells(_REGION_SIDE):
		_walkable[cell] = true
		var tile := MeshInstance3D.new()
		tile.mesh = HexMeshFactory.create_tile(GameConfig.HEX_SIZE * 0.96, GameConfig.TILE_HEIGHT)
		tile.position = HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
		var material := StandardMaterial3D.new()
		material.albedo_color = _COLOR_BASE
		tile.material_override = material
		add_child(tile)
		_tiles[cell] = tile


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = GameConfig.HEX_SIZE * 0.5
	disc.bottom_radius = GameConfig.HEX_SIZE * 0.5
	disc.height = 0.22
	disc.radial_segments = 32
	_marker.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff7043")
	_marker.material_override = material
	add_child(_marker)


func _restart() -> void:
	_movement = Movement.new(_walkable, Vector2i.ZERO, _BUDGET)
	_refresh()


# --- Interaction -------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_left_pressed(event.position)
				else:
					_orbiting = false
			MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(5.0, _orbit_distance - 0.8)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(30.0, _orbit_distance + 0.8)
				_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		_orbit_yaw -= event.relative.x * 0.4
		_orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.4, -85.0, -15.0)
		_update_camera()


func _on_left_pressed(screen_pos: Vector2) -> void:
	var cell := _cell_under(screen_pos)
	if _movement.legal_moves().has(cell):
		_movement.step(cell)
		_refresh()
	else:
		_orbiting = true  # clicked off a legal cell: orbit instead


# Projects the cursor onto the board plane (y = 0) and returns the axial cell there.
func _cell_under(screen_pos: Vector2) -> Vector2i:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.00001:
		return Vector2i(9999, 9999)
	var t := -origin.y / dir.y
	if t <= 0.0:
		return Vector2i(9999, 9999)
	return HexUtils.world_to_axial(origin + dir * t, GameConfig.HEX_SIZE)


# --- Presentation ------------------------------------------------------------------------------

func _refresh() -> void:
	var visited := {}
	for cell in _movement.path():
		visited[cell] = true
	var legal := {}
	for cell in _movement.legal_moves():
		legal[cell] = true

	for cell in _tiles:
		var color := _COLOR_BASE
		if cell == _movement.current():
			color = _COLOR_CURRENT
		elif legal.has(cell):
			color = _COLOR_LEGAL
		elif visited.has(cell):
			color = _COLOR_VISITED
		(_tiles[cell].material_override as StandardMaterial3D).albedo_color = color

	_marker.position = HexUtils.axial_to_world(_movement.current(), GameConfig.HEX_SIZE) \
		+ Vector3(0.0, GameConfig.TILE_HEIGHT * 0.5 + _MARKER_LIFT, 0.0)

	var status := "En cours"
	if _movement.is_complete():
		status = "Terminé ✓"
	elif _movement.is_stuck():
		status = "Bloqué (jet perdu : %d)" % _movement.remaining()
	_status_label.text = "Jet : %d   Restant : %d   %s" % [_BUDGET, _movement.remaining(), status]


# --- Scene scaffolding -------------------------------------------------------------------------

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 55.0
	_camera_pivot.add_child(_camera)
	_camera.current = true
	_update_camera()


func _update_camera() -> void:
	_camera_pivot.rotation_degrees = Vector3(_orbit_pitch, _orbit_yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _orbit_distance)
	_camera.rotation = Vector3.ZERO


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -35, 0)
	light.shadow_enabled = true
	add_child(light)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141a24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a0")
	env.ambient_light_energy = 0.9
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = "Clic sur une case verte : avancer   •   R : relancer le jet   •   Glisser le fond : orbiter   •   Molette : zoom"
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_status_label = Label.new()
	_status_label.position = Vector2(16, 36)
	layer.add_child(_status_label)
	add_child(layer)
