class_name TitleScreen
extends CanvasLayer
## Opening title screen: the game logo on the dark backdrop with a single "Jouer" button. Drawn above
## everything; on press it emits [signal start_requested] and frees itself, revealing the player-count
## chooser underneath. Pure UI — Main wires it.

signal start_requested

const _LOGO := "res://assets/logo/LOGO-SHOPOPOP-EXPRESS.png"


func _ready() -> void:
	layer = 100  # above the placement UI / zoom controls

	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("141a26")  # opaque dark, matches the world backdrop
	backdrop.add_theme_stylebox_override("panel", bg)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 44)
	center.add_child(box)

	var logo := TextureRect.new()
	logo.texture = load(_LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(620, 508)  # keeps the 980×804 aspect
	box.add_child(logo)

	var play := Button.new()
	play.text = "Jouer"
	play.custom_minimum_size = Vector2(280, 76)
	play.add_theme_font_size_override("font_size", 32)
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BLUE))
	play.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.BLUE, 1.6))
	play.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.BLUE))
	play.add_theme_color_override("font_color", UITheme.TEXT)
	play.pressed.connect(func() -> void: start_requested.emit())
	box.add_child(play)
