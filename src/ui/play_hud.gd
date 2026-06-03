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
