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
const HEX_PER_TILE := 19  # cells in one district tile (drives the "19 Hex" label)
const BRIDGE_TINT := Color("8fd0ec")  # tray-card accent for the free bridge
const TEAM_NAMES := {
	PlayerColor.Kind.BLUE: "Équipe Bleue",
	PlayerColor.Kind.RED: "Équipe Rouge",
	PlayerColor.Kind.PURPLE: "Équipe Violette",
	PlayerColor.Kind.YELLOW: "Équipe Jaune",
}

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
var _header_label: Label          # "PHASE DE PLACEMENT | Équipe ... · Tour X/Y"
var _subline_label: Label         # "J1 : Équipe ..."
var _hex_label: Label             # "19 Hex"
var _tray_rotate: Button          # cycles magnet orientation; only visible while dragging
var _validate_button: Button      # "VALIDER LE PLACEMENT" (was _finish_button)
var _pieces_bar: HBoxContainer
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

	# --- Top-center header: pill + player sub-line -------------------------
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_theme_constant_override("separation", 6)
	_game_panel.add_child(top)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.pill_style())
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(pill)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", UITheme.TEXT)
	pill.add_child(_header_label)

	_subline_label = Label.new()
	_subline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subline_label.add_theme_font_size_override("font_size", 15)
	top.add_child(_subline_label)

	# --- Bottom: 19 Hex + tray + Valider -----------------------------------
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 6)
	_game_panel.add_child(bottom)

	_hex_label = Label.new()
	_hex_label.text = "%d Hex" % HEX_PER_TILE
	_hex_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hex_label.add_theme_color_override("font_color", UITheme.TEXT)
	bottom.add_child(_hex_label)

	# A row that holds (left spacer) | centered tray | right-aligned Valider.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_spacer)

	_pieces_bar = HBoxContainer.new()
	_pieces_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_pieces_bar.add_theme_constant_override("separation", 10)
	row.add_child(_pieces_bar)

	# Drag-time rotate (cycles magnet orientation) — hidden unless dragging.
	_tray_rotate = Button.new()
	_tray_rotate.text = "⟳"
	_tray_rotate.custom_minimum_size = Vector2(52, 52)
	_tray_rotate.add_theme_font_size_override("font_size", 20)
	_tray_rotate.add_theme_color_override("font_color", UITheme.TEXT)
	_tray_rotate.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.PANEL_DARK))
	_tray_rotate.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.PANEL_DARK, 1.6))
	_tray_rotate.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.PANEL_DARK))
	_tray_rotate.hide()
	_tray_rotate.pressed.connect(func() -> void: rotate_requested.emit())
	row.add_child(_tray_rotate)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)

	_validate_button = Button.new()
	_validate_button.text = "VALIDER\nLE PLACEMENT"
	_validate_button.custom_minimum_size = Vector2(150, 64)
	_validate_button.add_theme_font_size_override("font_size", 15)
	_validate_button.add_theme_color_override("font_color", UITheme.TEXT)
	_validate_button.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BLUE))
	_validate_button.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.BLUE, 1.6))
	_validate_button.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.BLUE))
	_validate_button.add_theme_stylebox_override("disabled", UITheme.button_style_pressed(UITheme.PANEL_BORDER))
	_validate_button.pressed.connect(func() -> void: finish_requested.emit())
	right.add_child(_validate_button)


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
## locked (one block per turn) and "Valider" is enabled; otherwise the reverse. [param turn_index] /
## [param turn_total] feed the header's "Tour X/Y" (display only; default 0 hides it).
func set_current_player(player: Player, block_placed: bool, turn_index: int = 0, turn_total: int = 0) -> void:
	var team: String = TEAM_NAMES.get(player.color, PlayerColor.name_of(player.color))
	var team_color := PlayerColor.to_color(player.color)
	var turn_suffix := ""
	if turn_total > 0:
		turn_suffix = " · Tour %d/%d" % [turn_index, turn_total]
	_header_label.text = "PHASE DE PLACEMENT  |  %s%s" % [team, turn_suffix]
	_subline_label.text = "J%d : %s" % [player.index + 1, team]
	_subline_label.add_theme_color_override("font_color", team_color)

	for child in _pieces_bar.get_children():
		child.queue_free()
	for child in _vp_host.get_children():
		child.queue_free()

	for i in player.pieces.size():
		_pieces_bar.add_child(_make_tray_card(
			TilePreview.build(player.pieces[i], _vp_host),
			"Block %d" % (i + 1), team_color, false, block_placed,
			_on_piece_pressed.bind(i)))

	# The free bridge, if still held — draggable any time during the turn.
	if player.bridge != null:
		_pieces_bar.add_child(_make_tray_card(
			TilePreview.build(player.bridge, _vp_host),
			"Pont", BRIDGE_TINT, false, false,
			func() -> void: bridge_drag_started.emit()))

	_validate_button.disabled = not block_placed


# Builds one labeled tray card: a textured tile button over a small caption, in a styled frame.
func _make_tray_card(tex: Texture2D, caption: String, accent: Color, selected: bool, disabled: bool, on_down: Callable) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.tray_card_style(accent, selected))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)

	var button := TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = PREVIEW_SIZE
	button.disabled = disabled
	button.modulate = Color(0.45, 0.45, 0.45) if disabled else Color.WHITE
	button.button_down.connect(on_down)
	box.add_child(button)
	frame.set_meta("tex_button", button)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 12)
	caption_label.add_theme_color_override("font_color", UITheme.TEXT)
	box.add_child(caption_label)

	return frame


## Positions (and shows/hides) the floating toolbar over the active piece.
func update_controls(shown: bool, screen_pos: Vector2) -> void:
	_controls.visible = shown
	if shown:
		_controls.position = screen_pos - _controls.size * 0.5


## Shows/hides the drag-time magnet-rotate button (visible only while a piece is being dragged).
func set_dragging(dragging: bool) -> void:
	_tray_rotate.visible = dragging


func set_finished() -> void:
	_header_label.text = "MISE EN PLACE TERMINÉE"
	_subline_label.text = "Tous les blocs sont posés."
	_subline_label.add_theme_color_override("font_color", UITheme.TEXT)
	_controls.hide()
	_tray_rotate.hide()
	_validate_button.disabled = true
	for child in _pieces_bar.get_children():
		child.queue_free()


func _on_piece_pressed(index: int) -> void:
	# Brighten the pressed tile and dim the others (preserves the pre-redesign selection feedback;
	# the bridge card, added after the blocks, is dimmed like any non-selected tile).
	var i := 0
	for child in _pieces_bar.get_children():
		if child.has_meta("tex_button"):
			var tex_button: TextureButton = child.get_meta("tex_button")
			tex_button.modulate = Color.WHITE if i == index else Color(0.55, 0.55, 0.55)
			i += 1
	piece_drag_started.emit(index)
