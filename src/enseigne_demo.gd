extends Node3D
## Standalone demo for the delivery-combo generator. A felt mat shows a column of clipped combos
## (enseigne + status insert + destinataire). Click a combo to advance its status; once EN_COURS, the
## next click delivers it — the recipient is discarded and a new one is clipped from the pool until it
## runs out. Drag to orbit, wheel to zoom.

const ENSEIGNES_DIR := "res://resources/enseignes/"
const DESTINATAIRES_DIR := "res://resources/destinataires/"
const SLOTS := 4
const ROW_STEP := 1.7  # vertical spacing between combos on the mat

var _generator: DeliveryGenerator
var _views: Array[ClipCardView] = []
var _count_label: Label

var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 0.0
var _orbit_pitch := -55.0
var _orbit_distance := 12.0
var _orbiting := false


func _ready() -> void:
	_build_camera()
	_build_light()
	_build_environment()
	_build_mat()
	_build_hud()

	_generator = DeliveryGenerator.new(_load_enseignes(), _load_destinataires(), SLOTS)
	_generator.combo_changed.connect(_on_combo_changed)
	_generator.recycled.connect(_on_combo_changed)
	_generator.exhausted.connect(_on_exhausted)
	_build_views()
	_refresh_count()


func _build_views() -> void:
	for view in _views:
		view.queue_free()
	_views.clear()
	var combos := _generator.combos()
	var top := (combos.size() - 1) * 0.5 * ROW_STEP
	for i in combos.size():
		var view := ClipCardView.new()
		add_child(view)
		view.bind(combos[i])
		view.position = Vector3(0.0, 0.0, top - i * ROW_STEP)
		_views.append(view)


func _on_combo_changed(index: int) -> void:
	if index < _views.size():
		_views[index].bind(_generator.combos()[index])  # full rebuild (status insert + new destinataire)
	_refresh_count()


func _on_exhausted() -> void:
	_count_label.text = "Pioche épuisée — plus de destinataire à clipser."


# --- Interaction -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_left_pressed(event.position)
				else:
					_orbiting = false
			MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(5.0, _orbit_distance - 0.7)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(28.0, _orbit_distance + 0.7)
				_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		_orbit_yaw -= event.relative.x * 0.4
		_orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.4, -85.0, -15.0)
		_update_camera()


func _on_left_pressed(screen_pos: Vector2) -> void:
	var index := _combo_under(screen_pos)
	if index < 0:
		_orbiting = true
		return
	var combo := _generator.combos()[index]
	if combo.status == DeliveryStatus.Kind.EN_COURS:
		_generator.complete(index)
	else:
		_generator.advance(index)


# Index of the combo view nearest the cursor ray (within a radius), or -1.
func _combo_under(screen_pos: Vector2) -> int:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best := -1
	var best_along := INF
	for i in _views.size():
		var to_center: Vector3 = _views[i].global_position - origin
		var along := to_center.dot(dir)
		if along <= 0.0:
			continue
		var closest := origin + dir * along
		if closest.distance_to(_views[i].global_position) <= 1.4 and along < best_along:
			best_along = along
			best = i
	return best


func _refresh_count() -> void:
	_count_label.text = "Destinataires restants dans la pioche : %d" % _generator.remaining_recipients()


# --- Data --------------------------------------------------------------------

func _load_enseignes() -> Array[EnseigneDefinition]:
	var result: Array[EnseigneDefinition] = []
	var dir := DirAccess.open(ENSEIGNES_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(ENSEIGNES_DIR + file))
	return result


func _load_destinataires() -> Array[DestinataireDefinition]:
	var result: Array[DestinataireDefinition] = []
	var dir := DirAccess.open(DESTINATAIRES_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(DESTINATAIRES_DIR + file))
	return result


# --- Scaffolding (mirrors card_demo) -----------------------------------------

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
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
	light.rotation_degrees = Vector3(-60, -35, 0)
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


func _build_mat() -> void:
	var mat := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9.0, 9.0)
	mat.mesh = plane
	mat.position = Vector3(0.0, -0.06, 0.0)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("1f4a3a")
	mat.material_override = felt
	add_child(mat)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = "Clic sur une livraison : avancer son statut (Disponible → Réservé → En cours → Livrer = recyclage)   •   Glisser : orbiter   •   Molette : zoom"
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_count_label = Label.new()
	_count_label.position = Vector2(16, 36)
	layer.add_child(_count_label)
	add_child(layer)
