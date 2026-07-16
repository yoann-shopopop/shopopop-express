class_name TitleScreen
extends CanvasLayer
## Opening title screen: the game logo on the dark backdrop with "Jouer", "La Tournée", "Tutoriel" and
## "⚙ Réglages" buttons. Drawn above everything; pressing "Jouer" emits [signal start_requested] and
## frees itself, revealing the player-count chooser underneath. "La Tournée" emits
## [signal tournee_requested] for the solo score-attack mode (its own auto-built board, no placement
## phase). "Tutoriel" emits [signal tutorial_requested] for the guided first-time session. "⚙ Réglages"
## opens [SettingsMenu] directly (no signal — self-contained). Espace/Entrée (task #30) triggers
## "Jouer" — the default action for a screen with no other input focus yet. Pure UI — Main wires the
## first three signals.

signal start_requested
signal tutorial_requested
signal tournee_requested

const _LOGO := "res://assets/logo/logo_shopopop_express.png"


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
	play.text = tr("Jouer")
	play.custom_minimum_size = Vector2(280, 76)
	play.add_theme_font_size_override("font_size", 32)
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BLUE))
	play.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.BLUE, 1.6))
	play.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.BLUE))
	play.add_theme_color_override("font_color", UITheme.TEXT)
	play.pressed.connect(_start)
	box.add_child(play)

	var tournee := Button.new()
	tournee.text = tr("La Tournée (solo)")
	tournee.custom_minimum_size = Vector2(280, 52)
	tournee.focus_mode = Control.FOCUS_NONE
	tournee.add_theme_font_size_override("font_size", 22)
	tournee.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.GREEN))
	tournee.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.GREEN, 1.6))
	tournee.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.GREEN))
	tournee.add_theme_color_override("font_color", UITheme.TEXT)
	tournee.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		tournee_requested.emit())
	box.add_child(tournee)

	var tutorial := Button.new()
	tutorial.text = tr("Tutoriel")
	tutorial.custom_minimum_size = Vector2(280, 52)
	tutorial.focus_mode = Control.FOCUS_NONE
	tutorial.add_theme_font_size_override("font_size", 22)
	tutorial.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.ORANGE))
	tutorial.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.ORANGE, 1.6))
	tutorial.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.ORANGE))
	tutorial.add_theme_color_override("font_color", UITheme.TEXT)
	tutorial.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		tutorial_requested.emit())
	box.add_child(tutorial)

	var settings := Button.new()
	settings.text = tr("⚙ Réglages")
	settings.custom_minimum_size = Vector2(280, 52)
	settings.focus_mode = Control.FOCUS_NONE
	settings.add_theme_font_size_override("font_size", 22)
	settings.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.PANEL_BORDER))
	settings.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.PANEL_BORDER, 1.6))
	settings.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.PANEL_BORDER))
	settings.add_theme_color_override("font_color", UITheme.TEXT)
	settings.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		var menu := SettingsMenu.new()
		add_child(menu)
		menu.setup(GameSettings.current()))
	box.add_child(settings)


func _start() -> void:
	AudioManager.sfx(&"ui_click")
	start_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start()
		get_viewport().set_input_as_handled()
