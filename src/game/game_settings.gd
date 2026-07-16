class_name GameSettings
extends Node
## Persisted player preferences (task #26) — music/SFX volume, fullscreen, language, and a "fast mode"
## pacing flag (consumed by task #27's animation speed-up, not yet by this task). NOT a Godot autoload
## — like [AudioManager], [Main] creates the one live instance at startup (after [Localization]'s "fr"
## default is already active), so headless tools/GUT tests never load a developer's real
## [member DEFAULT_PATH] and stay deterministic. [method current] exposes that instance for wiring
## [SettingsMenu] from [TitleScreen]/[PlayHud]; [SettingsMenu] itself takes an explicit reference
## (dependency injection, not an ambient global) so it stays independently testable.

signal settings_changed  # a live SettingsMenu instance refreshes if settings change elsewhere

const DEFAULT_PATH := "user://settings.cfg"
const MUSIC_BUS := "Musique"
const SFX_BUS := "Effets"

static var _instance: GameSettings

var music_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false
var language: String = "fr"
var fast_mode: bool = false

var _path: String = DEFAULT_PATH


## The live instance [Main] created at startup, or null before that (headless tools/tests that never
## instantiate one) — also guards against a stale reference surviving a scene reload
## ([code]get_tree().reload_current_scene()[/code] frees the old Main/GameSettings; [code]_instance[/code]
## would otherwise dangle non-null until the new one's [method _ready] runs).
static func current() -> GameSettings:
	return _instance if _instance != null and is_instance_valid(_instance) else null


const FAST_PACING_SCALE := 0.3  # a flat speed-up, not a fine-grained slider — kept minimal per the plan

## The multiplier every animated wait in the game (walk steps, AI turns, event reveals, banner/toast
## hold times — task #27) should apply to its base duration: [constant FAST_PACING_SCALE] while
## [member fast_mode] is on, [code]1.0[/code] (normal pace) otherwise. Static and null-safe so any
## file can call [code]GameSettings.pacing_scale()[/code] directly, the same way [AudioManager.sfx]
## no-ops before an instance exists — headless tools/tests always see normal pace.
static func pacing_scale() -> float:
	var gs := current()
	return FAST_PACING_SCALE if gs != null and gs.fast_mode else 1.0


func _ready() -> void:
	_instance = self
	load_settings()
	apply_all()


## Test seam: points this instance at a scratch config file instead of the real [member DEFAULT_PATH]
## — call before [method load_settings] (the real autoload never calls this).
func set_config_path(path: String) -> void:
	_path = path


## Reads the config file into this instance's fields (a missing file just keeps the defaults — first
## run). Does not touch the engine; call [method apply_all] separately.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	language = cfg.get_value("locale", "language", language)
	fast_mode = cfg.get_value("pacing", "fast_mode", fast_mode)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("locale", "language", language)
	cfg.set_value("pacing", "fast_mode", fast_mode)
	cfg.save(_path)


## Applies every current field to the live engine state. Idempotent; safe to call anytime.
func apply_all() -> void:
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_fullscreen()
	TranslationServer.set_locale(language)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_music_volume()
	save_settings()
	settings_changed.emit()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_sfx_volume()
	save_settings()
	settings_changed.emit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	save_settings()
	settings_changed.emit()


func set_language(code: String) -> void:
	language = code
	TranslationServer.set_locale(code)
	save_settings()
	settings_changed.emit()


func set_fast_mode(enabled: bool) -> void:
	fast_mode = enabled
	save_settings()
	settings_changed.emit()


func _apply_music_volume() -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))
		AudioServer.set_bus_mute(idx, music_volume <= 0.0001)


func _apply_sfx_volume() -> void:
	var idx := AudioServer.get_bus_index(SFX_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))
		AudioServer.set_bus_mute(idx, sfx_volume <= 0.0001)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
