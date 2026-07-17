class_name ZoomControls
extends CanvasLayer
## Always-on +/- zoom buttons, anchored to the right edge and vertically centered so they clear the
## top labels and the bottom action bar. Phase-independent (lives across setup and game). Emits
## intents; main.gd wires them to the CameraRig. Trackpad pinch and mouse wheel still zoom directly.

signal zoom_in_requested
signal zoom_out_requested

const BUTTON_SIZE := Vector2(56, 56)
const EDGE_MARGIN := 16


func _ready() -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor.add_theme_constant_override("margin_right", EDGE_MARGIN)
	add_child(anchor)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	anchor.add_child(column)

	column.add_child(_make_button("+", zoom_in_requested))
	column.add_child(_make_button("−", zoom_out_requested))  # U+2212 minus sign


func _make_button(label: String, intent: Signal) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 28)
	button.focus_mode = Control.FOCUS_NONE  # don't steal keyboard focus from the board
	button.add_theme_stylebox_override("normal", UITheme.button_style_textured(UITheme.PackRole.NEUTRAL))
	button.add_theme_stylebox_override("hover", UITheme.button_style_textured(UITheme.PackRole.NEUTRAL))
	button.add_theme_stylebox_override("pressed", UITheme.button_style_textured(UITheme.PackRole.NEUTRAL, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void: intent.emit())
	return button
