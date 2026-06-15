class_name CharacterSelect
extends CanvasLayer
## Seat-by-seat character draft (hotseat): each player, in turn order/colour, picks one of the eight
## characters from a grid that shows the portrait, transport (→ dice) and super-power. Picked
## characters grey out. A "Tout aléatoire" button fills the rest. Emits the ordered choices and frees
## itself. Pure UI — [Main] wires it between the player-count chooser and the placement phase.

signal characters_chosen(chosen: Array)

# power_id -> a short "Name · effect" line shown on the card.
const POWER_BLURB := {
	&"bonne_marcheuse": "Bonne Marcheuse · +2 cases",
	&"carnet_adresses": "Carnet d'Adresses · pioche 2",
	&"bouclier_vert": "Bouclier Vert · annule un malus",
	&"habitue_quartier": "Habitué·e · livraison au max",
	&"passage_secret": "Passage Secret · franchis l'eau",
	&"chargement_pro": "Chargement Pro · +1 livraison",
	&"depassement": "Dépassement · échange ta place",
	&"coup_accelerateur": "Coup d'Accélérateur · relance un dé",
}
const TRANSPORT_NAME := ["Vélo", "À pied", "Voiture", "Camion"]

var _characters: Array = []
var _count := 0
var _seat := 0
var _chosen: Array = []
var _used: Dictionary = {}        # character index -> true
var _rng := RandomNumberGenerator.new()
var _header: Label
var _grid: GridContainer


## Starts a draft for [param count] seats choosing from [param characters].
func setup(count: int, characters: Array) -> void:
	_count = count
	_characters = characters
	_rng.randomize()
	layer = 60

	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("141a26")
	backdrop.add_theme_stylebox_override("panel", bg)
	add_child(backdrop)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	backdrop.add_child(margin)
	margin.add_child(box)

	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_grid)

	var random_btn := Button.new()
	random_btn.text = "Tout aléatoire"
	random_btn.custom_minimum_size = Vector2(220, 52)
	random_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	random_btn.add_theme_font_size_override("font_size", 20)
	random_btn.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.ORANGE))
	random_btn.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.ORANGE, 1.6))
	random_btn.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.ORANGE))
	random_btn.add_theme_color_override("font_color", UITheme.TEXT)
	random_btn.pressed.connect(_fill_random)
	box.add_child(random_btn)

	_build_cards()
	_refresh_header()


func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for i in _characters.size():
		_grid.add_child(_card(i))


func _card(index: int) -> Control:
	var character: CharacterDefinition = _characters[index]
	var panel := PanelContainer.new()
	var used: bool = _used.has(index)
	panel.add_theme_stylebox_override("panel", UITheme.tray_card_style(UITheme.BLUE, false))
	panel.modulate = Color(0.4, 0.4, 0.45) if used else Color.WHITE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not used:
		panel.gui_input.connect(_on_card_input.bind(index))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(150, 196)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = character.texture
	portrait.clip_contents = true
	col.add_child(portrait)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.make_title(name_label, 18)
	name_label.text = character.display_name
	col.add_child(name_label)

	var transport := Label.new()
	transport.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transport.add_theme_font_size_override("font_size", 13)
	transport.add_theme_color_override("font_color", UITheme.ORANGE)
	var t: int = character.transport
	transport.text = "%s · %d dé%s" % [TRANSPORT_NAME[t], character.dice_count(), "s" if character.dice_count() > 1 else ""]
	col.add_child(transport)

	var power := Label.new()
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power.custom_minimum_size = Vector2(150, 0)
	power.add_theme_font_size_override("font_size", 12)
	power.add_theme_color_override("font_color", UITheme.TEXT)
	power.text = POWER_BLURB.get(character.power_id, "")
	col.add_child(power)

	return panel


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pick(index)


func _pick(index: int) -> void:
	if _used.has(index):
		return
	AudioManager.sfx(&"ui_click")
	_used[index] = true
	_chosen.append(_characters[index])
	_seat += 1
	if _seat >= _count:
		_finish()
		return
	_build_cards()
	_refresh_header()


func _fill_random() -> void:
	AudioManager.sfx(&"ui_click")
	var available: Array = []
	for i in _characters.size():
		if not _used.has(i):
			available.append(i)
	# Shuffle the remaining indices deterministically-enough and assign to the remaining seats.
	for i in range(available.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = available[i]
		available[i] = available[j]
		available[j] = tmp
	var k := 0
	while _seat < _count and k < available.size():
		_chosen.append(_characters[available[k]])
		k += 1
		_seat += 1
	_finish()


func _finish() -> void:
	characters_chosen.emit(_chosen)
	queue_free()


func _refresh_header() -> void:
	var colors := PlayerColor.all()
	var color: int = colors[_seat % colors.size()]
	UITheme.make_title(_header, 30, PlayerColor.to_color(color))
	_header.text = "Joueur %d — %s : choisis ton personnage" % [_seat + 1, PlayerColor.name_of(color)]
