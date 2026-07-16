class_name TutorialOverlay
extends CanvasLayer
## The tutorial's speech bubble: a compact panel anchored bottom-center, above the action buttons,
## showing at most a couple of short lines per beat. Auto-advancing beats just replace the text;
## the final beat additionally shows a "Terminer" button. Pure UI — [TutorialDirector] drives it.

signal finished_pressed

var _panel: PanelContainer
var _label: Label
var _finish_btn: Button


func _ready() -> void:
	layer = 55  # above the play HUD, below modals (choosers sit even higher via their own CanvasLayer)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -170
	_panel.offset_bottom = -100
	_panel.add_theme_stylebox_override("panel", UITheme.panel_card(Color("1c2230")))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_title(_label, 20)
	box.add_child(_label)

	_finish_btn = Button.new()
	_finish_btn.text = tr("Terminer")
	_finish_btn.custom_minimum_size = Vector2(180, 48)
	_finish_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_finish_btn.add_theme_font_size_override("font_size", 18)
	_finish_btn.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.GREEN))
	_finish_btn.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.GREEN, 1.6))
	_finish_btn.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.GREEN))
	_finish_btn.add_theme_color_override("font_color", UITheme.TEXT)
	_finish_btn.pressed.connect(func() -> void:
		AudioManager.sfx(&"ui_click")
		finished_pressed.emit())
	_finish_btn.hide()
	box.add_child(_finish_btn)


## Shows [param text] as the current beat's bubble (replaces any previous text).
func say(text: String) -> void:
	_label.text = text


## Shows the "Terminer" button (the tutorial's last beat).
func show_finish_button() -> void:
	_finish_btn.show()
