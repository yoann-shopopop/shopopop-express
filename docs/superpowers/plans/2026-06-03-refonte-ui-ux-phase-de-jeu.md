# Refonte UI/UX de la phase de jeu — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réorganiser le HUD de la phase de jeu autour d'un plateau encadré, en réutilisant les composants 3D existants (`ClipCardView`, `PawnView` jeton, `DieView`, `CardView`) et un cadre 2D `CanvasLayer`.

**Architecture:** Rendu **hybride** : un `CanvasLayer` 2D (`PlayHud`) dessine le cadre fenêtre, la barre de titre (tour/score/ordre + zoom ＋/－), les fonds d'emplacements et les boutons d'action ; les composants 3D réutilisés sont épinglés chaque frame dans des régions d'écran par `GameRoot` (même technique que les dés actuels). La logique (`GamePhase`) est inchangée.

**Tech Stack:** Godot 4.6, GDScript, GUT (tests headless).

**Commandes** (binaire macOS) :
- Import : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Un fichier de test : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<f>.gd -gexit`
- Suite complète : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit`
- Boot : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30 scenes/main.tscn 2>&1 | grep -iE "error|invalid|nil|SCRIPT"`

**Structure de fichiers**
- `src/ui/play_hud.gd` (créé) — `CanvasLayer` : cadre + barre de titre (tour/score/ordre + zoom) + bouton contextuel + bouton pouvoir + fonds DECK/2 emplacements/DÉFAUSSE + panneau de fin. Émet des intentions, expose une API d'état.
- `src/view/delivery_list_view.gd` (créé) — `Node3D` : collection de `ClipCardView` (une par `Delivery`), positionnée à gauche, avec défilement.
- `src/view/clip_card_view.gd` (modifié) — `bind_delivery(Delivery)`.
- `src/game/delivery.gd` (modifié) — `is_available()`.
- `src/game/game_root.gd` (modifié) — swap `GameUI`→`PlayHud`, jetons drive/destinataire, dés+cubes, rangée cartes, pinning des régions, câblage.
- `src/ui/game_ui.gd` (supprimé en fin de plan).
- `src/interaction/event_card_choice.gd` (modifié) — présentation dans les 2 emplacements bas.

> Repère placement écran→monde (caméra ortho top-down, `rotation (-90,0,0)`) : un point d'offset écran normalisé `(nx, ny)` ∈ [-1,1] (x→droite, y→haut) se place en monde à `center + Vector3(nx*half_w, lift, -ny*half_h)`, avec `half_h = camera.size*0.5`, `half_w = half_h*aspect`, `center = (camera.x, 0, camera.z)`, et une échelle `k * (camera.size/REF_SIZE)`. C'est la généralisation du code de pinning des dés déjà présent dans `GameRoot._process`.

---

## Task 1 : `PlayHud` — cadre 2D, barre de titre (zoom/tour/score), boutons d'action

**Files:**
- Create: `src/ui/play_hud.gd`
- Modify: `src/game/game_root.gd`

> Couche Node, non testée par GUT : validée par import + boot + `test_game_root.gd`.

- [ ] **Step 1 : Créer `src/ui/play_hud.gd`**

```gdscript
class_name PlayHud
extends CanvasLayer
## 2D chrome for the play phase: a framed board window (title bar carrying turn/score, the player-order
## strip and the zoom +/- buttons), a contextual primary action button + a power button (bottom-left),
## and the bottom event-card slot backings (DECK / two slots / DÉFAUSSE). Emits intents; GameRoot acts
## and pins the 3D pieces (delivery list, dice, cards) into the regions this frame defines.

signal roll_requested
signal reserve_requested
signal end_turn_requested
signal power_requested
signal zoom_in_requested
signal zoom_out_requested

## The contextual primary action.
enum Action { ROLL, RESERVE, END_TURN }

const _ACTION_LABEL := {
	Action.ROLL: "Lancer",
	Action.RESERVE: "Réserver",
	Action.END_TURN: "Fin de tour",
}

# Screen fractions (0..1 of the viewport) the frame occupies; GameRoot mirrors these to place the 3D
# pieces, so the 2D chrome and the 3D content stay visually aligned. Tune together.
const BOARD_RECT := Rect2(0.27, 0.04, 0.71, 0.66)   # x, y, w, h (fractions)
const LEFT_RECT := Rect2(0.01, 0.06, 0.24, 0.62)
const CARDS_Y := 0.80                                # vertical fraction of the card row

var _turn_label: Label
var _score_label: Label
var _order_bar: HBoxContainer
var _action_btn: Button
var _power_btn: Button
var _end_panel: Control
var _players: Array[Player] = []
var _chips: Array[Panel] = []
var _action: int = Action.ROLL


func _ready() -> void:
	_build_frame()
	_build_title_bar()
	_build_actions()
	_build_card_backings()


# A thin window frame around the board region (visual only).
func _build_frame() -> void:
	var frame := Panel.new()
	frame.name = "BoardFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.anchor_left = BOARD_RECT.position.x
	frame.anchor_top = BOARD_RECT.position.y
	frame.anchor_right = BOARD_RECT.position.x + BOARD_RECT.size.x
	frame.anchor_bottom = BOARD_RECT.position.y + BOARD_RECT.size.y
	frame.offset_left = 0; frame.offset_top = 0; frame.offset_right = 0; frame.offset_bottom = 0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks reach the 3D board
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)  # transparent body (board shows through)
	style.set_border_width_all(3)
	style.border_color = Color("3a4252")
	style.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)


func _build_title_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TitleBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.anchor_left = BOARD_RECT.position.x
	bar.anchor_right = BOARD_RECT.position.x + BOARD_RECT.size.x
	bar.offset_top = 4
	bar.offset_left = 10
	bar.offset_right = -10
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(_turn_label)

	_order_bar = HBoxContainer.new()
	_order_bar.add_theme_constant_override("separation", 4)
	bar.add_child(_order_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(_score_label)

	var zoom_out := _small_button("－")
	zoom_out.pressed.connect(func() -> void: zoom_out_requested.emit())
	bar.add_child(zoom_out)
	var zoom_in := _small_button("＋")
	zoom_in.pressed.connect(func() -> void: zoom_in_requested.emit())
	bar.add_child(zoom_in)


func _build_actions() -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 20
	box.offset_top = -84
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_action_btn = Button.new()
	_action_btn.custom_minimum_size = Vector2(190, 64)
	_action_btn.add_theme_font_size_override("font_size", 24)
	_action_btn.pressed.connect(_on_action_pressed)
	box.add_child(_action_btn)

	_power_btn = Button.new()
	_power_btn.text = "⚡"
	_power_btn.custom_minimum_size = Vector2(64, 64)
	_power_btn.add_theme_font_size_override("font_size", 24)
	_power_btn.pressed.connect(func() -> void: power_requested.emit())
	box.add_child(_power_btn)
	set_action(Action.ROLL)


func _build_card_backings() -> void:
	# DECK / two slots / DÉFAUSSE labels along the bottom (purely visual anchors).
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	for caption in ["DECK", "", "", "DÉFAUSSE"]:
		var lbl := Label.new()
		lbl.text = caption
		lbl.custom_minimum_size = Vector2(90, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(lbl)


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(34, 30)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _on_action_pressed() -> void:
	match _action:
		Action.ROLL: roll_requested.emit()
		Action.RESERVE: reserve_requested.emit()
		Action.END_TURN: end_turn_requested.emit()


## Sets the contextual primary action (changes the button label + which intent it emits).
func set_action(action: int) -> void:
	_action = action
	_action_btn.text = _ACTION_LABEL[action]


## Shows/enables the power button (hidden once the one-shot power is spent).
func set_power_available(available: bool) -> void:
	_power_btn.visible = available


## Builds the player-order strip once (a colored chip per player, seat order).
func setup_players(players: Array[Player]) -> void:
	_players = players
	for child in _order_bar.get_children():
		child.queue_free()
	_chips.clear()
	for player in players:
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(20, 20)
		_order_bar.add_child(chip)
		_chips.append(chip)


## Updates turn label, score, and highlights the current player's chip.
func refresh(player: Player, score: int) -> void:
	var who := PlayerColor.name_of(player.color)
	_turn_label.text = "Tour : %s" % who
	_turn_label.add_theme_color_override("font_color", PlayerColor.to_color(player.color))
	_score_label.text = "Score : %d" % score
	for i in _chips.size():
		var color := PlayerColor.to_color(_players[i].color)
		var is_current := _players[i].index == player.index
		var style := StyleBoxFlat.new()
		style.bg_color = color if is_current else color.darkened(0.35)
		style.set_corner_radius_all(4)
		if is_current:
			style.set_border_width_all(2)
			style.border_color = Color.WHITE
		_chips[i].add_theme_stylebox_override("panel", style)


func set_status(_text: String) -> void:
	pass  # status now conveyed by the contextual button + board; kept for call-site compatibility


## Shows the final scoreboard. [param scores] maps seat index -> total.
func show_end(scores: Dictionary, players: Array[Player]) -> void:
	_action_btn.hide()
	_power_btn.hide()
	_end_panel = CenterContainer.new()
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_end_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_end_panel.add_child(box)
	var title := Label.new()
	title.text = "Partie terminée"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var total := 0
	for player in players:
		var pts: int = scores.get(player.index, 0)
		total += pts
		var line := Label.new()
		line.text = "%s : %d pts" % [PlayerColor.name_of(player.color), pts]
		line.add_theme_color_override("font_color", PlayerColor.to_color(player.color))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)
	var sum := Label.new()
	sum.text = "Total collectif : %d pts" % total
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sum)
```

- [ ] **Step 2 : Câbler `PlayHud` dans `GameRoot.setup()` (remplace `GameUI` + `ZoomControls`)**

Dans `src/game/game_root.gd`, remplacer le type du champ et l'instanciation/branchements. Changer la déclaration :
```gdscript
var _ui: GameUI
```
en :
```gdscript
var _ui: PlayHud
```
Dans `setup()`, remplacer le bloc qui crée `_ui = GameUI.new()` … et les `connect` d'UI par :
```gdscript
	_ui = PlayHud.new()
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
	_phase.delivery_reserved.connect(_on_delivery_changed)
	_phase.delivery_in_progress.connect(_on_delivery_changed)
	_phase.game_finished.connect(_on_game_finished)
	_phase.event_triggered.connect(_on_event_triggered)
	_ui.roll_requested.connect(_on_roll)
	_ui.end_turn_requested.connect(_phase.end_turn)
	_ui.reserve_requested.connect(_on_reserve)
	_ui.power_requested.connect(_on_power)
	_ui.zoom_in_requested.connect(camera.zoom_in)
	_ui.zoom_out_requested.connect(camera.zoom_out)
	_refresh_ui()
```

> The `camera` parameter of `setup()` is a `CameraRig` (it has `zoom_in`/`zoom_out` from the earlier work) typed as `Camera3D`; cast if needed: `(camera as CameraRig).zoom_in`. If `camera` is declared `Camera3D`, change the connects to `(camera as CameraRig).zoom_in` / `.zoom_out`.

- [ ] **Step 3 : Adapter `_refresh_ui` pour piloter le bouton contextuel**

Remplacer `_refresh_ui()` par :
```gdscript
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
```

Et remplacer la ligne dans `_on_roll` qui faisait `_ui.set_status(...)` et l'ancien `_ui.refresh(player, score, can_roll, reservable)` partout par `_refresh_ui()`. Supprimer toute référence à `GameUI`-spécifique (l'ancienne signature `refresh(player, score, can_roll, can_reserve)`), et retirer la création de `ZoomControls` si `GameRoot` en créait (sinon, le retrait de `ZoomControls` se fait dans `src/main.gd` — vérifier : `ZoomControls` est instancié dans `main.gd`, pas dans `GameRoot`).

> `ZoomControls` est créé dans `src/main.gd` (pour la phase de placement). Le laisser pour le placement, mais il restera visible en jeu. Décision : dans `main.gd`, masquer `_zoom_controls` quand la phase de jeu démarre (`_zoom_controls.hide()` au moment où `GameRoot` prend la main) puisque `PlayHud` fournit désormais le zoom en barre de titre. Repérer dans `main.gd` l'endroit où l'on bascule vers `GameRoot` (`_game_root = GameRoot.new()`) et y ajouter `_zoom_controls.hide()`.

- [ ] **Step 4 : Import + boot + smoke test**

Run import, puis :
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_root.gd -gexit`
Expected : PASS (1/1).
Boot : `... --quit-after 30 scenes/main.tscn 2>&1 | grep -iE "error|invalid|nil|SCRIPT"` → aucune erreur.

- [ ] **Step 5 : Commit**

```bash
git add src/ui/play_hud.gd src/game/game_root.gd src/main.gd
git commit -m "feat(ui): PlayHud — cadre plateau, zoom en barre de titre, bouton d'action contextuel + pouvoir"
```

---

## Task 2 : Jetons 3D drive & destinataire sur les tuiles

**Files:**
- Modify: `src/game/game_root.gd`

> Remplace les « cartes flottantes » `_enseigne_marker`/`_destinataire_marker` par des `PawnView` en mode jeton (déjà existant : `PawnView._build_token` via un `PawnDefinition` de type DRIVE/RECIPIENT portant une `texture`).

- [ ] **Step 1 : Remplacer la construction des marqueurs**

Dans `src/game/game_root.gd`, remplacer `_build_delivery_markers`, `_enseigne_marker`, `_destinataire_marker`, `_card`, `_rebuild_recipient_marker` par des jetons `PawnView`. Nouveau code :
```gdscript
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
```

> `PawnView.bind(pawn)` builds a token (chip + image) when `pawn.definition.is_mobile()` is false (DRIVE/RECIPIENT). `Pawn.place(cell)` positions it. The token's world position comes from `PawnView._move_to_cell` (already lifts above the tile). No `_card` helper needed anymore — delete it.

- [ ] **Step 2 : Import + boot + smoke test**

Import, boot (aucune erreur), `test_game_root.gd` PASS.

- [ ] **Step 3 : Commit**

```bash
git add src/game/game_root.gd
git commit -m "feat(game): jetons 3D drive/destinataire sur les tuiles (PawnView) au lieu des cartes flottantes"
```

---

## Task 3 : Colonne gauche — `DeliveryListView` (ClipCardView par livraison)

**Files:**
- Modify: `src/game/delivery.gd`
- Modify: `src/view/clip_card_view.gd`
- Create: `src/view/delivery_list_view.gd`
- Modify: `src/game/game_root.gd`
- Test: `tests/test_delivery.gd`, `tests/test_clip_card_view.gd`

- [ ] **Step 1 : Test `Delivery.is_available()`**

Ajouter à `tests/test_delivery.gd` :
```gdscript
func test_is_available_is_true_only_when_disponible() -> void:
	var d := _delivery(0)
	assert_true(d.is_available(), "DISPONIBLE par défaut")
	d.status = DeliveryStatus.Kind.RESERVE
	assert_false(d.is_available())
```

- [ ] **Step 2 : Vérifier l'échec**

Run `-gtest=res://tests/test_delivery.gd` → FAIL (`is_available` inexistante).

- [ ] **Step 3 : Ajouter `is_available()` à `src/game/delivery.gd`**

Après `is_reservable()` :
```gdscript
## True while the delivery is on the board and not yet taken (status DISPONIBLE), recipient or not.
func is_available() -> bool:
	return status == DeliveryStatus.Kind.DISPONIBLE
```

- [ ] **Step 4 : Test `ClipCardView.bind_delivery`**

Ajouter à `tests/test_clip_card_view.gd` (le fichier existe ; ajouter la fonction) :
```gdscript
func test_bind_delivery_shows_status_insert_when_not_available() -> void:
	var piece := PlacedPiece.new(_min_block(), Vector2i.ZERO, 0, 0)
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [piece] as Array[PlacedPiece])
	d.enseigne = EnseigneDefinition.new()
	d.destinataire = DestinataireDefinition.new()
	var view := ClipCardView.new()
	add_child_autofree(view)
	view.bind_delivery(d)
	assert_false(view.has_status_insert(), "DISPONIBLE → pas d'insert")
	d.status = DeliveryStatus.Kind.EN_COURS
	view.bind_delivery(d)
	assert_true(view.has_status_insert(), "EN_COURS → insert visible")


func _min_block() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return b
```

> Si `tests/test_clip_card_view.gd` n'a pas encore de helper/forme compatible, ajouter ces fonctions à la suite des tests existants (ne pas casser ceux qui utilisent `bind(combo)`).

- [ ] **Step 5 : Vérifier l'échec**

Run `-gtest=res://tests/test_clip_card_view.gd` → FAIL (`bind_delivery` inexistante).

- [ ] **Step 6 : Ajouter `bind_delivery` à `src/view/clip_card_view.gd`**

`ClipCardView.bind()` lit `combo.enseigne`, `combo.destinataire`, `combo.status`, `combo.is_available()`. Extraire le corps en une routine paramétrée et ajouter `bind_delivery`. Remplacer la méthode `bind` et ajouter `bind_delivery` :
```gdscript
## Builds (or rebuilds) the view for [param combo] (demo path).
func bind(combo: DeliveryCombo) -> void:
	_build(combo.enseigne, combo.destinataire, combo.status)


## Builds (or rebuilds) the view for a spatial [Delivery] (game path).
func bind_delivery(delivery: Delivery) -> void:
	_build(delivery.enseigne, delivery.destinataire, delivery.status)


func _build(enseigne: EnseigneDefinition, destinataire: DestinataireDefinition, status: int) -> void:
	_enseigne = enseigne
	_destinataire = destinataire
	_status = status
	for child in get_children():
		child.queue_free()
	_insert = null
	var step := CARD.x * 0.5 + INSERT.x * 0.5 + GAP
	_add_card(Vector3(-step, 0.0, 0.0), CARD, enseigne.color, enseigne.display_name, enseigne.texture)
	var dest_color: Color = destinataire.color if destinataire else Color("33384a")
	var dest_name: String = destinataire.display_name if destinataire else "(vide)"
	var dest_tex: Texture2D = destinataire.texture if destinataire else null
	_add_card(Vector3(step, 0.0, 0.0), CARD, dest_color, dest_name, dest_tex)
	refresh()
```

Remplacer les champs et `refresh()` pour ne plus dépendre de `_combo` :
```gdscript
var _enseigne: EnseigneDefinition
var _destinataire: DestinataireDefinition
var _status: int = DeliveryStatus.Kind.DISPONIBLE
var _insert: Node3D = null
```
```gdscript
## Updates the status insert to match the current status.
func refresh() -> void:
	if _insert != null:
		_insert.queue_free()
		_insert = null
	if _status == DeliveryStatus.Kind.DISPONIBLE:
		return
	_insert = _make_slab(Vector3.ZERO, INSERT, Color("20242c"))
	_insert.add_child(_make_label(DeliveryStatus.label(_status), Color.WHITE, INSERT.x))
	add_child(_insert)
```
(Supprimer l'ancien champ `var _combo: DeliveryCombo`.)

- [ ] **Step 7 : Vérifier le succès (delivery + clip_card)**

Run `-gtest=res://tests/test_delivery.gd,res://tests/test_clip_card_view.gd` → PASS.

- [ ] **Step 8 : Créer `src/view/delivery_list_view.gd`**

```gdscript
class_name DeliveryListView
extends Node3D
## The left column: one ClipCardView per delivery, stacked vertically and pinned into a screen region
## by GameRoot. Scroll offsets the stack; cards outside the region are hidden. Pure rendering.

const ROW_GAP := 1.5         # vertical world gap between cards (before scaling)
const VISIBLE_ROWS := 4      # how many rows fit in the left region at once

var _views: Array[ClipCardView] = []
var _deliveries: Array[Delivery] = []
var _scroll: int = 0         # index of the first visible row


## Rebuilds one card per delivery (call once after setup).
func build(deliveries: Array[Delivery]) -> void:
	for v in _views:
		v.queue_free()
	_views.clear()
	_deliveries = deliveries
	for delivery in deliveries:
		var view := ClipCardView.new()
		add_child(view)
		view.bind_delivery(delivery)
		_views.append(view)


## Re-reads every delivery's status (call on any delivery change).
func refresh_statuses() -> void:
	for i in _views.size():
		_views[i].bind_delivery(_deliveries[i])


## Scrolls the list by [param delta] rows (clamped).
func scroll_by(delta: int) -> void:
	_scroll = clampi(_scroll + delta, 0, maxi(0, _views.size() - VISIBLE_ROWS))


## Lays the cards out around [param origin] (world), each row [param row_step] down (world units),
## scaled by [param card_scale]. Rows outside the visible window are hidden.
func layout(origin: Vector3, row_step: float, card_scale: float) -> void:
	for i in _views.size():
		var slot := i - _scroll
		var visible := slot >= 0 and slot < VISIBLE_ROWS
		_views[i].visible = visible
		if visible:
			_views[i].position = origin + Vector3(0.0, 0.0, slot * row_step)
			_views[i].scale = Vector3.ONE * card_scale
```

- [ ] **Step 9 : Brancher la liste dans `GameRoot`**

Dans `game_root.gd` : ajouter le champ `var _delivery_list: DeliveryListView`, l'instancier dans `setup()` après `_build_delivery_markers` :
```gdscript
	_delivery_list = DeliveryListView.new()
	add_child(_delivery_list)
	_delivery_list.build(deliveries)
```
La rafraîchir dans `_on_delivery_changed` et `_on_delivery_completed` (ajouter `_delivery_list.refresh_statuses()`), et la positionner dans `_process` (voir Step 10). Câbler le défilement molette : dans `_on_event_triggered`/input — simplement, ajouter une méthode :
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and _delivery_list != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _over_left_region():
			_delivery_list.scroll_by(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _over_left_region():
			_delivery_list.scroll_by(-1)


# True if the mouse is over the left third of the screen (the delivery column).
func _over_left_region() -> bool:
	return get_viewport().get_mouse_position().x < get_viewport().get_visible_rect().size.x * 0.26
```

- [ ] **Step 10 : Positionner la liste dans `_process`**

Dans `_process`, après le code des dés, ajouter le placement de la liste (région gauche, fractions `PlayHud.LEFT_RECT`) :
```gdscript
	if _delivery_list != null:
		# Left column: centered horizontally on x≈-0.82*half_w, top near +0.5*half_h, rows going down (+z).
		var left_origin := center + Vector3(-half_w * 0.82, 1.0, -half_h * 0.46)
		_delivery_list.layout(left_origin, half_h * 0.30 * zoom, 0.55 * zoom)
```

> Les fractions (`-0.82`, `-0.46`, `0.30`, `0.55`) sont des valeurs de départ alignées sur `PlayHud.LEFT_RECT` ; ajustables visuellement après coup.

- [ ] **Step 11 : Import + tests + boot**

Import ; suite complète verte ; boot sans erreur.

- [ ] **Step 12 : Commit**

```bash
git add src/game/delivery.gd src/view/clip_card_view.gd src/view/delivery_list_view.gd src/game/game_root.gd tests/test_delivery.gd tests/test_clip_card_view.gd
git commit -m "feat(ui): colonne gauche des livraisons (ClipCardView par Delivery, défilable)"
```

---

## Task 4 : Dés + cubes de budget

**Files:**
- Modify: `src/game/game_root.gd`

- [ ] **Step 1 : Ajouter un porteur de cubes**

Dans `game_root.gd` : champ `var _budget_cubes: Node3D`. Dans `setup()`, après `_dice_views` :
```gdscript
	_budget_cubes = Node3D.new()
	add_child(_budget_cubes)
```
Ajouter les fonctions :
```gdscript
# Shows [param remaining] little cubes = remaining movement budget.
func _show_budget(remaining: int) -> void:
	for child in _budget_cubes.get_children():
		child.queue_free()
	for i in remaining:
		var inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.5, 0.5)
		inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e6b800")
		inst.material_override = mat
		inst.position = Vector3(i * 0.62, 0.0, 0.0)
		_budget_cubes.add_child(inst)
```

- [ ] **Step 2 : Mettre à jour les cubes sur le budget**

Dans `_on_roll`, après `_phase.begin_movement(...)`, appeler `_show_budget(_dice.total())`. Dans `_on_budget_changed(remaining)`, remplacer le corps par `_show_budget(remaining)`. Dans `_on_turn_changed` et `_clear_dice`, vider aussi les cubes (`for c in _budget_cubes.get_children(): c.queue_free()`), ou appeler `_show_budget(0)`.

- [ ] **Step 3 : Positionner les cubes dans `_process`**

Sous le placement des dés :
```gdscript
	if _budget_cubes != null and _budget_cubes.get_child_count() > 0:
		_budget_cubes.position = center + Vector3(-half_w * 0.30, 1.0, half_h * 0.50)
		_budget_cubes.scale = Vector3.ONE * 2.2 * zoom
```

- [ ] **Step 4 : Import + boot**

Import ; boot sans erreur ; suite verte.

- [ ] **Step 5 : Commit**

```bash
git add src/game/game_root.gd
git commit -m "feat(ui): cubes de budget (pas restants) à côté des dés"
```

---

## Task 5 : Rangée cartes événement (DECK / 2 emplacements / DÉFAUSSE)

**Files:**
- Modify: `src/interaction/event_card_choice.gd`
- Modify: `src/game/game_root.gd`

> On conserve la logique « pioche 2 / garde 1 / active » (`EventCardChoice`) mais on la présente dans les deux emplacements bas (au lieu du centre). `EventCardChoice` est déjà autonome ; il suffit de l'ancrer dans la région basse au lieu du centre.

- [ ] **Step 1 : Ancrer le choix dans la rangée basse**

Dans `src/game/game_root.gd`, `_on_event_triggered`, remplacer le calcul d'ancrage centré :
```gdscript
	var anchor := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE) + Vector3(0.0, 1.0, 0.0)
	_event_choice.present(drawn, _camera, anchor)
```
par un ancrage dans la rangée basse (centre-bas de l'écran), repositionné dans `_process` :
```gdscript
	_event_choice.present(drawn, _camera, Vector3.ZERO)  # position pinned each frame by _process
```
Et dans `_process`, là où l'ancien code épinglait `_event_choice` au centre, le placer en bas-centre :
```gdscript
	if _event_choice != null and is_instance_valid(_event_choice):
		_event_choice.position = center + Vector3(0.0, 1.0, half_h * 0.74)
		_event_choice.scale = Vector3.ONE * 3.0 * zoom
```

- [ ] **Step 2 : Espacer les deux cartes pour tomber dans les 2 emplacements**

Dans `src/interaction/event_card_choice.gd`, les positions de révélation `_REVEAL` (`±1.3`) conviennent ; les laisser. (Les emplacements `PlayHud` sont au centre-bas, séparés ; l'espacement `±1.3` × scale correspond.) Aucun changement de code requis ici sauf si le visuel impose d'élargir : ajuster `_REVEAL` à `±1.6` si besoin. Pour ce lot, **laisser `_REVEAL` tel quel**.

- [ ] **Step 3 : Import + boot**

Import ; boot sans erreur ; suite verte. (Le flux d'événement n'est pas couvert par un test de scène ; vérifier au moins l'absence d'erreur de parse/boot.)

- [ ] **Step 4 : Commit**

```bash
git add src/game/game_root.gd src/interaction/event_card_choice.gd
git commit -m "feat(ui): cartes événement présentées dans la rangée basse (DECK/emplacements/DÉFAUSSE)"
```

---

## Task 6 : Nettoyage + vérification finale

**Files:**
- Delete: `src/ui/game_ui.gd` (+ `.uid`)
- Modify: éventuels résidus

- [ ] **Step 1 : Vérifier qu'aucun code ne référence plus `GameUI`**

Run : `grep -rn "GameUI\|game_ui" src/ tests/`
Expected : aucune référence (hors d'éventuels commentaires). Si une référence subsiste, la migrer vers `PlayHud`.

- [ ] **Step 2 : Supprimer l'ancien `GameUI`**

```bash
git rm src/ui/game_ui.gd src/ui/game_ui.gd.uid
```

- [ ] **Step 3 : Import + suite complète + boot**

Import ; `... gut_cmdln.gd -gexit` → « All tests passed! » (208 + 2 nouveaux = 210) ; boot `scenes/main.tscn` sans erreur.

- [ ] **Step 4 : Vérifier les références mortes de pinning**

`grep -rn "_REF_SIZE\|half_w\|half_h" src/game/game_root.gd` → confirmer que le placement des dés, cubes, liste et cartes utilise la même base `center/half_w/half_h/zoom` (pas de duplication divergente). Si dupliqué, extraire un helper `_anchor(nx, ny, lift)` et l'utiliser partout.

- [ ] **Step 5 : Commit**

```bash
git add -A
git commit -m "chore(ui): retire l'ancien GameUI, PlayHud le remplace intégralement"
```

---

## Récapitulatif des signatures (cohérence)

- `PlayHud` (`CanvasLayer`) : signaux `roll_requested`/`reserve_requested`/`end_turn_requested`/`power_requested`/`zoom_in_requested`/`zoom_out_requested` ; enum `Action {ROLL, RESERVE, END_TURN}` ; API `setup_players(players)`, `refresh(player, score)`, `set_action(int)`, `set_power_available(bool)`, `set_status(String)` (no-op de compat), `show_end(scores, players)`.
- `Delivery.is_available() -> bool` (DISPONIBLE).
- `ClipCardView.bind_delivery(delivery)` + `bind(combo)` conservé ; `_build(enseigne, destinataire, status)` privé.
- `DeliveryListView` : `build(deliveries)`, `refresh_statuses()`, `scroll_by(int)`, `layout(origin, row_step, card_scale)`.
- `GameRoot` : `_current_action() -> int`, `_show_budget(int)`, jetons `_drive_token`/`_destinataire_token`/`_token_at`, `_delivery_list`, `_budget_cubes`.
