class_name PlayHud
extends CanvasLayer
## 2D chrome for the play phase: a thin top bar (game name, turn/score, the player-order strip and the
## zoom +/- buttons), a contextual primary action button + a power button (bottom-left), and the
## always-visible DECK / DÉFAUSSE card piles (bottom-right). No board frame — the board fills the view
## and only the terrain reacts to zoom. Emits intents; GameRoot acts and pins the 3D pieces (delivery
## list, dice, drawn cards) at fixed screen positions independent of zoom.

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

var _round_label: Label
var _turn_label: Label
var _score_label: Label
var _deliveries_label: Label
var _toast: Label
var _order_bar: HBoxContainer
var _action_btn: Button
var _power_btn: Button
var _end_panel: Control
var _players: Array[Player] = []
var _chips: Array[Panel] = []
var _action: int = Action.ROLL
var _char_frame: Panel       # framed character card of the current player (right of the board)
var _char_card: TextureRect
var _chooser: Control        # transient modal chooser (interactive powers), null when none


var _banner: Label


func _ready() -> void:
	_build_title_bar()
	_build_actions()
	_build_card_backings()
	_build_char_card()
	_build_toast()
	_build_banner()


# A big, splashy centered banner for headline moments (whose turn, "Événement !"). Distinct from the
# small running toast: it fades in, holds, and fades out, and never blocks input.
func _build_banner() -> void:
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 120
	_banner.offset_bottom = 210
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)


## Flashes a headline [param text] tinted [param color] across the centre — for turn changes and big
## events. Fades on its own.
func show_banner(text: String, color: Color = UITheme.TEXT) -> void:
	if _banner == null or text.is_empty():
		return
	_banner.text = text
	UITheme.make_title(_banner, 46, color)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.22)
	tween.tween_interval(0.9)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


# A transient banner just under the top bar that announces what just happened (roll, reservation,
# delivery, event, power). Centered, fades out on its own. This is the game's running feedback.
func _build_toast() -> void:
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 52
	_toast.offset_bottom = 92
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.make_title(_toast, 24)
	_toast.modulate.a = 0.0
	add_child(_toast)


# The current player's character card, framed in their color, on the right edge (whose-turn-it-is).
func _build_char_card() -> void:
	_char_frame = Panel.new()
	# Top-right, with a comfortable gap below the top bar (~42 px), 25% larger (228×316 -> 285×395).
	_char_frame.anchor_left = 1.0
	_char_frame.anchor_right = 1.0
	_char_frame.anchor_top = 0.0
	_char_frame.anchor_bottom = 0.0
	_char_frame.offset_left = -301
	_char_frame.offset_right = -16
	_char_frame.offset_top = 68
	_char_frame.offset_bottom = 463
	add_child(_char_frame)
	_char_card = TextureRect.new()
	_char_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_char_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_frame.add_child(_char_card)


func _build_title_bar() -> void:
	# A thin status bar across the very top of the screen (no board-enclosing frame).
	var bar_panel := Panel.new()
	bar_panel.name = "TopBar"
	bar_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_panel.offset_top = 0
	bar_panel.offset_bottom = 42
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = UITheme.PANEL_DARK
	bar_style.border_width_bottom = 2
	bar_style.border_color = UITheme.PANEL_BORDER
	bar_style.shadow_color = UITheme.SHADOW
	bar_style.shadow_size = 4
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	add_child(bar_panel)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 14
	bar.offset_right = -10
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	bar_panel.add_child(bar)

	var title := Label.new()
	title.text = "Shopopop Express"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.make_title(title, 24)
	bar.add_child(title)

	_round_label = Label.new()
	_round_label.text = "Manche 1"
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.make_title(_round_label, 20, UITheme.ORANGE)
	bar.add_child(_round_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_turn_label = Label.new()
	_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 20)
	bar.add_child(_turn_label)

	_order_bar = HBoxContainer.new()
	_order_bar.add_theme_constant_override("separation", 4)
	bar.add_child(_order_bar)

	_score_label = Label.new()
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.make_title(_score_label, 20)
	bar.add_child(_score_label)

	_deliveries_label = Label.new()
	_deliveries_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deliveries_label.add_theme_font_size_override("font_size", 20)
	_deliveries_label.add_theme_color_override("font_color", UITheme.TEXT)
	bar.add_child(_deliveries_label)

	var mute := _small_button("Son")
	mute.custom_minimum_size = Vector2(60, 34)
	mute.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		mute.text = "Muet" if AudioManager.toggle_mute() else "Son")
	bar.add_child(mute)

	var zoom_out := _small_button("−")  # U+2212 minus (renders cleanly, unlike fullwidth －)
	zoom_out.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		zoom_out_requested.emit())
	bar.add_child(zoom_out)
	var zoom_in := _small_button("+")
	zoom_in.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		zoom_in_requested.emit())
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
	_theme_button(_action_btn, UITheme.BLUE)
	_action_btn.pressed.connect(_on_action_pressed)
	box.add_child(_action_btn)

	_power_btn = Button.new()
	_power_btn.text = "⚡"
	_power_btn.custom_minimum_size = Vector2(64, 64)
	_power_btn.add_theme_font_size_override("font_size", 24)
	_theme_button(_power_btn, UITheme.ORANGE)
	_power_btn.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		power_requested.emit())
	box.add_child(_power_btn)
	set_action(Action.ROLL)


# Applies the shared UITheme look to a button (normal/hover/pressed/disabled states + text color).
func _theme_button(btn: Button, base: Color) -> void:
	btn.add_theme_stylebox_override("normal", UITheme.button_style(base))
	btn.add_theme_stylebox_override("hover", UITheme.button_style(base, 1.6))
	btn.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(base))
	btn.add_theme_stylebox_override("disabled", UITheme.button_style(base.darkened(0.3)))
	btn.add_theme_stylebox_override("focus", UITheme.button_style(base))
	btn.add_theme_color_override("font_color", UITheme.TEXT)
	btn.add_theme_color_override("font_disabled_color", UITheme.TEXT.darkened(0.35))


func _build_card_backings() -> void:
	# DECK (face-down pile) and DÉFAUSSE, always visible at the bottom-right as card-shaped backings.
	# The two drawn event cards appear large at screen center during a rainbow event (pinned by GameRoot).
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_right = -70
	row.offset_bottom = -16
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	# DECK reads as the active pile (blue accent), DÉFAUSSE as a neutral one.
	row.add_child(_card_pile("DECK", UITheme.BLUE, true))
	row.add_child(_card_pile("DÉFAUSSE", UITheme.PANEL_BORDER, false))


# A card-shaped backing (shared UITheme tray look) with a caption under it. [param accent] colors the
# border; [param active] thickens it (DECK vs DÉFAUSSE).
func _card_pile(caption: String, accent: Color, active: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var card := Panel.new()
	card.custom_minimum_size = Vector2(132, 188)
	card.add_theme_stylebox_override("panel", UITheme.tray_card_style(accent, active))
	col.add_child(card)
	var lbl := Label.new()
	lbl.text = caption
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", UITheme.TEXT)  # light text on the dark backdrop
	col.add_child(lbl)
	return col


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	# A lighter slate than the bar so the +/- read clearly on the dark header.
	_theme_button(b, Color("3c4858"))
	return b


func _on_action_pressed() -> void:
	AudioManager.sfx(&"ui_click")
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
	_order_bar.add_theme_constant_override("separation", 7)
	for player in players:
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(26, 26)
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
		style.bg_color = color if is_current else color.darkened(0.45)
		style.set_corner_radius_all(13)  # circular dots
		style.shadow_color = UITheme.SHADOW
		style.shadow_size = 2
		if is_current:
			style.set_border_width_all(3)
			style.border_color = Color.WHITE
		_chips[i].add_theme_stylebox_override("panel", style)
		# The active player's dot is a touch bigger, so it pops out of the row.
		_chips[i].custom_minimum_size = Vector2(30, 30) if is_current else Vector2(24, 24)
	_refresh_char_card(player)


# Shows the current player's character card, framed in their color (hidden if no character/texture).
func _refresh_char_card(player: Player) -> void:
	var has_card: bool = player.character != null and player.character.texture != null
	_char_frame.visible = has_card
	if not has_card:
		return
	_char_card.texture = player.character.texture
	var frame := StyleBoxFlat.new()
	frame.bg_color = UITheme.PANEL_DARK
	frame.set_corner_radius_all(10)
	frame.set_border_width_all(4)
	frame.border_color = PlayerColor.to_color(player.color)
	frame.set_content_margin_all(6)
	frame.shadow_color = UITheme.SHADOW
	frame.shadow_size = 5
	_char_frame.add_theme_stylebox_override("panel", frame)


## Flashes [param text] as a transient toast under the top bar — the game's running feedback (rolls,
## reservations, deliveries, events, powers). Fades on its own; calls replace one another.
func set_status(text: String) -> void:
	if _toast == null or text.is_empty():
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.7)


## Shows a transient modal chooser centered on screen: [param prompt] then one button per option
## ([code]{ "text": String, "color": Color }[/code]); calls [param on_pick] with the chosen index, then
## dismisses. A "Annuler" button dismisses with index -1. The dim backdrop blocks board clicks while
## open. Used by the interactive super-powers (Dépassement target, Coup d'Accélérateur die).
func show_chooser(prompt: String, options: Array, on_pick: Callable) -> void:
	dismiss_chooser()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # eats clicks so the board isn't moved meanwhile
	add_child(backdrop)
	_chooser = backdrop
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.pill_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var label := Label.new()
	label.text = prompt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UITheme.TEXT)
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.text = opt.get("text", "?")
		btn.custom_minimum_size = Vector2(132, 60)
		btn.add_theme_font_size_override("font_size", 20)
		_theme_button(btn, opt.get("color", UITheme.BLUE))
		var idx := i
		btn.pressed.connect(func() -> void:
			AudioManager.sfx(&"ui_click")
			dismiss_chooser()
			on_pick.call(idx))
		row.add_child(btn)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.custom_minimum_size = Vector2(132, 40)
	cancel.add_theme_font_size_override("font_size", 18)
	_theme_button(cancel, UITheme.PANEL_BORDER)
	cancel.pressed.connect(func() -> void:
		dismiss_chooser()
		on_pick.call(-1))
	box.add_child(cancel)


## Dismisses the modal chooser if one is open.
func dismiss_chooser() -> void:
	if _chooser != null and is_instance_valid(_chooser):
		_chooser.queue_free()
	_chooser = null


## Updates the round counter shown in the top bar.
func set_round(round_number: int) -> void:
	if _round_label != null:
		_round_label.text = "Manche %d" % round_number


## Updates the "deliveries left" indicator (the visible finish line).
func set_deliveries_remaining(count: int) -> void:
	if _deliveries_label != null:
		_deliveries_label.text = "Livraisons : %d" % count


## Shows the final scoreboard: a dimmed backdrop, the ranking (best first, top one highlighted), the
## cooperative total, and a "Rejouer" button. [param scores] maps seat index -> total.
func show_end(scores: Dictionary, players: Array[Player]) -> void:
	dismiss_chooser()
	_action_btn.hide()
	_power_btn.hide()
	if _char_frame != null:
		_char_frame.hide()
	_end_panel = ColorRect.new()
	_end_panel.color = Color(0.05, 0.07, 0.1, 0.82)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_end_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "Partie terminée !"
	UITheme.make_title(title, 38, UITheme.ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Rank players best-first; ties keep seat order.
	var ranked := players.duplicate()
	ranked.sort_custom(func(a: Player, b: Player) -> bool:
		return scores.get(a.index, 0) > scores.get(b.index, 0))
	var total := 0
	for i in ranked.size():
		var player: Player = ranked[i]
		var pts: int = scores.get(player.index, 0)
		total += pts
		var line := Label.new()
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == 0:
			line.text = "Meilleur·e : %s — %d pts" % [PlayerColor.name_of(player.color), pts]
			UITheme.make_title(line, 28, PlayerColor.to_color(player.color))
		else:
			line.text = "%d.  %s — %d pts" % [i + 1, PlayerColor.name_of(player.color), pts]
			line.add_theme_font_size_override("font_size", 20)
			line.add_theme_color_override("font_color", PlayerColor.to_color(player.color))
		box.add_child(line)

	var sum := Label.new()
	sum.text = "Total collectif : %d pts" % total
	UITheme.make_title(sum, 22, UITheme.GREEN)
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sum)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)

	var replay := Button.new()
	replay.text = "Rejouer"
	replay.custom_minimum_size = Vector2(220, 60)
	replay.add_theme_font_size_override("font_size", 24)
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_theme_button(replay, UITheme.BLUE)
	replay.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		get_tree().reload_current_scene())
	box.add_child(replay)
