class_name GameRoot
extends Node3D
## Composition root for the play phase, taking over once setup is finished. Wires the pure [GamePhase]
## to the world: a [DiceRoller], one [Pawn] + [PawnView] per player, drive/recipient markers, a
## [MovementController] for input and a [GameUI]. Mirrors what [Main] does for the setup phase.

const EVENTS_DIR := "res://resources/events/"
const _REF_SIZE := 30.0  # the camera's default ortho size; overlays scale relative to it

var _board: Board
var _players: Array[Player]
var _camera: Camera3D
var _phase: GamePhase
var _dice: DiceRoller
var _events: Deck
var _ui: GameUI
var _pawns: Dictionary = {}            # player index -> Pawn
var _can_roll: bool = true
var _dice_views: Node3D                 # holder for the rolled 3D dice
var _highlights: Node3D                 # holder for the reachable-cell markers
var _event_choice: EventCardChoice      # active card choice, if any


func setup(board: Board, players: Array[Player], camera: Camera3D) -> void:
	_board = board
	_players = players
	_camera = camera
	var deliveries := DeliverySetup.build(board)
	_phase = GamePhase.new(players, board, deliveries)
	_dice = DiceRoller.new()
	_events = Deck.new(_load_events())
	_events.shuffle()

	_ui = GameUI.new()
	add_child(_ui)
	_ui.setup_players(players)
	_dice_views = Node3D.new()
	add_child(_dice_views)
	_highlights = Node3D.new()
	add_child(_highlights)

	for player in players:
		_spawn_pawn(player)
	_build_delivery_markers(deliveries)

	var move_controller := MovementController.new()
	add_child(move_controller)
	move_controller.setup(camera, _phase)

	_phase.pawn_moved.connect(_on_pawn_moved)
	_phase.turn_changed.connect(_on_turn_changed)
	_phase.delivery_completed.connect(_on_delivery_completed)
	_phase.game_finished.connect(_on_game_finished)
	_phase.event_triggered.connect(_on_event_triggered)
	_ui.roll_requested.connect(_on_roll)
	_ui.end_turn_requested.connect(_phase.end_turn)
	_ui.pickup_requested.connect(_on_pickup)
	_ui.deliver_requested.connect(_on_deliver)
	_ui.power_requested.connect(_on_power)
	_refresh_ui()
	_ui.set_status("À toi de jouer — lance les dés.")


# Pins the dice (bottom-left) and the event-card choice (centered) to fixed screen regions, scaled to
# the zoom, so they keep a consistent size and use the available space whatever the pan/zoom.
func _process(_delta: float) -> void:
	if _camera == null:
		return
	var zoom := _camera.size / _REF_SIZE
	var half_h := _camera.size * 0.5
	var half_w := half_h * get_viewport().get_visible_rect().size.aspect()
	var center := Vector3(_camera.global_position.x, 0.0, _camera.global_position.z)
	if _dice_views != null and _dice_views.get_child_count() > 0:
		_dice_views.position = center + Vector3(-half_w * 0.58, 1.0, half_h * 0.58)
		_dice_views.scale = Vector3.ONE * 3.1 * zoom
	if _event_choice != null and is_instance_valid(_event_choice):
		_event_choice.position = center + Vector3(0.0, 1.0, -half_h * 0.05)
		_event_choice.scale = Vector3.ONE * 4.0 * zoom


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
		add_child(_marker(delivery.drive_cell, Color("8a8f99"), 0.42))   # drive: grey, square-ish
		add_child(_marker(delivery.recipient_cell, Color("6aa84f"), 0.3))  # recipient: green dot


func _marker(cell: Vector2i, color: Color, radius: float) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.12
	mesh.radial_segments = 6
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = 0.2
	inst.position = pos
	return inst


func _on_roll() -> void:
	if not _can_roll or _phase.current_subphase() != GamePhase.SubPhase.PLANIFICATION:
		return
	var player := _phase.current_player()
	var dice_count := player.character.dice_count() if player.character != null else 2
	_dice.roll(dice_count)
	_phase.begin_movement(_dice.total())
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
	if remaining > 0:
		_ui.set_status("Déplacement restant : %d" % remaining)
	else:
		_ui.set_status("Déplacement terminé — prends/livre ou Fin de tour.")


func _on_pickup() -> void:
	if _phase.confirm_pickup():
		_ui.set_status("Pris en charge au drive (-1 déplacement).")
	else:
		_ui.set_status("Approche-toi du drive (case grise) pour prendre la livraison.")
	_refresh_highlights()
	_refresh_ui()


func _on_deliver() -> void:
	if not _phase.confirm_delivery():
		_ui.set_status("Approche-toi du destinataire (case verte), livraison en main.")
	_refresh_ui()


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
	var anchor := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE) + Vector3(0.0, 1.0, 0.0)
	_event_choice.present(drawn, _camera, anchor)
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


func _on_turn_changed(_player: Player) -> void:
	_can_roll = true
	_clear_dice()
	_refresh_highlights()
	_refresh_ui()
	_ui.set_status("À toi de jouer — lance les dés.")


func _on_delivery_completed(_delivery: Delivery, points: int) -> void:
	_ui.set_status("Livré ! +%d points." % points)
	_refresh_ui()


func _on_game_finished(scores: Dictionary) -> void:
	_ui.show_end(scores, _players)


func _refresh_ui() -> void:
	var player := _phase.current_player()
	_ui.refresh(player, _phase.score_of(player), _can_roll, _phase.current_delivery())


func _load_events() -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	var dir := DirAccess.open(EVENTS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(EVENTS_DIR + file))
	return result
