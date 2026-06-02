class_name PlacementUI
extends CanvasLayer
## Setup-phase UI: a start screen to pick the player count, then a bar showing whose turn it is, the
## current player's remaining pieces (selectable), and a rotate button. Lives in a CanvasLayer so it
## stays the home of the future game UI (cards, dice, scores). Emits intents; the controller acts.

signal player_count_chosen(count: int)
signal piece_drag_started(index: int)
signal rotate_requested

const BUTTON_MIN := Vector2(118, 52)

const PREVIEW_SIZE := Vector2(104, 104)

var _start_panel: Control
var _game_panel: Control
var _turn_label: Label
var _pieces_bar: HBoxContainer
var _status_label: Label
var _vp_host: Node  # offscreen holder for the preview SubViewports


func _ready() -> void:
	_vp_host = Node.new()
	add_child(_vp_host)
	_build_start_panel()
	_build_game_panel()
	_game_panel.hide()


# --- Start screen -----------------------------------------------------------

func _build_start_panel() -> void:
	_start_panel = CenterContainer.new()
	_start_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_start_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_start_panel.add_child(box)

	var title := Label.new()
	title.text = "Nombre de joueurs"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for n in [2, 3, 4]:
		var button := Button.new()
		button.text = str(n)
		button.custom_minimum_size = BUTTON_MIN
		button.pressed.connect(_on_count_pressed.bind(n))
		row.add_child(button)


func _on_count_pressed(count: int) -> void:
	player_count_chosen.emit(count)


## Switches from the start screen to the in-game bar.
func begin_game() -> void:
	_start_panel.hide()
	_game_panel.show()


# --- In-game bar ------------------------------------------------------------

func _build_game_panel() -> void:
	_game_panel = MarginContainer.new()
	_game_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_panel.add_theme_constant_override("margin_left", 16)
	_game_panel.add_theme_constant_override("margin_right", 16)
	_game_panel.add_theme_constant_override("margin_top", 16)
	_game_panel.add_theme_constant_override("margin_bottom", 16)
	add_child(_game_panel)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 24)
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_game_panel.add_child(_turn_label)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	_game_panel.add_child(bottom)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_status_label)

	_pieces_bar = HBoxContainer.new()
	_pieces_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_pieces_bar.add_theme_constant_override("separation", 10)
	bottom.add_child(_pieces_bar)


## Refreshes the bar for [param player]'s turn: colored label + a tile preview per remaining piece.
func set_current_player(player: Player) -> void:
	_turn_label.text = "Tour : %s" % PlayerColor.name_of(player.color)
	_turn_label.add_theme_color_override("font_color", PlayerColor.to_color(player.color))
	_status_label.text = "Choisis une tuile puis clique pour la poser (R = rotation)"

	for child in _pieces_bar.get_children():
		child.queue_free()
	for child in _vp_host.get_children():
		child.queue_free()

	for i in player.pieces.size():
		var button := TextureButton.new()
		button.texture_normal = TilePreview.build(player.pieces[i], _vp_host)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = PREVIEW_SIZE
		button.modulate = Color.WHITE
		button.button_down.connect(_on_piece_pressed.bind(i))  # press = start dragging the tile
		_pieces_bar.add_child(button)

	var rotate := Button.new()
	rotate.text = "⟳"
	rotate.custom_minimum_size = Vector2(52, 52)
	rotate.pressed.connect(func() -> void: rotate_requested.emit())
	_pieces_bar.add_child(rotate)


func set_finished() -> void:
	_turn_label.text = "Mise en place terminée"
	_turn_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.text = "Tous les blocs sont posés."
	for child in _pieces_bar.get_children():
		child.queue_free()


func _on_piece_pressed(index: int) -> void:
	for i in _pieces_bar.get_child_count():
		var child := _pieces_bar.get_child(i)
		if child is TextureButton:
			child.modulate = Color.WHITE if i == index else Color(0.55, 0.55, 0.55)
	piece_drag_started.emit(index)
