class_name PlacementUI
extends CanvasLayer
## Setup-phase UI: a start screen to pick the player count, then a bar showing whose turn it is and
## the current player's remaining pieces (draggable previews). Placing a block does not end the turn;
## a floating toolbar (rotate left / remove / rotate right) hovers over the piece just placed so it
## can be adjusted, and "Terminer" (enabled only once a block is placed) ends the turn. Lives in a
## CanvasLayer so it stays the home of the future game UI. Emits intents; the controller acts.

signal player_count_chosen(count: int)
signal piece_drag_started(index: int)
signal bridge_drag_started
signal finish_requested
signal rotate_requested            ## cycle the magnet's candidate orientation while dragging
signal rotate_left_requested       ## floating toolbar: rotate the placed piece counter-clockwise
signal rotate_right_requested      ## floating toolbar: rotate the placed piece clockwise
signal remove_requested            ## floating toolbar: take the placed piece back to the tray

const BUTTON_MIN := Vector2(118, 52)
const PREVIEW_SIZE := Vector2(104, 104)
const CONTROL_BTN := Vector2(56, 56)

## 1-based placement-turn number for the header's "Tour X/Y". [param total] is the player's initial
## tile count, [param remaining] the tiles still in their tray, [param block_placed] whether this
## turn's block is already down. When no block is placed yet we add 1 so the counter reads the
## current turn (not the next), since placing a block removes it from [param remaining]. Clamped
## to >= 1. Pure — no state, unit-tested.
static func compute_turn_index(total: int, remaining: int, block_placed: bool) -> int:
	var index := total - remaining + (0 if block_placed else 1)
	return maxi(index, 1)


var _start_panel: Control
var _game_panel: Control
var _turn_label: Label
var _pieces_bar: HBoxContainer
var _status_label: Label
var _finish_button: Button
var _controls: HBoxContainer       # floating, world-anchored toolbar for the active piece
var _vp_host: Node                 # offscreen holder for the preview SubViewports


func _ready() -> void:
	_vp_host = Node.new()
	add_child(_vp_host)
	_build_start_panel()
	_build_game_panel()
	_build_controls()
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
	for n in [2, 3, 4, 5, 6]:
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
	_game_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let board presses through empty areas
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


# Floating toolbar shown above the piece just placed: rotate left, remove, rotate right (in order).
func _build_controls() -> void:
	_controls = HBoxContainer.new()
	_controls.add_theme_constant_override("separation", 10)
	_controls.top_level = true
	_controls.hide()
	add_child(_controls)

	_controls.add_child(_make_control_button("⟲", UITheme.ORANGE, func() -> void: rotate_left_requested.emit()))
	_controls.add_child(_make_control_button("✕", UITheme.RED, func() -> void: remove_requested.emit()))
	_controls.add_child(_make_control_button("⟳", UITheme.BLUE, func() -> void: rotate_right_requested.emit()))


# A single round-ish accent button for the floating toolbar.
func _make_control_button(glyph: String, accent: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = CONTROL_BTN
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.add_theme_stylebox_override("normal", UITheme.button_style(accent))
	b.add_theme_stylebox_override("hover", UITheme.button_style(accent, 1.6))
	b.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(accent))
	b.add_theme_stylebox_override("focus", UITheme.button_style(accent))
	b.pressed.connect(on_press)
	return b


## Refreshes the bar for [param player]'s turn. While [param block_placed] is true the tray blocks are
## locked (one block per turn) and "Terminer" is enabled; otherwise the reverse.
func set_current_player(player: Player, block_placed: bool) -> void:
	_turn_label.text = "Tour : %s" % PlayerColor.name_of(player.color)
	_turn_label.add_theme_color_override("font_color", PlayerColor.to_color(player.color))
	_status_label.text = "Pose une tuile, ajuste-la (boutons au-dessus), puis Terminer." if block_placed \
		else "Choisis une tuile et glisse-la sur le plateau pour la poser."

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
		button.disabled = block_placed  # only one block may be placed per turn
		button.modulate = Color(0.45, 0.45, 0.45) if block_placed else Color.WHITE
		button.button_down.connect(_on_piece_pressed.bind(i))
		_pieces_bar.add_child(button)

	# The free bridge, if still held — draggable any time during the turn.
	if player.bridge != null:
		var bridge_btn := TextureButton.new()
		bridge_btn.texture_normal = TilePreview.build(player.bridge, _vp_host)
		bridge_btn.ignore_texture_size = true
		bridge_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		bridge_btn.custom_minimum_size = PREVIEW_SIZE
		bridge_btn.modulate = Color(0.8, 0.95, 1.0)
		bridge_btn.button_down.connect(func() -> void: bridge_drag_started.emit())
		_pieces_bar.add_child(bridge_btn)

	var rotate := Button.new()
	rotate.text = "⟳"
	rotate.custom_minimum_size = Vector2(52, 52)
	rotate.pressed.connect(func() -> void: rotate_requested.emit())
	_pieces_bar.add_child(rotate)

	_finish_button = Button.new()
	_finish_button.text = "Terminer"
	_finish_button.custom_minimum_size = Vector2(110, 52)
	_finish_button.disabled = not block_placed
	_finish_button.pressed.connect(func() -> void: finish_requested.emit())
	_pieces_bar.add_child(_finish_button)


## Positions (and shows/hides) the floating toolbar over the active piece.
func update_controls(shown: bool, screen_pos: Vector2) -> void:
	_controls.visible = shown
	if shown:
		_controls.position = screen_pos - _controls.size * 0.5


func set_finished() -> void:
	_turn_label.text = "Mise en place terminée"
	_turn_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.text = "Tous les blocs sont posés."
	_controls.hide()
	for child in _pieces_bar.get_children():
		child.queue_free()


func _on_piece_pressed(index: int) -> void:
	for i in _pieces_bar.get_child_count():
		var child := _pieces_bar.get_child(i)
		if child is TextureButton:
			child.modulate = Color.WHITE if i == index else Color(0.55, 0.55, 0.55)
	piece_drag_started.emit(index)
