extends Node3D
## Standalone interactive 3D demo for the Deck feature, played on a felt mat.
##
## Click the PIOCHE to draw 2 cards face up. Click one to choose it (the other goes to DÉFAUSSE).
## Click the chosen card again to ACTIVATE its power — then it too goes to DÉFAUSSE. When the PIOCHE
## is empty, click the full DÉFAUSSE to gather it back and reshuffle into a fresh pile (visibly).
## Drag the background to orbit, wheel to zoom. Card fronts are placeholder art.

const _DRAW_COUNT := 2
const _STACK_STEP := 0.012  # vertical gap between stacked cards

const _DRAW_POS := Vector3(-2.6, 0.0, 0.0)
const _DISCARD_POS := Vector3(2.6, 0.0, 0.0)
const _ACTIVE_POS := Vector3(0.0, 0.0, 1.7)  # where the chosen card waits to be activated
const _REVEAL_POS: Array[Vector3] = [Vector3(-0.7, 0.0, 0.4), Vector3(0.7, 0.0, 0.4)]

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
var _revealed: Array[Dictionary] = []  # the two drawn cards awaiting a choice
var _chosen: Dictionary = {}  # the chosen card awaiting power activation ({ "view", "card" })
var _reshuffles := 0
var _busy := false  # true while the reshuffle animation plays
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
	_build_mat()

	_deck = Deck.new(_build_cards())
	_deck.reshuffled.connect(_on_reshuffled)
	_deck.shuffle()
	_refresh_piles()
	_refresh_counts()


func _build_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	# Keep an even deck so drawing in pairs always empties the pile to exactly 0 — no stranded card.
	var deck_size := _FRONTS.size() - (_FRONTS.size() % 2)
	for i in deck_size:
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
	if _busy:
		return
	if not _chosen.is_empty():
		# A chosen card waits to be activated: click it to fire its power, then discard it.
		if _pick([_chosen["view"]], screen_pos) != null:
			_activate_chosen()
		else:
			_orbiting = true
		return
	if not _revealed.is_empty():
		# Two cards are up: click one to choose it (the other is discarded).
		var picked := _pick(_revealed_views(), screen_pos)
		if picked != null:
			_choose(picked)
		else:
			_orbiting = true
		return
	# Idle: clicking the PIOCHE draws; clicking the full DÉFAUSSE (when the pile is empty) reshuffles.
	if _hits_pile(screen_pos, _DRAW_POS):
		_draw_cards()
	elif _hits_pile(screen_pos, _DISCARD_POS) and _deck.draw_count() < _DRAW_COUNT and _deck.discard_count() > 0:
		_animate_reshuffle()
	else:
		_orbiting = true


# True when the cursor points at the card slot centered on [param center] (projected onto the mat).
func _hits_pile(screen_pos: Vector2, center: Vector3) -> bool:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.00001:
		return false
	var t := -origin.y / dir.y
	if t <= 0.0:
		return false
	var hit := origin + dir * t
	return Vector2(hit.x - center.x, hit.z - center.z).length() < 0.9


func _draw_cards() -> void:
	if _busy or not _revealed.is_empty() or not _chosen.is_empty():
		return  # busy, a choice is pending, or a chosen card still needs activating
	if _deck.draw_count() < _DRAW_COUNT:
		return  # pile too low — click the full DÉFAUSSE to rebuild a fresh pile
	_deal()


func _deal() -> void:
	var cards := _deck.draw(_DRAW_COUNT)
	if cards.is_empty():
		return
	var lift_off := _DRAW_POS + Vector3(0.0, maxi(_deck.draw_count(), 1) * _STACK_STEP, 0.0)
	for i in cards.size():
		# Start on top of the draw pile, face down, then deal in an arc to the reveal slot.
		var view := _make_view(cards[i], false, lift_off)
		view.animate_deal(_REVEAL_POS[i % _REVEAL_POS.size()], i * 0.12)
		_revealed.append({"view": view, "card": cards[i]})
	_refresh_piles()
	_refresh_counts()


# Visibly gathers the discard pile back to the draw pile, reshuffles, and brews a wobble.
func _animate_reshuffle() -> void:
	_busy = true
	var loose: Array[CardView] = []
	loose.append_array(_discard_stack)
	_discard_stack.clear()

	# Fly every discarded card back onto the draw pile, face down.
	for i in loose.size():
		loose[i].animate_gather(_DRAW_POS + Vector3(0.0, i * _STACK_STEP, 0.0), i * 0.03)
	await get_tree().create_timer(0.45 + loose.size() * 0.03).timeout
	for view in loose:
		view.queue_free()

	_deck.reshuffle()  # discard -> draw, shuffled (emits reshuffled -> counter++)
	_refresh_piles()  # the draw pile is now full
	await _shuffle_wobble()
	_refresh_counts()
	_busy = false


# A quick side-to-side jiggle of the draw pile to read as "shuffling".
func _shuffle_wobble() -> void:
	for view in _draw_stack:
		var base := view.position
		var tween := view.create_tween()
		var jitter := Vector3(randf_range(-0.12, 0.12), 0.0, randf_range(-0.12, 0.12))
		tween.tween_property(view, "position", base + jitter, 0.08)
		tween.tween_property(view, "position", base, 0.12)
	await get_tree().create_timer(0.24).timeout


func _choose(picked: CardView) -> void:
	for entry in _revealed:
		var view: CardView = entry["view"]
		if view == picked:
			view.animate_move_to(_ACTIVE_POS)
			_chosen = entry
		else:
			# The non-chosen card goes back on top of the draw pile.
			_deck.return_to_top(entry["card"])
			view.animate_gather(_DRAW_POS + Vector3(0.0, _deck.draw_count() * _STACK_STEP, 0.0))
			_free_after(view, 0.45)
	_revealed.clear()
	_refresh_piles()
	_refresh_counts()


# Frees [param node] after [param delay] seconds (once an animation has landed).
func _free_after(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


func _activate_chosen() -> void:
	_busy = true
	var entry := _chosen
	_chosen = {}
	var view: CardView = entry["view"]
	_spawn_power_popup(_ACTIVE_POS)
	await view.animate_activate()  # power fires, then the card goes to the discard
	view.animate_discard(_DISCARD_POS + Vector3(0.0, _deck.discard_count() * _STACK_STEP, 0.0))
	_deck.discard(entry["card"])
	_busy = false
	_refresh_piles()
	_refresh_counts()


# A floating "power fired" label that rises and fades over the active slot.
func _spawn_power_popup(at: Vector3) -> void:
	var label := Label3D.new()
	label.text = "POUVOIR ACTIVÉ !"
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color("ffd54f")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at + Vector3(0.0, 0.6, 0.0)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3(0.0, 1.0, 0.0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)


func _on_reshuffled() -> void:
	_reshuffles += 1
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
	# Real counts — the draw pile shows exactly what's left (its slot stays clickable when empty).
	_rebuild_stack(_draw_stack, _deck.draw_count(), _DRAW_POS, false)
	_rebuild_stack(_discard_stack, _deck.discard_count(), _DISCARD_POS, true)


# The felt mat plus labelled card slots for PIOCHE / DÉFAUSSE / the active card.
func _build_mat() -> void:
	var mat := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.5, 5.5)
	mat.mesh = plane
	mat.position = Vector3(0.0, -0.06, 0.3)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("1f4a3a")  # green felt
	mat.material_override = felt
	add_child(mat)

	_build_slot(_DRAW_POS, "PIOCHE")
	_build_slot(_DISCARD_POS, "DÉFAUSSE")
	_build_slot(_ACTIVE_POS, "CARTE ACTIVE")


# A flat card-sized slot with a label, marking a zone on the mat.
func _build_slot(at: Vector3, label_text: String) -> void:
	var slot := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CardView.WIDTH * 1.08, 0.02, CardView.HEIGHT * 1.08)
	slot.mesh = box
	slot.position = at - Vector3(0.0, 0.05, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("16352a")
	slot.material_override = material
	add_child(slot)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 56
	label.pixel_size = 0.004
	label.modulate = Color("d8e8df")
	label.rotation_degrees = Vector3(-90, 0, 0)  # lie flat on the mat
	label.position = at + Vector3(0.0, -0.04, CardView.HEIGHT * 0.5 + 0.45)
	add_child(label)


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
	hint.text = "Clic PIOCHE : tirer 2 cartes   •   Clic carte : la choisir (l'autre → défausse)   •   Re-clic carte choisie : activer le pouvoir → défausse   •   PIOCHE vide ? clic DÉFAUSSE : remélanger   •   Glisser : orbiter   •   Molette : zoom"
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_count_label = Label.new()
	_count_label.position = Vector2(16, 36)
	layer.add_child(_count_label)
	add_child(layer)


func _refresh_counts() -> void:
	_count_label.text = "Pioche : %d   Défausse : %d   Remélanges : %d" % [
		_deck.draw_count(), _deck.discard_count(), _reshuffles,
	]
