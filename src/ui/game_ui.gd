class_name GameUI
extends CanvasLayer
## Play-phase UI: a compact turn-order strip (top center), whose turn it is + their score, a
## rebuildable action bar (roll dice, pick up, deliver, power, end turn) and the live status line.
## A final panel shows the scores. Emits intents; GameRoot acts. Stays dumb.

signal roll_requested
signal end_turn_requested
signal pickup_requested
signal deliver_requested
signal power_requested

const _CHIP := Vector2(26, 26)

var _turn_label: Label
var _score_label: Label
var _status_label: Label
var _actions: HBoxContainer
var _order_bar: HBoxContainer
var _end_panel: Control
var _players: Array[Player] = []
var _chips: Array[Panel] = []


func _ready() -> void:
	var panel := MarginContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		panel.add_theme_constant_override("margin_" + side, 16)
	add_child(panel)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 24)
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(_turn_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(_score_label)

	# Turn-order strip, centered at the top, separate from everything else.
	_order_bar = HBoxContainer.new()
	_order_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_order_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_order_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_order_bar.add_theme_constant_override("separation", 6)
	panel.add_child(_order_bar)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	panel.add_child(bottom)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_status_label)

	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 10)
	bottom.add_child(_actions)


## Builds the turn-order strip once (a colored chip per player, in seat order).
func setup_players(players: Array[Player]) -> void:
	_players = players
	for child in _order_bar.get_children():
		child.queue_free()
	_chips.clear()
	for player in players:
		var chip := Panel.new()
		chip.custom_minimum_size = _CHIP
		_order_bar.add_child(chip)
		_chips.append(chip)


## Rebuilds the action bar for a turn and highlights the current player in the strip.
func refresh(player: Player, score: int, can_roll: bool, carrying: Delivery) -> void:
	var who := PlayerColor.name_of(player.color)
	if player.character != null:
		who = "%s (%s)" % [player.character.display_name, who]
	_turn_label.text = "Tour : %s" % who
	_turn_label.add_theme_color_override("font_color", PlayerColor.to_color(player.color))
	_score_label.text = "Score : %d" % score
	_highlight_current(player.index)

	for child in _actions.get_children():
		child.queue_free()

	var roll := _button("Lancer les dés", Vector2(150, 48))
	roll.disabled = not can_roll
	roll.pressed.connect(func() -> void: roll_requested.emit())
	_actions.add_child(roll)

	if carrying == null:
		var pickup := _button("Prendre", Vector2(120, 48))
		pickup.pressed.connect(func() -> void: pickup_requested.emit())
		_actions.add_child(pickup)
	else:
		var deliver := _button("Livrer", Vector2(120, 48))
		deliver.pressed.connect(func() -> void: deliver_requested.emit())
		_actions.add_child(deliver)

	if player.character != null and not player.power_used:
		var power := _button("Pouvoir : %s" % _power_name(player.character.power_id), Vector2(180, 48))
		power.pressed.connect(func() -> void: power_requested.emit())
		_actions.add_child(power)

	var end := _button("Fin de tour", Vector2(130, 48))
	end.pressed.connect(func() -> void: end_turn_requested.emit())
	_actions.add_child(end)


# Tints each chip its player's color; the current seat gets a white border and a slight grow.
func _highlight_current(current_index: int) -> void:
	for i in _chips.size():
		var color := PlayerColor.to_color(_players[i].color)
		var is_current := _players[i].index == current_index
		var style := StyleBoxFlat.new()
		style.bg_color = color if is_current else color.darkened(0.35)
		style.set_corner_radius_all(5)
		if is_current:
			style.set_border_width_all(3)
			style.border_color = Color.WHITE
		_chips[i].add_theme_stylebox_override("panel", style)
		_chips[i].custom_minimum_size = _CHIP * (1.25 if is_current else 1.0)


## Sets the status line (dice result, remaining budget, hints).
func set_status(text: String) -> void:
	_status_label.text = text


## Shows the final scoreboard. [param scores] maps seat index -> total.
func show_end(scores: Dictionary, players: Array[Player]) -> void:
	for child in _actions.get_children():
		child.queue_free()
	_status_label.text = ""
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


func _button(text: String, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	return b


const _POWER_NAMES := {
	&"bouclier_vert": "Bouclier Vert",
	&"habitue_quartier": "Habitué·e",
	&"passage_secret": "Passage Secret",
	&"bonne_marcheuse": "Bonne Marcheuse",
	&"coup_accelerateur": "Coup d'Accélérateur",
	&"depassement": "Dépassement",
	&"chargement_pro": "Chargement Pro",
	&"carnet_adresses": "Carnet d'Adresses",
}


func _power_name(power_id: StringName) -> String:
	return _POWER_NAMES.get(power_id, "spécial")
