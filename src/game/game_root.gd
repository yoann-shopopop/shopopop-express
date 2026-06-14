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
var _highlights: Node3D                 # holder for the reachable-cell markers
var _active_marker: Node3D              # ring under the active pawn + floating steps badge above it
var _event_modal: EventModal            # active event card choice (2D HUD modal), if any
var _delivery_panel: DeliveryPanel


## The pure turn logic, exposed for scripting/demo/screenshot harnesses (the game itself drives it
## through signals). Returns null before [method setup].
func phase() -> GamePhase:
	return _phase


## The in-game HUD (CanvasLayer), exposed so a demo/screenshot harness can emit its intents.
func hud() -> PlayHud:
	return _ui


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
	_highlights = Node3D.new()
	add_child(_highlights)
	_active_marker = Node3D.new()
	add_child(_active_marker)

	for player in players:
		_spawn_pawn(player)
	_build_delivery_markers(deliveries)
	# The delivery list is a crisp 2D HUD panel (left column), child of the PlayHud CanvasLayer.
	_delivery_panel = DeliveryPanel.new()
	_ui.add_child(_delivery_panel)
	_delivery_panel.build(deliveries, _players)

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
	_update_active_marker()
	var first := _phase.current_player()
	_ui.show_banner("Au tour de %s" % PlayerColor.name_of(first.color), PlayerColor.to_color(first.color))


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
	# The board sits between the left delivery panel (~342 px) and the right character card (~317 px):
	# ~78% of the height, ~62% of the width. Take the larger so it always fits both ways.
	var size_for_h := board_h / 0.78
	var size_for_w := board_w / (0.62 * aspect)
	var target := maxf(size_for_h, size_for_w)
	var rig := _camera as CameraRig
	if rig != null:
		target = clampf(target, rig.min_size, rig.max_size)
	_camera.size = target
	var half_h := target * 0.5
	var half_w := half_h * aspect
	# Center the board just right of screen centre (the left panel is a touch wider than the right card).
	var board_cx := (min_x + max_x) * 0.5
	var board_cz := (min_z + max_z) * 0.5
	_camera.position = Vector3(board_cx - 0.02 * half_w, _camera.position.y, board_cz + 0.0 * half_h)


# Pins the 3D dice and the event-card choice to fixed screen regions, scaled to the zoom, so they keep a
# consistent size whatever the pan/zoom. (The delivery list is now a crisp 2D HUD panel — see PlayHud.)
func _process(_delta: float) -> void:
	if _camera == null:
		return
	var zoom := _camera.size / _REF_SIZE
	var half_h := _camera.size * 0.5
	var half_w := half_h * get_viewport().get_visible_rect().size.aspect()
	var center := Vector3(_camera.global_position.x, 0.0, _camera.global_position.z)
	# Dice sit low, just right of the left delivery panel (clear of both the panel and the centre action).
	if _dice_views != null and _dice_views.get_child_count() > 0:
		_dice_views.position = center + Vector3(-half_w * 0.30, 1.0, half_h * 0.40)
		_dice_views.scale = Vector3.ONE * 3.2 * zoom
	# (The event card choice is a 2D HUD modal now — no world pinning needed.)


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
	AudioManager.sfx(&"dice")
	_phase.begin_movement(_dice.total())
	_phase.movement().step_budget_changed.connect(_on_budget_changed)
	_can_roll = false
	_show_dice(_dice.values())
	_refresh_highlights()
	_update_active_marker()
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
	mesh.top_radius = GameConfig.HEX_SIZE * 0.66
	mesh.bottom_radius = GameConfig.HEX_SIZE * 0.66
	mesh.height = 0.08
	mesh.radial_segments = 6
	inst.mesh = mesh
	inst.rotation_degrees = Vector3(0, 30, 0)  # flat-top alignment
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 1.0, 0.55, 0.78)  # bright green, clearly readable
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.06
	inst.position = pos
	return inst


# Marks the active pawn: a ring in the player's color under it, plus a floating "steps remaining"
# badge above it (Mario-Party style) during movement. Rebuilt on turn/roll/step/move.
func _update_active_marker() -> void:
	if _active_marker == null:
		return
	for child in _active_marker.get_children():
		child.queue_free()
	var player := _phase.current_player()
	_active_marker.position = HexUtils.axial_to_world(_phase.position_of(player), GameConfig.HEX_SIZE)
	var color := PlayerColor.to_color(player.color)
	_active_marker.add_child(_active_ring(color))
	var movement := _phase.movement()
	if movement != null and _phase.current_subphase() == GamePhase.SubPhase.DEPLACEMENT:
		_active_marker.add_child(_steps_badge(movement.remaining(), color))


# A flat ring around the active pawn's cell, in the player's color.
func _active_ring(color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = GameConfig.HEX_SIZE * 0.82
	torus.outer_radius = GameConfig.HEX_SIZE * 1.02
	torus.rings = 6
	inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	inst.position = Vector3(0.0, GameConfig.TILE_HEIGHT + 0.07, 0.0)
	return inst


# A floating bubble (colored chip + big number) just north of the pawn, showing steps remaining.
func _steps_badge(remaining: int, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.7, -GameConfig.HEX_SIZE * 1.15)  # raised + north (above on screen)
	var chip := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.1
	cyl.radial_segments = 32
	chip.mesh = cyl
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = color
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chip.material_override = cmat
	root.add_child(chip)
	var label := Label3D.new()
	label.text = str(remaining)
	label.font_size = 120
	label.pixel_size = 0.0075
	label.modulate = Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE
	label.outline_size = 12
	label.outline_modulate = Color(1, 1, 1, 0.5) if color.get_luminance() <= 0.5 else Color(0, 0, 0, 0.5)
	label.position = Vector3(0.0, 0.06, 0.0)
	label.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(label)
	return root


func _on_budget_changed(_remaining: int) -> void:
	_update_active_marker()


func _on_reserve() -> void:
	if _phase.reserve_delivery():
		AudioManager.sfx(&"reserve")
		_ui.set_status("Livraison réservée.")
	else:
		_ui.set_status("Aucune livraison à réserver sur cette tuile.")
	_refresh_highlights()
	_refresh_ui()


# A delivery's status changed (reserved / en cours): refresh its status disc and the action bar.
func _on_delivery_changed(delivery: Delivery) -> void:
	if delivery.status == DeliveryStatus.Kind.EN_COURS:
		AudioManager.sfx(&"pickup")
	_update_status_ring(delivery)
	if _delivery_panel != null:
		_delivery_panel.refresh()
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


func _on_event_triggered(_cell: Vector2i) -> void:
	# Draw the event card(s): normally one (forced), but two when the player armed Carnet d'Adresses
	# (Charlie) — then they keep one and the other returns to the deck. Movement is paused (EVENEMENT)
	# until the choice resolves.
	var player := _phase.current_player()
	var count := 1
	if player.pending_draw_two:
		count = 2
		player.pending_draw_two = false
	var drawn := _events.draw(count)
	if drawn.is_empty():
		_phase.end_turn()  # deck somehow empty: don't strand the player in EVENEMENT
		return
	AudioManager.sfx(&"event")
	_ui.show_banner("Événement !", UITheme.ORANGE)
	_refresh_highlights()  # clears the markers while the cards are up
	_event_modal = EventModal.new()
	_ui.add_child(_event_modal)  # 2D modal on the HUD CanvasLayer
	_event_modal.resolved.connect(_on_event_resolved)
	_event_modal.present(drawn)
	if count == 2:
		_ui.set_status("Carnet d'Adresses : pioche 2, garde la carte qui t'arrange.")
	else:
		_ui.set_status("Événement ! Clique la carte pour l'activer.")


func _on_event_resolved(chosen: EventCardDefinition, discarded: Array) -> void:
	var ctx := _phase.context()
	_phase.apply_event(chosen)
	_events.discard(chosen)
	for card in discarded:
		_events.return_to_top(card)
	_event_modal = null
	if ctx != null and ctx.shield_consumed:
		ctx.shield_consumed = false
		_ui.set_status("Bouclier Vert : malus « %s » annulé !" % chosen.display_name)
	else:
		var tag := "Malus" if chosen.is_malus else "Avantage"
		_ui.set_status("%s : %s" % [tag, chosen.display_name])
	_consume_event_aftermath()
	_refresh_highlights()
	_update_active_marker()
	_refresh_ui()


# Effects the resolver flags but cannot apply itself (they need the dice / the view): Prime
# Gouvernementale rolls bonus dice into the current budget; Tous les Feux au Vert is announced here and
# enacted by GamePhase.end_turn (the same player replays).
func _consume_event_aftermath() -> void:
	var ctx := _phase.context()
	if ctx == null:
		return
	if ctx.extra_dice > 0 and _phase.movement() != null:
		var extra := _dice.roll(ctx.extra_dice)
		var bonus := 0
		for v in extra:
			bonus += v
		_phase.movement().add_steps(bonus)
		ctx.extra_dice = 0
		_show_dice(extra)
		_ui.set_status("Prime gouvernementale : +%d dé(s) → +%d cases !" % [extra.size(), bonus])
	if ctx.replay:
		_ui.set_status("Tous les feux au vert — tu rejoues un tour !")


func _on_power() -> void:
	var player := _phase.current_player()
	if player.character == null or player.power_used or _phase.context() == null:
		_ui.set_status("Aucun pouvoir disponible pour l'instant.")
		return
	var pid := player.character.power_id
	if PowerResolver.is_interactive(pid):
		_begin_interactive_power(pid)
		return
	if _phase.use_power():
		AudioManager.sfx(&"power")
		_ui.set_status(_power_message(pid))
		_refresh_highlights()
		_update_active_marker()
	else:
		_ui.set_status("Ce pouvoir n'est pas disponible maintenant.")
	_refresh_ui()


# Interactive powers ask the player to pick a target first, then call the matching GamePhase method.
func _begin_interactive_power(pid: StringName) -> void:
	if pid == &"depassement":
		var options: Array = []
		var indices: Array = []
		for p in _players:
			if p.index == _phase.current_player().index:
				continue
			options.append({"text": PlayerColor.name_of(p.color), "color": PlayerColor.to_color(p.color)})
			indices.append(p.index)
		if options.is_empty():
			_ui.set_status("Dépassement : aucun autre joueur à dépasser.")
			return
		_ui.show_chooser("Dépassement — échange ta place avec :", options, func(choice: int) -> void:
			if choice < 0:
				return
			if _phase.swap_positions(indices[choice]):
				AudioManager.sfx(&"power")
				_ui.set_status("Dépassement ! Place échangée.")
				_refresh_highlights()
				_update_active_marker()
				_refresh_ui())
	elif pid == &"coup_accelerateur":
		var values := _dice.values()
		if values.is_empty():
			_ui.set_status("Coup d'Accélérateur : lance d'abord les dés.")
			return
		var options: Array = []
		for v in values:
			options.append({"text": "Dé : %d" % v, "color": UITheme.ORANGE})
		_ui.show_chooser("Coup d'Accélérateur — relance quel dé ?", options, func(choice: int) -> void:
			if choice < 0:
				return
			var old_value: int = values[choice]
			var new_value := _dice.reroll(choice)
			if _phase.apply_reroll(new_value - old_value):
				AudioManager.sfx(&"power")
				_show_dice(_dice.values())
				_ui.set_status("Coup d'Accélérateur : %d → %d (%+d cases)." % [old_value, new_value, new_value - old_value])
				_refresh_highlights()
				_update_active_marker()
				_refresh_ui())


# Toast describing the effect of a non-interactive power that was just used.
func _power_message(pid: StringName) -> String:
	match pid:
		&"bonne_marcheuse":
			return "Bonne Marcheuse : +2 cases !"
		&"carnet_adresses":
			return "Carnet d'Adresses : ton prochain événement, pioche 2 et garde 1."
		&"bouclier_vert":
			return "Bouclier Vert : le prochain malus sera annulé."
		&"habitue_quartier":
			return "Habitué·e : ta prochaine livraison comptera au maximum."
		&"passage_secret":
			return "Passage Secret : tu peux franchir l'eau ce tour-ci !"
		&"chargement_pro":
			return "Chargement Pro : +1 livraison transportable."
		_:
			return "Super-pouvoir activé !"


func _on_pawn_moved(player: Player, _from: Vector2i, to: Vector2i) -> void:
	var pawn: Pawn = _pawns[player.index]
	pawn.move_to(to)
	_refresh_highlights()
	_update_active_marker()
	_refresh_ui()


func _on_turn_changed(player: Player) -> void:
	_can_roll = true
	_clear_dice()
	_refresh_highlights()
	_update_active_marker()
	_refresh_ui()
	_ui.show_banner("Au tour de %s" % PlayerColor.name_of(player.color), PlayerColor.to_color(player.color))
	_ui.set_status("À toi de jouer — lance les dés.")


func _on_delivery_completed(delivery: Delivery, points: int) -> void:
	# The destinataire was recycled (or cleared) — refresh that delivery's recipient card + status.
	AudioManager.sfx(&"deliver")
	_celebrate_delivery(delivery.recipient_cell)
	_rebuild_recipient_marker(delivery)
	_update_status_ring(delivery)  # back to DISPONIBLE -> ring removed
	if _delivery_panel != null:
		_delivery_panel.refresh()
	_ui.set_status("Livré ! +%d points." % points)
	_refresh_ui()


# A short confetti-like burst at [param cell] to celebrate a completed delivery (GL-safe CPU particles).
func _celebrate_delivery(cell: Vector2i) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 28
	particles.lifetime = 0.9
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 4.5
	particles.gravity = Vector3(0, -6.0, 0)
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.2
	particles.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	particles.mesh.material = mat
	particles.color_ramp = _confetti_ramp()
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.3
	particles.position = pos
	add_child(particles)
	particles.emitting = true
	# Auto-clean once the burst is over.
	get_tree().create_timer(1.4).timeout.connect(particles.queue_free)


func _confetti_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color("ffd23f"))
	g.set_color(1, Color("ff6b6b"))
	g.add_point(0.5, Color("4ecdc4"))
	return g


func _on_game_finished(scores: Dictionary) -> void:
	AudioManager.sfx(&"victory")
	_ui.show_end(scores, _players)


func _refresh_ui() -> void:
	var player := _phase.current_player()
	_ui.refresh(player, _phase.score_of(player))
	_ui.set_round(_phase.round_number())
	_ui.set_deliveries_remaining(_phase.deliveries_remaining())
	if _delivery_panel != null:
		_delivery_panel.set_remaining(_phase.deliveries_remaining())
		_delivery_panel.set_current_player(player.index)
	# The power needs the turn context (it acts during movement), so only offer it then — never a dead
	# press during planning, and never silently wasted on an unimplemented effect.
	var power_ready := player.character != null and not player.power_used and _phase.context() != null
	_ui.set_power_available(power_ready)
	_ui.set_action(_current_action())


# The contextual primary action: ROLL while planning, RESERVE when standing on a reservable tile,
# else END_TURN (movement spent / nothing to reserve).
func _current_action() -> int:
	if _phase.current_subphase() == GamePhase.SubPhase.PLANIFICATION and _can_roll:
		return PlayHud.Action.ROLL
	if _phase.current_subphase() == GamePhase.SubPhase.DEPLACEMENT and _phase.reservable_delivery() != null:
		return PlayHud.Action.RESERVE
	return PlayHud.Action.END_TURN


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
