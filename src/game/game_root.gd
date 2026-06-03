class_name GameRoot
extends Node3D
## Composition root for the play phase, taking over once setup is finished. Wires the pure [GamePhase]
## to the world: a [DiceRoller], one [Pawn] + [PawnView] per player, drive/recipient markers, a
## [MovementController] for input and a [PlayHud]. Mirrors what [Main] does for the setup phase.

const EVENTS_DIR := "res://resources/events/"
const ENSEIGNES_DIR := "res://resources/enseignes/"
const DESTINATAIRES_DIR := "res://resources/destinataires/"
const _REF_SIZE := 30.0  # the camera's default ortho size; overlays scale relative to it

var _board: Board
var _players: Array[Player]
var _camera: Camera3D
var _phase: GamePhase
var _dice: DiceRoller
var _events: Deck
var _ui: PlayHud
var _pawns: Dictionary = {}            # player index -> Pawn
var _recipient_markers: Dictionary = {}  # Delivery -> Node3D (rebuilt on recycle)
var _status_rings: Dictionary = {}     # Delivery -> Node3D (status disc on the drive cell)
var _can_roll: bool = true
var _dice_views: Node3D                 # holder for the rolled 3D dice
var _budget_cubes: Node3D               # holder for the remaining movement budget cubes
var _highlights: Node3D                 # holder for the reachable-cell markers
var _event_choice: EventCardChoice      # active card choice, if any
var _delivery_list: DeliveryListView


func setup(board: Board, players: Array[Player], camera: Camera3D) -> void:
	_board = board
	_players = players
	_camera = camera
	var deliveries := DeliverySetup.build(board)
	# Each tile becomes an enseigne slot clipped with a random destinataire; delivering recycles a new
	# one until the pool is exhausted (DeliveryGenerator). One slot per deliverable tile.
	var generator := DeliveryGenerator.new(_load_enseignes(), _load_destinataires(), deliveries.size())
	var combos := generator.combos()
	for i in deliveries.size():
		if i < combos.size():
			deliveries[i].enseigne = combos[i].enseigne
			deliveries[i].destinataire = combos[i].destinataire
	_phase = GamePhase.new(players, board, deliveries, generator)
	_dice = DiceRoller.new()
	_events = Deck.new(_load_events())
	_events.shuffle()

	_ui = PlayHud.new()
	add_child(_ui)
	_ui.setup_players(players)
	_dice_views = Node3D.new()
	add_child(_dice_views)
	_budget_cubes = Node3D.new()
	add_child(_budget_cubes)
	_highlights = Node3D.new()
	add_child(_highlights)

	for player in players:
		_spawn_pawn(player)
	_build_delivery_markers(deliveries)
	_delivery_list = DeliveryListView.new()
	add_child(_delivery_list)
	_delivery_list.build(deliveries, _players)

	var move_controller := MovementController.new()
	add_child(move_controller)
	move_controller.setup(camera, _phase)

	_phase.pawn_moved.connect(_on_pawn_moved)
	_phase.turn_changed.connect(_on_turn_changed)
	_phase.delivery_completed.connect(_on_delivery_completed)
	_phase.delivery_reserved.connect(_on_delivery_changed)
	_phase.delivery_in_progress.connect(_on_delivery_changed)
	_phase.game_finished.connect(_on_game_finished)
	_phase.event_triggered.connect(_on_event_triggered)
	_ui.roll_requested.connect(_on_roll)
	_ui.end_turn_requested.connect(_phase.end_turn)
	_ui.reserve_requested.connect(_on_reserve)
	_ui.power_requested.connect(_on_power)
	var camera_rig := camera as CameraRig
	if camera_rig != null:
		_ui.zoom_in_requested.connect(camera_rig.zoom_in)
		_ui.zoom_out_requested.connect(camera_rig.zoom_out)
	_fit_camera_to_board()
	_refresh_ui()


# Centers the camera on the placed board and zooms so it fills the framed region at game start (the
# player can still pan/zoom afterwards). Without this the small board floats in a large empty view.
func _fit_camera_to_board() -> void:
	var cells := _board.occupied_cells()
	if cells.is_empty():
		return
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for c in cells:
		var w := HexUtils.axial_to_world(c, GameConfig.HEX_SIZE)
		min_x = minf(min_x, w.x); max_x = maxf(max_x, w.x)
		min_z = minf(min_z, w.z); max_z = maxf(max_z, w.z)
	var pad := GameConfig.HEX_SIZE * 2.0
	var board_w := (max_x - min_x) + pad
	var board_h := (max_z - min_z) + pad
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.aspect() if vp.y > 0.0 else 1.78
	# The board sits between the left delivery column and the right character card: ~80% of the height,
	# ~54% of the width. Take the larger so it always fits both ways.
	var size_for_h := board_h / 0.80
	var size_for_w := board_w / (0.54 * aspect)
	var target := maxf(size_for_h, size_for_w)
	var rig := _camera as CameraRig
	if rig != null:
		target = clampf(target, rig.min_size, rig.max_size)
	_camera.size = target
	var half_h := target * 0.5
	var half_w := half_h * aspect
	# Center the board between the left delivery column and the right character card (nx ≈ 0.08, just
	# right of screen center; vertically centered).
	var board_cx := (min_x + max_x) * 0.5
	var board_cz := (min_z + max_z) * 0.5
	_camera.position = Vector3(board_cx - 0.08 * half_w, _camera.position.y, board_cz + 0.0 * half_h)


# Pins the dice (bottom-left) and the event-card choice (centered) to fixed screen regions, scaled to
# the zoom, so they keep a consistent size and use the available space whatever the pan/zoom.
func _process(_delta: float) -> void:
	if _camera == null:
		return
	var zoom := _camera.size / _REF_SIZE
	var half_h := _camera.size * 0.5
	var half_w := half_h * get_viewport().get_visible_rect().size.aspect()
	var center := Vector3(_camera.global_position.x, 0.0, _camera.global_position.z)
	# All HUD overlays use a constant world-scale × zoom and screen-edge anchoring, so they keep a fixed
	# on-screen size/position: zooming only changes the terrain, never the side elements.
	if _dice_views != null and _dice_views.get_child_count() > 0:
		_dice_views.position = center + Vector3(-half_w * 0.70, 1.0, half_h * 0.42)
		_dice_views.scale = Vector3.ONE * 3.2 * zoom
	if _budget_cubes != null and _budget_cubes.get_child_count() > 0:
		# Clearly to the right of the die, never overlapping it.
		_budget_cubes.position = center + Vector3(-half_w * 0.46, 1.0, half_h * 0.50)
		_budget_cubes.scale = Vector3.ONE * 1.5 * zoom
	if _event_choice != null and is_instance_valid(_event_choice):
		# Drawn event cards: large, near screen center so they're unmistakable during a rainbow event.
		_event_choice.position = center + Vector3(0.0, 1.0, half_h * 0.10)
		_event_choice.scale = Vector3.ONE * 5.5 * zoom
	if _delivery_list != null:
		# Left column: big readable cards with a CONSTANT on-screen gap (row_step is constant×zoom, not
		# size-dependent), stacked down the left edge.
		var left_origin := center + Vector3(-half_w * 0.70, 1.0, -half_h * 0.55)
		_delivery_list.layout(left_origin, 3.9 * zoom, 1.4 * zoom)


func _spawn_pawn(player: Player) -> void:
	var def := PawnDefinition.new()
	def.type = PawnDefinition.PawnType.COTRANSPORTER
	def.color = PlayerColor.to_color(player.color)
	var pawn := Pawn.new(def)
	var view := PawnView.new()
	add_child(view)
	view.bind(pawn)
	pawn.place(_phase.position_of(player))
	_pawns[player.index] = pawn


func _build_delivery_markers(deliveries: Array[Delivery]) -> void:
	for delivery in deliveries:
		add_child(_drive_token(delivery))
		_rebuild_recipient_marker(delivery)


# A drive token: a PawnView in DRIVE token-mode carrying the enseigne logo, placed on the drive cell.
func _drive_token(delivery: Delivery) -> PawnView:
	var def := PawnDefinition.new()
	def.type = PawnDefinition.PawnType.DRIVE
	def.texture = delivery.enseigne.texture if delivery.enseigne != null else null
	return _token_at(def, delivery.drive_cell)


# A recipient token: a PawnView in RECIPIENT token-mode carrying the destinataire portrait.
func _destinataire_token(delivery: Delivery) -> PawnView:
	var def := PawnDefinition.new()
	def.type = PawnDefinition.PawnType.RECIPIENT
	def.texture = delivery.destinataire.texture if delivery.destinataire != null else null
	return _token_at(def, delivery.recipient_cell)


# Builds a fixed (non-mobile) PawnView bound to a one-shot Pawn placed on [param cell].
func _token_at(def: PawnDefinition, cell: Vector2i) -> PawnView:
	var pawn := Pawn.new(def)
	var view := PawnView.new()
	view.bind(pawn)
	pawn.place(cell)
	return view


# (Re)builds the recipient token for [param delivery], reflecting its current destinataire.
func _rebuild_recipient_marker(delivery: Delivery) -> void:
	var existing = _recipient_markers.get(delivery, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
	var token := _destinataire_token(delivery)
	add_child(token)
	_recipient_markers[delivery] = token


func _on_roll() -> void:
	if not _can_roll or _phase.current_subphase() != GamePhase.SubPhase.PLANIFICATION:
		return
	var player := _phase.current_player()
	var dice_count := player.character.dice_count() if player.character != null else 2
	_dice.roll(dice_count)
	_phase.begin_movement(_dice.total())
	_show_budget(_dice.total())
	_phase.movement().step_budget_changed.connect(_on_budget_changed)
	_can_roll = false
	_show_dice(_dice.values())
	_refresh_highlights()
	_ui.set_status("Dés : %s — déplacement : %d (clique une case verte)" % [str(_dice.values()), _dice.total()])
	_refresh_ui()


func _show_dice(values: Array) -> void:
	_clear_dice()
	var n := values.size()
	for i in n:
		var die := DieView.new()
		_dice_views.add_child(die)
		# Local offsets around the holder origin; the holder is pinned to a screen corner by _process.
		die.position = Vector3((i - (n - 1) * 0.5) * 1.2, 0.0, 0.0)
		die.roll_to(values[i])


func _clear_dice() -> void:
	for child in _dice_views.get_children():
		child.queue_free()
	_show_budget(0)


## Shows [param remaining] little cubes = remaining movement budget.
func _show_budget(remaining: int) -> void:
	for child in _budget_cubes.get_children():
		child.queue_free()
	for i in remaining:
		var inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 0.4, 0.4)
		inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e6b800")
		inst.material_override = mat
		# Wrap into rows of 3 so a big budget stays a compact little block, not a long line.
		inst.position = Vector3((i % 3) * 0.55, 0.0, (i / 3) * 0.55)
		_budget_cubes.add_child(inst)


# Green markers on the cells the current pawn can step onto right now (empty outside movement).
func _refresh_highlights() -> void:
	for child in _highlights.get_children():
		child.queue_free()
	var movement := _phase.movement()
	if movement == null or _phase.current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
		return
	for cell in movement.legal_moves():
		_highlights.add_child(_highlight_marker(cell))


func _highlight_marker(cell: Vector2i) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = GameConfig.HEX_SIZE * 0.5
	mesh.bottom_radius = GameConfig.HEX_SIZE * 0.5
	mesh.height = 0.06
	mesh.radial_segments = 6
	inst.mesh = mesh
	inst.rotation_degrees = Vector3(0, 30, 0)  # flat-top alignment
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 0.4, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.05
	inst.position = pos
	return inst


func _on_budget_changed(remaining: int) -> void:
	_show_budget(remaining)


func _on_reserve() -> void:
	if _phase.reserve_delivery():
		_ui.set_status("Livraison réservée.")
	else:
		_ui.set_status("Aucune livraison à réserver sur cette tuile.")
	_refresh_highlights()
	_refresh_ui()


# A delivery's status changed (reserved / en cours): refresh its status disc and the action bar.
func _on_delivery_changed(delivery: Delivery) -> void:
	_update_status_ring(delivery)
	if _delivery_list != null:
		_delivery_list.refresh_statuses()
	_refresh_ui()


# A small disc on the drive cell echoing the delivery status: the reserving player's color when
# RESERVE, a brighter accent when EN_COURS, removed otherwise.
func _update_status_ring(delivery: Delivery) -> void:
	var existing = _status_rings.get(delivery, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
		_status_rings.erase(delivery)
	var color: Color
	match delivery.status:
		DeliveryStatus.Kind.RESERVE:
			color = PlayerColor.to_color(_players[delivery.reserved_by].color)
			color.a = 0.55
		DeliveryStatus.Kind.EN_COURS:
			color = Color(1.0, 0.95, 0.4, 0.85)
		_:
			return  # DISPONIBLE / LIVREE: no ring
	var inst := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = GameConfig.HEX_SIZE * 0.42
	mesh.outer_radius = GameConfig.HEX_SIZE * 0.6
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(delivery.drive_cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.08
	inst.position = pos
	add_child(inst)
	_status_rings[delivery] = inst


func _on_event_triggered(cell: Vector2i) -> void:
	# Draw two event cards and show them: the player keeps one (the other returns to the deck) and
	# activates it. Movement is paused (EVENEMENT) until the choice resolves.
	var drawn := _events.draw(2)
	if drawn.is_empty():
		return
	_refresh_highlights()  # clears the markers while the cards are up
	_event_choice = EventCardChoice.new()
	add_child(_event_choice)
	_event_choice.resolved.connect(_on_event_resolved)
	_event_choice.present(drawn, _camera, Vector3.ZERO)  # position pinned each frame by _process
	_ui.set_status("Événement ! Choisis une carte, puis clique-la pour l'activer.")


func _on_event_resolved(chosen: EventCardDefinition, discarded: Array) -> void:
	_phase.apply_event(chosen)
	_events.discard(chosen)
	for card in discarded:
		_events.return_to_top(card)
	_event_choice = null
	var tag := "Malus" if chosen.is_malus else "Avantage"
	_ui.set_status("%s : %s" % [tag, chosen.display_name])
	_refresh_highlights()
	_refresh_ui()


func _on_power() -> void:
	if _phase.use_power():
		_ui.set_status("Super-pouvoir activé !")
		_refresh_highlights()
	_refresh_ui()


func _on_pawn_moved(player: Player, _from: Vector2i, to: Vector2i) -> void:
	var pawn: Pawn = _pawns[player.index]
	pawn.move_to(to)
	_refresh_highlights()
	_refresh_ui()


func _on_turn_changed(_player: Player) -> void:
	_can_roll = true
	_clear_dice()
	_refresh_highlights()
	_refresh_ui()
	_ui.set_status("À toi de jouer — lance les dés.")


func _on_delivery_completed(delivery: Delivery, points: int) -> void:
	# The destinataire was recycled (or cleared) — refresh that delivery's recipient card + status.
	_rebuild_recipient_marker(delivery)
	_update_status_ring(delivery)  # back to DISPONIBLE -> ring removed
	if _delivery_list != null:
		_delivery_list.refresh_statuses()
	_ui.set_status("Livré ! +%d points." % points)
	_refresh_ui()


func _on_game_finished(scores: Dictionary) -> void:
	_ui.show_end(scores, _players)


func _refresh_ui() -> void:
	var player := _phase.current_player()
	_ui.refresh(player, _phase.score_of(player))
	_ui.set_power_available(player.character != null and not player.power_used)
	_ui.set_action(_current_action())


# The contextual primary action: ROLL while planning, RESERVE when standing on a reservable tile,
# else END_TURN (movement spent / nothing to reserve).
func _current_action() -> int:
	if _phase.current_subphase() == GamePhase.SubPhase.PLANIFICATION and _can_roll:
		return PlayHud.Action.ROLL
	if _phase.current_subphase() == GamePhase.SubPhase.DEPLACEMENT and _phase.reservable_delivery() != null:
		return PlayHud.Action.RESERVE
	return PlayHud.Action.END_TURN


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and _delivery_list != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _over_left_region():
			_delivery_list.scroll_by(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _over_left_region():
			_delivery_list.scroll_by(-1)


# True if the mouse is over the left third of the screen (the delivery column).
func _over_left_region() -> bool:
	return get_viewport().get_mouse_position().x < get_viewport().get_visible_rect().size.x * 0.26


func _load_events() -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	var dir := DirAccess.open(EVENTS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(EVENTS_DIR + file))
	return result


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
