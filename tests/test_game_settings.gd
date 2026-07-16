extends GutTest
## Tests for GameSettings — load/save round-trip, defaults, live application (audio buses, locale) and
## the settings_changed signal. Every test points at a scratch config path (never the real
## user://settings.cfg) and adds the instance to the tree via add_child_autofree only when a specific
## test needs _ready()'s auto-load/apply; most call load_settings/apply_all directly instead, which
## works without ever entering the tree — so GameSettings.current() (only set from _ready) is never
## touched here and stays whatever a real Main-driven session left it at.

const _SCRATCH_PATH := "user://test_settings_scratch.cfg"


func before_each() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("test_settings_scratch.cfg"):
		dir.remove("test_settings_scratch.cfg")


func after_each() -> void:
	TranslationServer.set_locale("fr")  # never leak a locale change into another test
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("test_settings_scratch.cfg"):
		dir.remove("test_settings_scratch.cfg")


func _fresh() -> GameSettings:
	var gs := GameSettings.new()
	autofree(gs)  # never entered into the tree (so _ready/_instance are untouched) — still needs freeing
	gs.set_config_path(_SCRATCH_PATH)
	return gs


func test_defaults_before_any_save() -> void:
	var gs := _fresh()
	gs.load_settings()  # no file yet: keeps the built-in defaults
	assert_eq(gs.music_volume, 1.0)
	assert_eq(gs.sfx_volume, 1.0)
	assert_false(gs.fullscreen)
	assert_eq(gs.language, "fr")
	assert_false(gs.fast_mode)


func test_setters_persist_across_a_fresh_load() -> void:
	var gs := _fresh()
	gs.set_music_volume(0.4)
	gs.set_sfx_volume(0.7)
	gs.set_fullscreen(true)
	gs.set_language("en")
	gs.set_fast_mode(true)

	var reloaded := _fresh()
	reloaded.load_settings()
	assert_almost_eq(reloaded.music_volume, 0.4, 0.001)
	assert_almost_eq(reloaded.sfx_volume, 0.7, 0.001)
	assert_true(reloaded.fullscreen)
	assert_eq(reloaded.language, "en")
	assert_true(reloaded.fast_mode)


func test_set_music_volume_clamps_to_the_valid_range() -> void:
	var gs := _fresh()
	gs.set_music_volume(1.5)
	assert_eq(gs.music_volume, 1.0)
	gs.set_music_volume(-0.5)
	assert_eq(gs.music_volume, 0.0)


func test_set_language_applies_the_locale_immediately() -> void:
	var gs := _fresh()
	gs.set_language("en")
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(tr("Jouer"), "Play")


func test_apply_all_sets_the_locale_from_loaded_settings() -> void:
	var writer := _fresh()
	writer.set_language("en")

	TranslationServer.set_locale("fr")  # simulate a fresh boot at the Localization default
	var gs := _fresh()
	gs.load_settings()
	gs.apply_all()
	assert_eq(TranslationServer.get_locale(), "en")


func test_setters_emit_settings_changed() -> void:
	var gs := _fresh()
	watch_signals(gs)
	gs.set_music_volume(0.3)
	assert_signal_emitted(gs, "settings_changed")


func test_current_is_null_until_a_real_instance_enters_the_tree() -> void:
	# GameSettings.current() only reflects Main's live instance (set in _ready) — a scratch instance
	# built and used purely via direct method calls (never add_child'd) must not clobber it.
	var gs := _fresh()
	gs.load_settings()
	gs.set_music_volume(0.2)
	assert_ne(GameSettings.current(), gs)


func test_pacing_scale_reflects_the_live_instances_fast_mode() -> void:
	var gs := GameSettings.new()
	gs.set_config_path(_SCRATCH_PATH)
	add_child_autofree(gs)  # _ready() fires: _instance = gs (scratch path, so no real file touched)
	assert_eq(GameSettings.pacing_scale(), 1.0, "fast_mode starts off")
	gs.set_fast_mode(true)
	assert_eq(GameSettings.pacing_scale(), GameSettings.FAST_PACING_SCALE)


func test_current_and_pacing_scale_stay_safe_after_the_instance_is_freed() -> void:
	# Guards the scene-reload hazard: get_tree().reload_current_scene() (Rejouer/Terminer) frees
	# Main's GameSettings without clearing the static _instance — current()/pacing_scale() must not
	# hand back (or dereference) a dangling reference in that window.
	var gs := GameSettings.new()
	gs.set_config_path(_SCRATCH_PATH)
	add_child(gs)  # not autofree: freed explicitly below, mid-test
	gs.set_fast_mode(true)
	gs.free()
	assert_null(GameSettings.current(), "a freed instance must not be returned as live")
	assert_eq(GameSettings.pacing_scale(), 1.0, "falls back to normal pace once the instance is gone")
