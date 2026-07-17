class_name HandoffScreen
extends CanvasLayer
## Hot-seat "pass the device" buffer screen (task #29): shown full-screen between two DIFFERENT
## human players' turns so the incoming player doesn't see the outgoing player's lingering board
## state before they're ready, and the outgoing player gets a clean beat to hand the device over.
## [GameRoot] only spawns this for an actual seat change between two humans — never for a solo
## session, an incoming AI seat, or a REJOUER replay of the same player. Dismissed by a tap/click
## anywhere or Enter/Space (ui_accept); frees itself.

signal continued

var _continued := false


## Builds the screen naming [param player] (the incoming seat) by color.
func setup(player: Player) -> void:
	layer = 95  # above PlayHud, below nothing else expected to be open at a turn boundary
	var color := PlayerColor.to_color(player.color)

	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("141a26")  # opaque: fully hides the board/HUD underneath during the handoff
	backdrop.add_theme_stylebox_override("panel", bg)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_continue())
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	var title := Label.new()
	title.text = tr("Passe l'appareil à")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.make_title(title, 22, UITheme.TEXT.darkened(0.15))
	box.add_child(title)

	var name_label := Label.new()
	name_label.text = PlayerColor.name_of(player.color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.make_title(name_label, 48, color)
	box.add_child(name_label)

	var continue_btn := Button.new()
	continue_btn.text = tr("C'est parti")
	continue_btn.custom_minimum_size = Vector2(240, 64)
	continue_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.add_theme_font_size_override("font_size", 22)
	continue_btn.add_theme_stylebox_override("normal", UITheme.button_style(color))
	continue_btn.add_theme_stylebox_override("hover", UITheme.button_style(color, 1.6))
	continue_btn.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(color))
	continue_btn.add_theme_color_override("font_color", UITheme.TEXT)
	continue_btn.pressed.connect(func() -> void: _continue())
	box.add_child(continue_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_continue()
		get_viewport().set_input_as_handled()


func _continue() -> void:
	if _continued:
		return  # a click and the Enter key on the same frame must not double-fire
	_continued = true
	AudioManager.sfx(&"ui_click")
	continued.emit()
	queue_free()
