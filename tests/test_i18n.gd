extends GutTest
## Tests for the i18n plumbing (task #25): the French default survives even when an "en" translation
## table is loaded (the locale/fallback trap — see CLAUDE.md), locale switches take effect immediately,
## and the two static-context lookups (PlayerColor, DeliveryStatus — no Object instance for plain tr())
## translate correctly via TranslationServer.translate.


func after_each() -> void:
	TranslationServer.set_locale("fr")  # never leak a locale change into the next test


func test_default_locale_is_french() -> void:
	# Locked in by the Localization autoload (src/localization.gd) — without it, TranslationServer
	# would follow the host OS locale, and an EN-locale machine would boot the game in English.
	assert_eq(TranslationServer.get_locale(), "fr")


func test_french_stays_untranslated_even_though_only_english_is_registered() -> void:
	# The real bug this guards: Godot's internationalization/locale/fallback project setting defaults
	# to "en" — with only an "en" translation table loaded and no explicit fallback override, every
	# tr() call would silently return English even under the French locale, since French has no table
	# of its own and the (English) fallback would be used unconditionally.
	assert_eq(tr("Jouer"), "Jouer")


func test_switching_to_english_translates_a_known_key() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr("Jouer"), "Play")
	assert_eq(tr("Manche %d") % 3, "Round 3")


func test_switching_back_to_french_restores_the_original_text() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr("Jouer"), "Play")
	TranslationServer.set_locale("fr")
	assert_eq(tr("Jouer"), "Jouer")


func test_player_color_name_translates_via_static_lookup() -> void:
	assert_eq(PlayerColor.name_of(PlayerColor.Kind.BLUE), "Bleu")
	TranslationServer.set_locale("en")
	assert_eq(PlayerColor.name_of(PlayerColor.Kind.BLUE), "Blue")


func test_delivery_status_label_translates_via_static_lookup() -> void:
	assert_eq(DeliveryStatus.label(DeliveryStatus.Kind.RESERVE), "Réservé")
	TranslationServer.set_locale("en")
	assert_eq(DeliveryStatus.label(DeliveryStatus.Kind.RESERVE), "Reserved")


func test_tournee_tier_translates_via_static_lookup() -> void:
	assert_eq(TourneeSession.tier_for(300), "Or")
	TranslationServer.set_locale("en")
	assert_eq(TourneeSession.tier_for(300), "Gold")
