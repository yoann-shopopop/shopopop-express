extends Node
## Autoload: pins the game's default language to French regardless of the host OS locale — without
## this, [method TranslationServer.get_locale] follows the OS locale, so an EN-locale machine would
## silently boot the game in English the moment an "en" translation file exists. Runs before any
## scene (including headless tools and GUT tests), so it is the single source of truth for the
## active language until task #26 (menu réglages) wires a persisted per-player choice on top.

func _init() -> void:
	TranslationServer.set_locale("fr")
