extends Node3D
## Standalone interactive 3D demo for the Deck feature.
##
## Click the draw pile to draw 2 cards face up; click one of them to keep it (it slides to the kept
## slot) — the other is discarded. The pile is endless: when it empties, the discard is reshuffled
## back in. Drag the background to orbit, wheel to zoom. Card fronts use placeholder art.

const _DRAW_COUNT := 2
const _STACK_STEP := 0.012  # vertical gap between stacked cards

const _DRAW_POS := Vector3(-2.6, 0.0, 0.0)
const _DISCARD_POS := Vector3(2.6, 0.0, 1.0)
const _KEPT_POS := Vector3(2.6, 0.0, -1.1)
const _REVEAL_POS: Array[Vector3] = [Vector3(-0.7, 0.0, 0.6), Vector3(0.7, 0.0, 0.6)]

# Placeholder fronts so the revealed cards look distinct.
const _FRONTS: Array[String] = [
	"res://assets/trades/CHAREFOUR.webp",
	"res://assets/trades/IKEO.webp",
	"res://assets/trades/BELLE_FLEUR.webp",
	"res://assets/trades/DECLATON.webp",
	"res://assets/trades/LIDI.webp",
	"res://assets/trades/WINE_MINE.webp",
	"res://assets/trades/BRICO_COCO.webp",
	"res://assets/trades/CHUPER_U.webp",
]

var _deck: Deck
var _draw_stack: Array[CardView] = []
var _discard_stack: Array[CardView] = []
var _kept_stack: Array[CardView] = []
var _revealed: Array[Dictionary] = []  # { "view": CardView, "card": CardDefinition }
var _count_label: Label

# Orbit camera state.
var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 0.0
var _orbit_pitch := -45.0
var _orbit_distance := 8.0
var _orbiting := false


func _ready() -> void:
	_build_camera()
	_build_light()
	_build_environment()
	_build_hud()

	_deck = Deck.new(_build_cards())
	_deck.shuffle()
	_refresh_piles()
	_refresh_counts()


func _build_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for i in _FRONTS.size():
		var c := CardDefinition.new()
		c.id = StringName("card_%d" % i)
		c.display_name = "Carte %d" % i
		c.front_texture = load(_FRONTS[i])
		cards.append(c)
	return cards


# --- Interaction -------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_left_pressed(event.position)
				else:
					_orbiting = false
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


func _on_left_pressed(screen_pos: Vector2) -> void:
	if not _revealed.is_empty():
		# Awaiting a choice: a click on a revealed card keeps it.
		var picked := _pick(_revealed_views(), screen_pos)
		if picked != null:
			_keep(picked)
		return
	# Otherwise, clicking the draw pile draws; clicking elsewhere orbits.
	if _pick(_draw_stack, screen_pos) != null:
		_draw_cards()
	else:
		_orbiting = true


func _draw_cards() -> void:
	var cards := _deck.draw(_DRAW_COUNT)
	if cards.is_empty():
		return
	for i in cards.size():
		var view := _make_view(cards[i], true, _REVEAL_POS[i % _REVEAL_POS.size()])
		_revealed.append({"view": view, "card": cards[i]})
	_refresh_piles()
	_refresh_counts()


func _keep(chosen: CardView) -> void:
	for entry in _revealed:
		var view: CardView = entry["view"]
		if view == chosen:
			view.position = _KEPT_POS + Vector3(0.0, _kept_stack.size() * _STACK_STEP, 0.0)
			_kept_stack.append(view)
		else:
			view.queue_free()
			_deck.discard(entry["card"])
	_revealed.clear()
	_refresh_piles()
	_refresh_counts()


# Returns the nearest view under [param screen_pos] within its PICK_RADIUS, or null.
func _pick(views: Array, screen_pos: Vector2) -> CardView:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var nearest: CardView = null
	var nearest_along := INF
	for view in views:
		var to_center: Vector3 = view.global_position - origin
		var along := to_center.dot(dir)
		if along <= 0.0:
			continue
		var closest := origin + dir * along
		if closest.distance_to(view.global_position) <= CardView.PICK_RADIUS and along < nearest_along:
			nearest_along = along
			nearest = view
	return nearest


func _revealed_views() -> Array[CardView]:
	var views: Array[CardView] = []
	for entry in _revealed:
		views.append(entry["view"])
	return views


# --- Pile visuals (decorative stacks reflecting the deck counts) -------------------------------

func _refresh_piles() -> void:
	_rebuild_stack(_draw_stack, _deck.draw_count(), _DRAW_POS, false)
	_rebuild_stack(_discard_stack, _deck.discard_count(), _DISCARD_POS, true)


# Rebuilds a decorative stack of [param count] cards at [param base], capped for sanity.
func _rebuild_stack(stack: Array[CardView], count: int, base: Vector3, face_up: bool) -> void:
	for view in stack:
		view.queue_free()
	stack.clear()
	var shown := mini(count, 16)
	for i in shown:
		var card := CardDefinition.new()
		var view := _make_view(card, face_up, base + Vector3(0.0, i * _STACK_STEP, 0.0))
		stack.append(view)


func _make_view(card: CardDefinition, face_up: bool, pos: Vector3) -> CardView:
	var view := CardView.new()
	add_child(view)
	view.bind(card)
	view.set_face_up(face_up)
	view.position = pos
	return view


# --- Scene scaffolding -------------------------------------------------------------------------

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.position = Vector3(0.0, 0.0, 0.2)
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
	hint.text = "Clic sur la pioche : tirer 2 cartes   •   Clic sur une carte : la garder (l'autre est défaussée)   •   Glisser le fond : orbiter   •   Molette : zoom"
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_count_label = Label.new()
	_count_label.position = Vector2(16, 36)
	layer.add_child(_count_label)
	add_child(layer)


func _refresh_counts() -> void:
	_count_label.text = "Pioche : %d   Défausse : %d   Gardées : %d" % [
		_deck.draw_count(), _deck.discard_count(), _kept_stack.size(),
	]
