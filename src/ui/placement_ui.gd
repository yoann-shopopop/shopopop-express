class_name PlacementUI
extends CanvasLayer
## Minimal on-screen controls for the placement demo: pick a block, rotate it.
##
## Built in a CanvasLayer so it overlays the 3D board and stays the natural home for the
## future game UI (cards, dice, turn info). Emits intents; the controller does the work.

signal block_chosen(id: StringName)
signal rotate_requested

const BUTTON_MIN_SIZE := Vector2(120, 56)

var _buttons: Dictionary = {}  # StringName id -> Button


## [param blocks] is an ordered list of { "id": StringName, "label": String }.
func build(blocks: Array) -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	# Bottom action bar — thumb-reachable on mobile.
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(bar)

	for block in blocks:
		var id: StringName = block["id"]
		var button := Button.new()
		button.text = block["label"]
		button.toggle_mode = true
		button.custom_minimum_size = BUTTON_MIN_SIZE
		button.pressed.connect(_on_block_pressed.bind(id))
		bar.add_child(button)
		_buttons[id] = button

	var rotate := Button.new()
	rotate.text = "⟳ Rotation"
	rotate.custom_minimum_size = BUTTON_MIN_SIZE
	rotate.pressed.connect(func() -> void: rotate_requested.emit())
	bar.add_child(rotate)


## Visually marks [param id] as the active block.
func set_active_block(id: StringName) -> void:
	for key in _buttons:
		(_buttons[key] as Button).button_pressed = (key == id)


func _on_block_pressed(id: StringName) -> void:
	set_active_block(id)
	block_chosen.emit(id)
