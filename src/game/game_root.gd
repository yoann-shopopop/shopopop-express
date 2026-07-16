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
var _deliveries: Array[Delivery] = []  # the built deliveries (drive/recipient cells), exposed to the view
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
var _hover_markers: Node3D              # holder for the delivery-panel hover markers/link
var _hovered_delivery: Delivery = null  # currently hovered card, so a stray unhover can't clear a newer hover
var _path_preview: Node3D               # holder for the hovered-cell trajectory preview + cost label
var _walking: bool = false              # an animated multi-cell auto-walk is in progress (ignore new clicks)
var _reservation_prompted: Dictionary = {}  # Delivery -> true, reset each turn: ask at most once per visit
var _ai_playing: bool = false           # an AI-controlled seat's turn is auto-playing (see AutoPilot)

## Fired once the auto-reservation prompt (chooser) is dismissed, however it was resolved — lets an
## in-progress auto-walk pause on arrival and resume afterwards instead of racing past the offer.
signal reservation_prompt_resolved
var _active_marker: Node3D              # ring under the active pawn + floating steps badge above it
var _event_choice: EventCardChoice      # active animated card draw (CardView), if any
var _event_discards_rejected: bool = false  # Carnet d'Adresses: discard the rejected card instead of top-decking
var _delivery_panel: DeliveryPanel
var _player_panel: PlayerPanel
var _last_run_announced: bool = false  # the « Dernière tournée ! » banner fires once per game
var _skipped_notice: String = ""       # pending turn_skipped notice(s), folded into the next turn status
var _tournee_session: TourneeSession = null  # non-null only for the solo "La Tournée" mode


## The pure turn logic, exposed for scripting/demo/screenshot harnesses (the game itself drives it
## through signals). Returns null before [method setup].
func phase() -> GamePhase:
	return _phase


## The in-game HUD (CanvasLayer), exposed so a demo/screenshot harness can emit its intents.
func hud() -> PlayHud:
	return _ui


## The built deliveries, exposed for scripting/demo/screenshot harnesses. Valid after [method setup].
func deliveries() -> Array[Delivery]:
	return _deliveries


## The cells hosting a delivery's drive (for [HexGridView] to draw the storefront art on the real,
## possibly cross-tile, drives). Valid after [method setup].
func drive_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for delivery in _deliveries:
		cells.append(delivery.drive_cell)
	return cells


## Wires the solo "La Tournée" mode on top of an already-[method setup] session: [param session] must
## already be [method TourneeSession.start]ed on this GameRoot's [method phase]. Suppresses the normal
## multiplayer end screen (see [method _on_game_finished]) in favour of [method PlayHud.show_tournee_end],
## shows the clock in place of "Manche N", and flashes the chaining bonus banner.
func set_tournee_session(session: TourneeSession) -> void:
	_tournee_session = session
	session.session_finished.connect(_on_tournee_finished)
	session.chain_bonus_awarded.connect(_on_chain_bonus_awarded)
	session.round_advanced.connect(_on_tournee_round_advanced)
	_ui.set_tournee_clock(session.clock_text())


func _on_tournee_finished(result: Dictionary) -> void:
	AudioManager.sfx(&"victory")
	_ui.show_tournee_end(result)


func _on_chain_bonus_awarded(_total: int) -> void:
	_ui.show_banner(tr("Chaînage ! +%d") % TourneeSession.CHAIN_BONUS, UITheme.GREEN)


func _on_tournee_round_advanced(_round_number: int, _rounds_left: int) -> void:
	if _tournee_session != null:
		_ui.set_tournee_clock(_tournee_session.clock_text())


func _randomized_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


# Absolute board cells of the players' starts (same formula as GamePhase), excluded from the recipient
# pool so a recipient never spawns under a pawn.
func _start_cells() -> Dictionary:
	var cells := {}
	for player in _players:
		if player.start_block == null:
			continue
		for piece in _board.pieces():
			if piece.block_def == player.start_block:
				cells[HexUtils.rotate(player.start_cell, piece.rotation) + piece.anchor] = true
				break
	return cells


## Wires the play phase for [param board] with [param players], viewed through [param camera].
## Everything after [param camera] is an OPTIONAL override for scripting a deterministic session
## (the tutorial, and tests) — with none given, delivery placement/pairing/dice/events are exactly
## as random as before:
## - [param rng]: replaces the internally-randomize()'d RNG used to build/pair deliveries.
## - [param forced_deliveries]: if non-empty, used AS-IS (enseigne/destinataire already assigned)
##   instead of DeliverySetup.build(...) + a DeliveryGenerator — the most robust way to guarantee a
##   specific arrangement (e.g. "one mono-tile delivery worth 25"). No recycling generator is built
##   for this session (nothing to recycle in a short, scripted one); is_finished() still works fine.
## - [param forced_dice]: replaces the internally-constructed DiceRoller — inject one built on a
##   seeded RNG, or call [method DiceRoller.force] on it externally to pin exact values.
## - [param forced_event_order]: if non-empty, replaces the shuffled events Deck's contents with
##   that exact draw order (a normal reshuffle still applies once it's exhausted).
## - [param uncapped_deliveries]: skips the « total tuiles = livraisons » cap on the identity pool —
##   only for La Tournée, whose 16-round session lives on continuous recycling rather than the
##   normal "one delivery per tile" multiplayer rule (see [method Main._start_tournee]).
func setup(
	board: Board,
	players: Array[Player],
	camera: Camera3D,
	rng: RandomNumberGenerator = null,
	forced_deliveries: Array[Delivery] = [],
	forced_dice: DiceRoller = null,
	forced_event_order: Array[CardDefinition] = [],
	uncapped_deliveries: bool = false,
) -> void:
	_board = board
	_players = players
	_camera = camera
	if not forced_deliveries.is_empty():
		_deliveries = forced_deliveries
		_phase = GamePhase.new(players, board, _deliveries)
	else:
		# Random placement: drives (urban) and recipients (green) are drawn board-wide and paired at
		# random (mono- or bi-tile), all reachable. Up to one per available destinataire; player
		# starts are excluded from the recipient pool so a recipient never lands under a pawn's spawn.
		var destinataires := _load_destinataires()
		var build_rng := rng if rng != null else _randomized_rng()
		_deliveries = DeliverySetup.build(board, build_rng, destinataires.size(), _start_cells())
		# Rules (« Mise en place ») : the total deliveries of a game equals the number of placed
		# tiles — the identity pool is capped accordingly, so a 2-player game is 6 deliveries, not
		# the full pool. La Tournée opts out (-1, uncapped): it recycles for 16 rounds, not one pass.
		var cap := -1 if uncapped_deliveries else _deliveries.size()
		var generator := DeliveryGenerator.new(_load_enseignes(), destinataires, _deliveries.size(), build_rng, cap)
		var combos := generator.combos()
		for i in _deliveries.size():
			if i < combos.size():
				_deliveries[i].enseigne = combos[i].enseigne
				_deliveries[i].destinataire = combos[i].destinataire
		_phase = GamePhase.new(players, board, _deliveries, generator)
	_dice = forced_dice if forced_dice != null else DiceRoller.new()
	_events = Deck.new(forced_event_order if not forced_event_order.is_empty() else _load_events())
	if forced_event_order.is_empty():
		_events.shuffle()

	_ui = PlayHud.new()
	add_child(_ui)
	_player_panel = PlayerPanel.new()
	_ui.add_child(_player_panel)
	_player_panel.build(players)
	_dice_views = Node3D.new()
	add_child(_dice_views)
	_highlights = Node3D.new()
	add_child(_highlights)
	_hover_markers = Node3D.new()
	add_child(_hover_markers)
	_path_preview = Node3D.new()
	add_child(_path_preview)
	_active_marker = Node3D.new()
	add_child(_active_marker)

	for player in players:
		_spawn_pawn(player)
	_build_delivery_markers(_deliveries)
	# The delivery list is a crisp 2D HUD panel (left column), child of the PlayHud CanvasLayer.
	_delivery_panel = DeliveryPanel.new()
	_ui.add_child(_delivery_panel)
	_delivery_panel.build(_deliveries, _players)
	_delivery_panel.delivery_hovered.connect(_on_delivery_hovered)
	_delivery_panel.delivery_unhovered.connect(_on_delivery_unhovered)

	var move_controller := MovementController.new()
	add_child(move_controller)
	move_controller.setup(camera)
	move_controller.cell_hovered.connect(_on_cell_hovered)
	move_controller.hover_cleared.connect(_on_hover_cleared)
	move_controller.cell_clicked.connect(_on_cell_clicked)

	_phase.pawn_moved.connect(_on_pawn_moved)
	_phase.turn_changed.connect(_on_turn_changed)
	_phase.turn_skipped.connect(_on_turn_skipped)
	_phase.delivery_completed.connect(_on_delivery_completed)
	_phase.delivery_reserved.connect(_on_delivery_changed)
	_phase.delivery_in_progress.connect(_on_delivery_changed)
	_phase.game_finished.connect(_on_game_finished)
	_phase.event_triggered.connect(_on_event_triggered)
	_ui.roll_requested.connect(_on_roll)
	_ui.end_turn_requested.connect(_phase.end_turn)
	_ui.reserve_requested.connect(_on_reserve)
	_ui.power_requested.connect(_on_power)
	_ui.boost_requested.connect(_on_boost_requested)
	var camera_rig := camera as CameraRig
	if camera_rig != null:
		_ui.zoom_in_requested.connect(camera_rig.zoom_in)
		_ui.zoom_out_requested.connect(camera_rig.zoom_out)
	_fit_camera_to_board()
	_refresh_ui()
	_update_active_marker()
	var first := _phase.current_player()
	_ui.show_banner(tr("Au tour de %s") % PlayerColor.name_of(first.color), PlayerColor.to_color(first.color))
	if first.is_ai:
		_play_ai_turn(first)  # turn_changed only fires from end_turn: the very first seat needs its own kick


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
	if _event_choice != null and is_instance_valid(_event_choice):
		# Drawn event cards: large, centered, and raised well ABOVE the pawns/dice/markers (top-down ortho
		# sorts by height) so nothing renders in front of them during a rainbow event.
		var card_y := 5.0
		_event_choice.position = center + Vector3(0.0, card_y, half_h * 0.02)
		_event_choice.scale = Vector3.ONE * 8.0 * zoom
		# Map the HUD PIOCHE / DÉFAUSSE piles to world points at the cards' height, so resolved cards fly
		# to the real piles.
		var depth := _camera.global_position.y - card_y
		_event_choice.pioche_target = _camera.project_position(_ui.pioche_screen_center(), depth)
		_event_choice.defausse_target = _camera.project_position(_ui.defausse_screen_center(), depth)


func _spawn_pawn(player: Player) -> void:
	var def := PawnDefinition.new()
	def.type = PawnDefinition.PawnType.COTRANSPORTER
	def.color = PlayerColor.to_color(player.color)
	def.shape_kind = player.color  # doubles the color with a distinct top-down silhouette
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


# (Re)builds the recipient token for [param delivery], reflecting its current destinataire. With the
# identity pool capped at the tile count, a completed delivery recycles to null: no ghost token then.
func _rebuild_recipient_marker(delivery: Delivery) -> void:
	var existing = _recipient_markers.get(delivery, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
		_recipient_markers.erase(delivery)
	if delivery.destinataire == null:
		return  # nothing left to deliver here: leave the green cell bare
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
	_ui.set_status(tr("Dés : %s — déplacement : %d (clique une case verte)") % [str(_dice.values()), _dice.total()])
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


const _LEGAL_MOVE_COLOR := Color(0.45, 1.0, 0.55, 0.78)  # bright green, clearly readable
const _HOVER_LINK_COLOR := Color(1.0, 1.0, 1.0, 0.85)    # neutral white: distinct from any player color


func _highlight_marker(cell: Vector2i, color: Color = _LEGAL_MOVE_COLOR) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = GameConfig.HEX_SIZE * 0.66
	mesh.bottom_radius = GameConfig.HEX_SIZE * 0.66
	mesh.height = 0.08
	mesh.radial_segments = 6
	inst.mesh = mesh
	inst.rotation_degrees = Vector3(0, 30, 0)  # flat-top alignment
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.06
	inst.position = pos
	return inst


# Highlights a hovered DeliveryPanel card's drive + recipient cells on the board (white rings distinct
# from the green legal-move highlight and from any player color), plus a straight link bar between them
# when the delivery spans two tiles — cross-tile pairing means the panel alone can't show WHERE they are.
# The reverse direction (hovering a 3D token highlights its card) is deferred: it would need a whole new
# 3D mouse-picking subsystem (none exists here) at real risk of intercepting MovementController's board
# clicks — not worth it for a secondary, lower-value direction.
func _on_delivery_hovered(delivery: Delivery) -> void:
	_hovered_delivery = delivery
	_clear_hover_markers()
	_hover_markers.add_child(_highlight_marker(delivery.drive_cell, _HOVER_LINK_COLOR))
	if delivery.recipient_cell != delivery.drive_cell:
		_hover_markers.add_child(_highlight_marker(delivery.recipient_cell, _HOVER_LINK_COLOR))
		_hover_markers.add_child(_hover_link_mesh(delivery.drive_cell, delivery.recipient_cell))


func _on_delivery_unhovered(delivery: Delivery) -> void:
	if delivery != _hovered_delivery:
		return  # a newer hover already replaced these markers — don't clear them out from under it
	_hovered_delivery = null
	_clear_hover_markers()


# Frees the hover markers immediately (not queue_free): mouse hover can retrigger rapidly as the
# player's cursor crosses several cards, and a deferred free would either flicker (old + new markers
# coexisting for a frame) or, in tests, still report stale children the instant after clearing.
func _clear_hover_markers() -> void:
	for child in _hover_markers.get_children():
		child.free()


# A thin bright bar on the ground connecting [param from] and [param to] — the "tracé du lien" between
# a hovered delivery's drive and recipient cells.
func _hover_link_mesh(from: Vector2i, to: Vector2i) -> MeshInstance3D:
	var a := HexUtils.axial_to_world(from, GameConfig.HEX_SIZE)
	var b := HexUtils.axial_to_world(to, GameConfig.HEX_SIZE)
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.06, 0.12)
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _HOVER_LINK_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	inst.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	inst.position = Vector3(mid.x, GameConfig.TILE_HEIGHT + 0.05, mid.z)
	return inst


# --- Trajectory preview + click-to-walk --------------------------------------

const _PATH_AFFORDABLE_COLOR := Color(0.35, 0.75, 1.0, 0.8)  # blue: distinct from the green legal-move dots
const _PATH_TOO_FAR_COLOR := Color(0.9, 0.35, 0.3, 0.55)     # dim red: reachable, but not this turn
const _WALK_STEP_DELAY := 0.2  # a touch longer than PawnView's 0.16s hop so each step reads clearly

## Previews the route to a hovered cell (BFS via [method TurnMovement.path_to]): the path cells light
## up blue if affordable this turn, dim red if the cell is farther than the remaining budget, and a
## floating label shows the cost in steps. No-op outside DEPLACEMENT (e.g. during PLANIFICATION).
func _on_cell_hovered(cell: Vector2i) -> void:
	_clear_path_preview()
	if _walking or _ai_playing:
		return  # keep the screen calm while an auto-walk (human or AI) is animating
	var movement := _phase.movement()
	if movement == null or _phase.current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
		return
	var path := movement.path_to(cell)
	if path.is_empty():
		return
	var affordable := path.size() <= movement.remaining()
	var color := _PATH_AFFORDABLE_COLOR if affordable else _PATH_TOO_FAR_COLOR
	for step_cell in path:
		_path_preview.add_child(_highlight_marker(step_cell, color))
	_path_preview.add_child(_path_cost_label(cell, path.size(), affordable))


func _on_hover_cleared() -> void:
	_clear_path_preview()


func _clear_path_preview() -> void:
	for child in _path_preview.get_children():
		child.free()


# A small floating "N cases" label above the hovered [param cell], tinted like the path markers.
func _path_cost_label(cell: Vector2i, cost: int, affordable: bool) -> Label3D:
	var label := Label3D.new()
	label.text = tr("%d case%s") % [cost, "s" if cost > 1 else ""]
	label.font_size = 34
	label.pixel_size = 0.0075
	label.modulate = _PATH_AFFORDABLE_COLOR if affordable else _PATH_TOO_FAR_COLOR
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.65)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.6
	label.position = pos
	return label


## Click/tap on [param cell]: walks the BFS route to it one [method GamePhase.try_step] at a time,
## animated (PawnView's own 0.16s hop already does the readability work — this just paces the calls
## so each hop's tween completes before the next starts). Generalizes the old single-adjacent-cell
## click: [method TurnMovement.path_to] returns a 1-cell path for an adjacent legal move. Stops early
## if a step is rejected (budget ran out mid-walk) or the phase leaves DEPLACEMENT (an event cell was
## triggered — try_step already pauses movement for it; the walk must not race past the event modal).
func _on_cell_clicked(cell: Vector2i) -> void:
	if _walking or _ai_playing:
		return
	var movement := _phase.movement()
	if movement == null or _phase.current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
		return
	var path := movement.path_to(cell)
	if path.is_empty():
		return
	_clear_path_preview()
	_walk_path(path)


func _walk_path(path: Array[Vector2i]) -> void:
	_walking = true
	_ui.set_actions_enabled(false)  # "Fin de tour" must not race the walk's own try_step calls
	for step_cell in path:
		if not _phase.try_step(step_cell):
			break
		if _phase.current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
			break  # an event cell paused movement: let it resolve before any further step
		if _maybe_prompt_reservation():
			await reservation_prompt_resolved
			if _phase.current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
				break  # reserving can auto-transition a delivery; re-check before continuing
		if step_cell != path[path.size() - 1]:
			await get_tree().create_timer(_WALK_STEP_DELAY).timeout
	_walking = false
	_ui.set_actions_enabled(true)


## Offers to reserve the delivery on the pawn's current tile the moment it becomes reservable —
## "réserver n'importe quand en te déplaçant" from the physical rules, rather than relying on the
## player to notice the small manual button. Asked at most once per (turn, delivery): declining just
## means "not now" — the manual "Réserver" button (still shown whenever [method
## GamePhase.reservable_delivery] is non-null) covers changing one's mind. Returns true if a prompt
## was shown (the caller must await [signal reservation_prompt_resolved] before continuing to move).
func _maybe_prompt_reservation() -> bool:
	var delivery := _phase.reservable_delivery()
	if delivery == null or _reservation_prompted.has(delivery):
		return false
	_reservation_prompted[delivery] = true
	var label := delivery.enseigne.display_name if delivery.enseigne != null else tr("cette livraison")
	_ui.show_chooser(tr("Réserver %s ?") % label, [
		{"text": tr("Réserver"), "color": UITheme.GREEN},
	], func(choice: int) -> void:
		if choice == 0:
			_on_reserve()
		reservation_prompt_resolved.emit())
	return true


# --- Solo vs IA (AutoPilot promoted to an in-game opponent) ------------------

const _AI_STEP_DELAY := 0.12   # faster than the human auto-walk's 0.2s — "joue vite" per the plan
const _AI_TURN_SAFETY_CAP := 400  # mirrors AutoPilot.play_turn's guard against a pathing dead-end

## Auto-plays [param player]'s entire turn (roll → walk greedily toward the most useful delivery,
## reserving/resolving events along the way → end turn) using [AutoPilot]'s pure decision functions
## (choose_target/step_toward), paced with short delays so it's animated and readable rather than
## instant. V1 rules (assumed and documented, not hidden): the AI never uses its super-power, and
## events are resolved with a short-circuited pick instead of the human's interactive card modal
## (see [method _ai_resolve_event]). Called from [signal GamePhase.turn_changed] and once for the
## very first seat (that signal only fires from end_turn, so the opening turn needs its own kick).
## No-ops once [method GamePhase.is_finished] — the round-robin keeps cycling turn_changed after the
## last delivery (a human simply stops clicking under the end-game overlay; an AI seat would
## otherwise keep auto-playing pointless turns forever behind it).
func _play_ai_turn(player: Player) -> void:
	if _ai_playing or _phase.is_finished():
		return
	_ai_playing = true
	_ui.set_actions_enabled(false)
	await get_tree().create_timer(0.3).timeout  # let the "Au tour de X" banner be read before it acts
	if _can_roll and _phase.current_subphase() == GamePhase.SubPhase.PLANIFICATION:
		_on_roll()
		await get_tree().create_timer(0.3).timeout
	var safety := 0
	while _phase.movement() != null and _phase.current_subphase() == GamePhase.SubPhase.DEPLACEMENT \
			and _phase.movement().remaining() > 0:
		safety += 1
		if safety > _AI_TURN_SAFETY_CAP:
			break
		if _phase.reservable_delivery() != null:
			_phase.reserve_delivery()  # silent: no confirmation prompt for the AI
			_refresh_ui()
		var target = AutoPilot.choose_target(_phase, _deliveries)
		var next = AutoPilot.step_toward(_phase, _board, _deliveries, target)
		if next == null or not _phase.try_step(next):
			break
		if _phase.current_subphase() == GamePhase.SubPhase.EVENEMENT:
			await _ai_resolve_event()
			if _phase.current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
				break  # e.g. a FIN_TOUR effect
		else:
			await get_tree().create_timer(_AI_STEP_DELAY).timeout
	# Reset BEFORE end_turn(), not after: end_turn() synchronously emits turn_changed, which (for a
	# REJOUER replay of this same AI, or a next seat that's also AI) re-enters _on_turn_changed →
	# _play_ai_turn *while still inside this call*. If _ai_playing were still true at that point, the
	# guard at the top would swallow that turn entirely — the replay/next-AI would never actually play.
	_ai_playing = false
	_ui.set_actions_enabled(true)
	_phase.end_turn()


## AI equivalent of the human draw-2-keep-1 flow (_on_event_triggered/_on_event_resolved): same Deck/
## discard/Carnet d'Adresses semantics (game state stays consistent either way), but auto-picks and
## shows a short banner instead of the interactive 3D card presentation — "modal court-circuité avec
## révélation courte" per the plan, so the AI's turn stays readable without waiting on a click.
func _ai_resolve_event() -> void:
	var player := _phase.current_player()
	var drawn := _events.draw(2)
	if drawn.is_empty():
		return
	var discards_rejected := player.pending_draw_two
	player.pending_draw_two = false
	_ui.set_deck_counts(_events.draw_count(), _events.discard_count())
	AudioManager.sfx(&"event")
	var chosen := _ai_choose_event(drawn)
	drawn.erase(chosen)
	var ctx := _phase.context()
	_phase.apply_event(chosen)
	_events.discard(chosen)
	for card in drawn:
		if discards_rejected:
			_events.discard(card)
		else:
			_events.return_to_top(card)
	_ui.set_discard_top(chosen)
	if ctx != null and ctx.shield_consumed:
		ctx.shield_consumed = false
	var tag := tr("Malus") if chosen.is_malus else tr("Avantage")
	_ui.show_banner("%s : %s" % [tag, tr(chosen.display_name)], UITheme.RED if chosen.is_malus else UITheme.GREEN)
	_consume_event_aftermath()
	_refresh_highlights()
	_update_active_marker()
	_refresh_ui()
	await get_tree().create_timer(0.5).timeout  # a short, legible reveal before the walk resumes


# Greedy draw-2-keep-1 pick for the AI: prefer an Avantage over a Malus (no deeper lookahead — the
# plan's own "joue vite" simplification, same spirit as it never using its super-power).
func _ai_choose_event(drawn: Array[CardDefinition]) -> EventCardDefinition:
	for card in drawn:
		if card is EventCardDefinition and not (card as EventCardDefinition).is_malus:
			return card
	return drawn[0] as EventCardDefinition


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
	# Keeps the legal-move highlights tracking the pawn as it walks (each step_budget_changed fires
	# on every step/add/subtract) — without this they'd stay frozen at the roll's original position
	# through an animated multi-cell auto-walk, visibly out of sync with where the pawn actually is.
	_refresh_highlights()


func _on_reserve() -> void:
	var target := _phase.reservable_delivery()
	if target == null or not _phase.reserve_delivery():
		_ui.set_status(tr("Aucune livraison à réserver sur cette tuile."))
		_refresh_highlights()
		_refresh_ui()
		return
	AudioManager.sfx(&"reserve")
	# Reserving on someone else's district denies them the color bonus — the competitive framing
	# names that as "taking the run" instead of a plain, identical-sounding reservation.
	var player := _phase.current_player()
	if target.drive_tile_owner() != player.color:
		_ui.set_status(tr("Course prise !"))
	else:
		_ui.set_status(tr("Livraison réservée."))
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
	if _phase.current_player().is_ai:
		return  # the AI's own turn loop resolves events directly (see _play_ai_turn/_ai_resolve_event)
	# Base rule: draw TWO event cards, keep one, the other goes back ON TOP of the deck. Carnet
	# d'Adresses (Charlie) changes only the fate of the rejected card — it is DISCARDED instead of put
	# back on top. Movement is paused (EVENEMENT) until the choice resolves.
	var player := _phase.current_player()
	var drawn := _events.draw(2)
	if drawn.is_empty():
		_phase.end_turn()  # deck somehow empty: don't strand the player in EVENEMENT
		return
	_event_discards_rejected = player.pending_draw_two
	player.pending_draw_two = false
	_ui.set_deck_counts(_events.draw_count(), _events.discard_count())  # pile drops as the cards are drawn
	AudioManager.sfx(&"event")
	_ui.show_banner(tr("Événement !"), UITheme.ORANGE)
	_refresh_highlights()  # clears the markers while the cards are up
	_event_choice = EventCardChoice.new()
	add_child(_event_choice)  # 3D cards dealt over the board, pinned to screen by _process
	_event_choice.reject_to_discard = _event_discards_rejected  # Charlie: rejected card → discard, not top
	_event_choice.resolved.connect(_on_event_resolved)
	_event_choice.present(drawn, _camera, Vector3.ZERO)
	if _event_discards_rejected:
		_ui.set_status(tr("Carnet d'Adresses : garde 1 carte, l'autre est défaussée."))
	else:
		_ui.set_status(tr("Garde 1 carte — l'autre repart au-dessus du deck."))


func _on_event_resolved(chosen: EventCardDefinition, discarded: Array) -> void:
	var ctx := _phase.context()
	_phase.apply_event(chosen)
	_events.discard(chosen)
	# Base: the rejected card returns to the top of the deck. Carnet d'Adresses discards it instead.
	for card in discarded:
		if _event_discards_rejected:
			_events.discard(card)
		else:
			_events.return_to_top(card)
	_event_discards_rejected = false
	_event_choice = null
	_ui.set_discard_top(chosen)  # the played card now sits face-up on the DÉFAUSSE pile
	if ctx != null and ctx.shield_consumed:
		ctx.shield_consumed = false
		_ui.set_status(tr("Bouclier Vert : malus « %s » annulé !") % tr(chosen.display_name))
	else:
		var tag := tr("Malus") if chosen.is_malus else tr("Avantage")
		_ui.set_status("%s : %s" % [tag, tr(chosen.display_name)])
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
		_ui.set_status(tr("Prime gouvernementale : +%d dé(s) → +%d cases !") % [extra.size(), bonus])
	if ctx.replay:
		_ui.set_status(tr("Tous les feux au vert — tu rejoues un tour !"))


func _on_power() -> void:
	var player := _phase.current_player()
	if player.character == null or player.power_used or _phase.context() == null:
		_ui.set_status(tr("Aucun pouvoir disponible pour l'instant."))
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
		_ui.set_status(tr("Ce pouvoir n'est pas disponible maintenant."))
	_refresh_ui()


# True only right after rolling, before the first step — the boost button hides itself otherwise
# instead of failing silently on press (GamePhase.spend_boost_token enforces the same rule).
func _boost_usable_now() -> bool:
	var movement := _phase.movement()
	return _phase.current_subphase() == GamePhase.SubPhase.DEPLACEMENT \
		and movement != null and movement.path().size() <= 1


## Coup de pouce: offers to reroll every die or fix one to its max face, in a single chooser (one
## option per die + "relancer tout"), then spends a token via [method GamePhase.spend_boost_token].
func _on_boost_requested() -> void:
	if not _boost_usable_now():
		return
	var values := _dice.values()
	if values.is_empty():
		return
	var options: Array = [{"text": tr("Relancer tout"), "color": UITheme.GREEN}]
	for i in values.size():
		options.append({"text": tr("Dé %d → max (%d)") % [i + 1, DiceRoller.SIDES], "color": UITheme.ORANGE})
	_ui.show_chooser(tr("Coup de pouce — que faire ?"), options, func(choice: int) -> void:
		if choice < 0:
			return
		var old_total := _dice.total()
		var desc: String
		if choice == 0:
			var before := values.duplicate()
			_dice.roll(values.size())
			desc = tr("Relance : %s → %s") % [str(before), str(_dice.values())]
		else:
			var idx := choice - 1
			var old_value: int = values[idx]
			_dice.force(idx, DiceRoller.SIDES)
			desc = tr("Dé %d : %d → %d") % [idx + 1, old_value, DiceRoller.SIDES]
		var delta := _dice.total() - old_total
		if _phase.spend_boost_token(delta):
			AudioManager.sfx(&"power")
			_show_dice(_dice.values())
			_ui.set_status(tr("Coup de pouce : %s (%+d cases).") % [desc, delta])
			_refresh_highlights()
			_update_active_marker()
		_refresh_ui())


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
			_ui.set_status(tr("Dépassement : aucun autre joueur à dépasser."))
			return
		_ui.show_chooser(tr("Dépassement — échange ta place avec :"), options, func(choice: int) -> void:
			if choice < 0:
				return
			if _phase.swap_positions(indices[choice]):
				AudioManager.sfx(&"power")
				_ui.set_status(tr("Dépassement ! Place échangée."))
				_refresh_highlights()
				_update_active_marker()
				_refresh_ui())
	elif pid == &"coup_accelerateur":
		var values := _dice.values()
		if values.is_empty():
			_ui.set_status(tr("Coup d'Accélérateur : lance d'abord les dés."))
			return
		var options: Array = []
		for v in values:
			options.append({"text": tr("Dé : %d") % v, "color": UITheme.ORANGE})
		_ui.show_chooser(tr("Coup d'Accélérateur — relance quel dé ?"), options, func(choice: int) -> void:
			if choice < 0:
				return
			var old_value: int = values[choice]
			var new_value := _dice.reroll(choice)
			if _phase.apply_reroll(new_value - old_value):
				AudioManager.sfx(&"power")
				_show_dice(_dice.values())
				_ui.set_status(tr("Coup d'Accélérateur : %d → %d (%+d cases).") % [old_value, new_value, new_value - old_value])
				_refresh_highlights()
				_update_active_marker()
				_refresh_ui())


# Toast describing the effect of a non-interactive power that was just used.
func _power_message(pid: StringName) -> String:
	match pid:
		&"bonne_marcheuse":
			return tr("Bonne Marcheuse : +2 cases !")
		&"carnet_adresses":
			return tr("Carnet d'Adresses : ton prochain événement, pioche 2 et garde 1.")
		&"bouclier_vert":
			return tr("Bouclier Vert : le prochain malus sera annulé.")
		&"habitue_quartier":
			return tr("Habitué·e : ta prochaine livraison comptera au maximum.")
		&"passage_secret":
			return tr("Passage Secret : tu peux franchir l'eau ce tour-ci !")
		&"chargement_pro":
			return tr("Chargement Pro : +1 livraison transportable.")
		_:
			return tr("Super-pouvoir activé !")


func _on_pawn_moved(player: Player, _from: Vector2i, to: Vector2i) -> void:
	var pawn: Pawn = _pawns[player.index]
	pawn.move_to(to)
	_refresh_highlights()
	_update_active_marker()
	_refresh_ui()


func _on_turn_changed(player: Player) -> void:
	_can_roll = true
	_reservation_prompted.clear()  # a new turn may re-offer a delivery declined earlier
	_clear_dice()
	_refresh_highlights()
	_update_active_marker()
	_refresh_ui()
	_ui.show_banner(tr("Au tour de %s") % PlayerColor.name_of(player.color), PlayerColor.to_color(player.color))
	# turn_skipped fires synchronously right before turn_changed: fold the notice into this status
	# line, or a separate toast would be overwritten before anyone could read it.
	var status := tr("À toi de jouer — lance les dés.")
	if _skipped_notice != "":
		status = "%s %s" % [_skipped_notice, status]
		_skipped_notice = ""
	_ui.set_status(status)
	if player.is_ai:
		_play_ai_turn(player)


func _on_delivery_completed(delivery: Delivery, points: int) -> void:
	# The destinataire was recycled (or cleared) — refresh that delivery's recipient card + status.
	AudioManager.sfx(&"deliver")
	_celebrate_delivery(delivery.recipient_cell)
	_show_score_breakdown(delivery, _phase.current_player(), points)
	_rebuild_recipient_marker(delivery)
	_update_status_ring(delivery)  # back to DISPONIBLE -> ring removed
	if _delivery_panel != null:
		_delivery_panel.refresh()
	_ui.set_status(tr("Livré ! +%d points.") % points)
	_announce_last_run()
	_refresh_ui()


# Announces the endgame sprint once: fewer deliveries left than players — every one of them counts.
func _announce_last_run() -> void:
	if _last_run_announced or _phase.is_finished():
		return
	var remaining := _phase.deliveries_remaining()
	if remaining > 0 and remaining <= _players.size():
		_last_run_announced = true
		_ui.show_banner(tr("Dernière tournée !"), UITheme.ORANGE)


# A skipped player has nothing left to do (nothing in flight, nothing reservable): remember the
# notice — _on_turn_changed (fired right after) folds it into its status line.
func _on_turn_skipped(player: Player) -> void:
	var notice := tr("%s a fini sa journée — tour passé.") % PlayerColor.name_of(player.color)
	_skipped_notice = notice if _skipped_notice == "" else "%s %s" % [_skipped_notice, notice]


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


# Floats "5 +10 (ton quartier) +10 (ton client) = 25" above the delivered recipient cell — the
# device that teaches the territorial scoring rule at the exact moment it pays off. Any gap between
# the plain breakdown and the delivery's actual [param points] (Habitué·e, Livraison Écologique) is
# called out rather than silently dropped.
func _show_score_breakdown(delivery: Delivery, player: Player, points: int) -> void:
	var breakdown := ScoreCalculator.breakdown_delivery(delivery, player.color)
	var parts: Array[String] = ["%d" % int(breakdown["base"])]
	if breakdown["drive_bonus"] > 0:
		parts.append(tr("+%d (ton quartier)") % int(breakdown["drive_bonus"]))
	if breakdown["recipient_bonus"] > 0:
		parts.append(tr("+%d (ton client)") % int(breakdown["recipient_bonus"]))
	var text := "%s = %d" % [" ".join(parts), int(breakdown["subtotal"])]
	if points != int(breakdown["subtotal"]):
		if points == int(breakdown["subtotal"]) * 2:
			text += tr(" → ×2 (Livraison Écologique)")
		else:
			text += " → %d" % points
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.0085
	label.modulate = PlayerColor.to_color(player.color)
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.65)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	var pos := HexUtils.axial_to_world(delivery.recipient_cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.9
	label.position = pos
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", pos.y + 0.7, 1.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.5)
	tween.tween_callback(label.queue_free)


func _confetti_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color("ffd23f"))
	g.set_color(1, Color("ff6b6b"))
	g.add_point(0.5, Color("4ecdc4"))
	return g


func _on_game_finished(scores: Dictionary) -> void:
	if _tournee_session != null:
		return  # La Tournée has its own end screen, driven by TourneeSession.session_finished
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
		var generator := _phase.generator()
		var upcoming: Array[DestinataireDefinition] = []
		if generator != null:
			upcoming = generator.peek_upcoming(3)
		_delivery_panel.set_upcoming(upcoming)
	if _player_panel != null:
		_player_panel.refresh(_phase, player)
	_ui.set_deck_counts(_events.draw_count(), _events.discard_count())
	# The power needs the turn context (it acts during movement), so only offer it then — never a dead
	# press during planning, and never silently wasted on an unimplemented effect.
	var power_ready := player.character != null and not player.power_used and _phase.context() != null
	_ui.set_power_available(power_ready)
	_ui.set_boost_tokens(player.boost_tokens, _boost_usable_now())
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
