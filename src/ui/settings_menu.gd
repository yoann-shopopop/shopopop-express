class_name SettingsMenu
extends CanvasLayer
## Minimal settings modal (task #26): music/SFX volume sliders, a fullscreen toggle, language buttons
## (FR/EN), and a fast-mode toggle (persisted here; its actual effect on animation pacing is task
## #27's job). Takes an explicit [GameSettings] reference via [method setup] — dependency injection,
## not an ambient global lookup, so this stays independently testable. Every control applies + saves
## immediately through [GameSettings]; there is no separate "Save" step to forget. A dimmed backdrop
## blocks board/HUD input underneath; "Fermer" (or Échap) dismisses and frees.

signal closed

var _settings: GameSettings
var _backdrop: ColorRect
var _fullscreen_btn: Button
var _fr_btn: Button
var _en_btn: Button
var _fast_btn: Button


## Builds the modal bound to [param settings] (the live instance — see [method GameSettings.current]).
func setup(settings: GameSettings) -> void:
	_settings = settings
	# Above EVERYTHING, including TitleScreen (100): opened from both TitleScreen and PlayHud, and
	# TitleScreen's own opaque backdrop would otherwise hide this entirely when layer <= 100 — a
	# real bug caught only by an actual screenshot (GUT never renders a frame to compare).
	layer = 110
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.55)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", UITheme.modal_style_textured())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("Réglages")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.make_title(title, 26, UITheme.ORANGE)
	box.add_child(title)

	box.add_child(_slider_row(tr("Musique"), _settings.music_volume, func(v: float) -> void:
		_settings.set_music_volume(v)))
	box.add_child(_slider_row(tr("Effets sonores"), _settings.sfx_volume, func(v: float) -> void:
		_settings.set_sfx_volume(v)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_fullscreen_btn = _toggle_button("", func() -> void:
		_settings.set_fullscreen(not _settings.fullscreen)
		_refresh_fullscreen_button())
	row.add_child(_fullscreen_btn)
	_refresh_fullscreen_button()

	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 10)
	box.add_child(lang_row)
	_fr_btn = _toggle_button("Français", func() -> void:
		_settings.set_language("fr")
		_refresh_language_buttons())
	lang_row.add_child(_fr_btn)
	_en_btn = _toggle_button("English", func() -> void:
		_settings.set_language("en")
		_refresh_language_buttons())
	lang_row.add_child(_en_btn)
	_refresh_language_buttons()

	var fast_row := HBoxContainer.new()
	fast_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(fast_row)
	_fast_btn = _toggle_button("", func() -> void:
		_settings.set_fast_mode(not _settings.fast_mode)
		_refresh_fast_button())
	fast_row.add_child(_fast_btn)
	_refresh_fast_button()

	var close := Button.new()
	close.text = tr("Fermer")
	close.custom_minimum_size = Vector2(160, 50)
	close.add_theme_font_size_override("font_size", 20)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_theme_button(close, UITheme.BLUE)
	close.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		close_menu())
	box.add_child(close)


func close_menu() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


# One labeled row: a title, a 0-100 slider starting at [param initial] (0.0-1.0), calling
# [param on_change] with the new 0.0-1.0 value whenever it's dragged.
func _slider_row(label_text: String, initial: float, on_change: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", UITheme.TEXT)
	col.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(340, 24)
	slider.value_changed.connect(func(v: float) -> void: on_change.call(v))
	col.add_child(slider)
	return col


func _toggle_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		on_press.call())
	return b


func _theme_button(btn: Button, base: Color) -> void:
	btn.add_theme_stylebox_override("normal", UITheme.button_style(base))
	btn.add_theme_stylebox_override("hover", UITheme.button_style(base, 1.6))
	btn.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(base))
	btn.add_theme_color_override("font_color", UITheme.TEXT)


func _refresh_fullscreen_button() -> void:
	var on := _settings.fullscreen
	_fullscreen_btn.text = tr("Plein écran : activé") if on else tr("Plein écran : désactivé")
	_theme_button(_fullscreen_btn, UITheme.GREEN if on else UITheme.PANEL_BORDER)


func _refresh_language_buttons() -> void:
	_theme_button(_fr_btn, UITheme.GREEN if _settings.language == "fr" else UITheme.PANEL_BORDER)
	_theme_button(_en_btn, UITheme.GREEN if _settings.language == "en" else UITheme.PANEL_BORDER)


func _refresh_fast_button() -> void:
	var on := _settings.fast_mode
	_fast_btn.text = tr("Rythme rapide : activé") if on else tr("Rythme rapide : désactivé")
	_theme_button(_fast_btn, UITheme.GREEN if on else UITheme.PANEL_BORDER)
