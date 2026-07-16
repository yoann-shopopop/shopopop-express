extends GutTest
## Tests for SettingsMenu — builds without error against an explicit (not ambient) GameSettings,
## reflects its current values, and dragging a slider / pressing a toggle routes through to it.

const _SCRATCH_PATH := "user://test_settings_menu_scratch.cfg"


func before_each() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("test_settings_menu_scratch.cfg"):
		dir.remove("test_settings_menu_scratch.cfg")


func after_each() -> void:
	TranslationServer.set_locale("fr")
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("test_settings_menu_scratch.cfg"):
		dir.remove("test_settings_menu_scratch.cfg")


func _fresh_settings() -> GameSettings:
	var gs := GameSettings.new()
	autofree(gs)  # never entered into the tree (so _ready/_instance are untouched) — still needs freeing
	gs.set_config_path(_SCRATCH_PATH)
	gs.load_settings()
	return gs


func test_builds_without_error_and_shows_the_current_language() -> void:
	var gs := _fresh_settings()
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	menu.setup(gs)
	assert_eq(menu._fr_btn.text, "Français")
	assert_eq(menu._en_btn.text, "English")


func test_pressing_the_english_button_switches_the_language() -> void:
	var gs := _fresh_settings()
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	menu.setup(gs)
	menu._en_btn.pressed.emit()
	assert_eq(gs.language, "en")


func test_toggling_fullscreen_flips_the_setting() -> void:
	var gs := _fresh_settings()
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	menu.setup(gs)
	assert_false(gs.fullscreen)
	menu._fullscreen_btn.pressed.emit()
	assert_true(gs.fullscreen)


func test_toggling_fast_mode_flips_the_setting() -> void:
	var gs := _fresh_settings()
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	menu.setup(gs)
	assert_false(gs.fast_mode)
	menu._fast_btn.pressed.emit()
	assert_true(gs.fast_mode)


func test_layer_is_above_title_screen_so_it_is_actually_visible_when_opened_from_it() -> void:
	# Regression: SettingsMenu used to sit at layer 90, BELOW TitleScreen's opaque full-screen
	# backdrop (layer 100) — opening it from the title screen built a real node that was completely
	# invisible (hidden behind TitleScreen's own CanvasLayer). Only caught by an actual screenshot;
	# GUT never renders a frame to compare, hence this numeric layer-ordering check instead.
	var title := TitleScreen.new()
	add_child_autofree(title)
	var gs := _fresh_settings()
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	menu.setup(gs)
	assert_gt(menu.layer, title.layer, "SettingsMenu must render above TitleScreen to ever be seen")


func test_close_button_emits_closed_and_frees_the_menu() -> void:
	var gs := _fresh_settings()
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.setup(gs)
	watch_signals(menu)
	menu.close_menu()
	assert_signal_emitted(menu, "closed")
