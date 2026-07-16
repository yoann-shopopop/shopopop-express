class_name PlayerPanel
extends Control
## Persistent per-player stat row (a second bandeau under the title bar): one compact card per
## player showing their initial+color badge, current score, in-flight gauge ("X/2"), and power
## status (⚡ available / dimmed once spent). The active player's card is highlighted. This is the
## information a classement game needs at all times — before this panel, only the current player's
## own score was ever visible (`_score_label`), so nobody could see where the others stood without
## waiting for their turn.
##
## Colorblind accessibility: identity is never color-only here — the initial letter is always shown
## alongside the color badge (see [PlayerColor]). Pure rendering: built once, re-read on [method refresh].

const _CARD_BASE := Color("212734")

var _players: Array[Player] = []
var _cards: Array[PanelContainer] = []
var _score_labels: Array[Label] = []
var _flight_labels: Array[Label] = []
var _power_icons: Array[Label] = []


## Builds one card per player, in seat order. Called once after the players are known.
func build(players: Array[Player]) -> void:
	_players = players
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 46
	offset_bottom = 94
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_cards.clear()
	_score_labels.clear()
	_flight_labels.clear()
	_power_icons.clear()
	for player in players:
		row.add_child(_make_card(player))


func _make_card(player: Player) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_card(_CARD_BASE))
	_cards.append(card)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var color := PlayerColor.to_color(player.color)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(24, 24)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = color
	badge_sb.set_corner_radius_all(12)
	badge.add_theme_stylebox_override("panel", badge_sb)
	var initial := Label.new()
	initial.text = PlayerColor.initial_of(player.color)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_size_override("font_size", 14)
	initial.add_theme_color_override(
		"font_color", Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE)
	badge.add_child(initial)
	box.add_child(badge)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", -2)
	box.add_child(stats)

	var score := Label.new()
	score.add_theme_font_size_override("font_size", 15)
	score.add_theme_color_override("font_color", UITheme.TEXT)
	stats.add_child(score)
	_score_labels.append(score)

	var flight := Label.new()
	flight.add_theme_font_size_override("font_size", 11)
	flight.add_theme_color_override("font_color", UITheme.TEXT.darkened(0.15))
	stats.add_child(flight)
	_flight_labels.append(flight)

	var power := Label.new()
	power.text = "⚡"
	power.add_theme_font_size_override("font_size", 16)
	power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power.visible = player.character != null
	box.add_child(power)
	_power_icons.append(power)

	return card


## Re-reads live values from [param phase] and highlights [param current]'s card (brighter
## background + colored border instead of resizing, so the HBoxContainer never reflows/jitters).
func refresh(phase: GamePhase, current: Player) -> void:
	for i in _players.size():
		var player := _players[i]
		var is_current := player.index == current.index
		var color := PlayerColor.to_color(player.color)

		_score_labels[i].text = tr("%d pts") % phase.score_of(player)
		var cap := GamePhase.MAX_IN_FLIGHT + player.bonus_capacity
		_flight_labels[i].text = tr("%d/%d en vol") % [phase.deliveries_in_flight(player.index).size(), cap]

		var power := _power_icons[i]
		power.visible = player.character != null
		power.modulate = Color(1, 1, 1, 0.28) if player.power_used else Color(1, 1, 1, 1)

		var style := UITheme.panel_card(_CARD_BASE.lightened(0.08) if is_current else _CARD_BASE)
		if is_current:
			style.border_color = color
			style.set_border_width_all(2)
		_cards[i].add_theme_stylebox_override("panel", style)
