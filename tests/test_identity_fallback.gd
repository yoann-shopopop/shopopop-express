extends GutTest
## Tests for IdentityFallback — the shared "couleur + nom" placeholder used by both PawnView's 3D
## board tokens and DeliveryPanel's 2D cards for any enseigne/destinataire without illustrator art.


func test_color_is_deterministic_and_differs_across_names() -> void:
	var a1 := IdentityFallback.color("Croquettes & Cie", Color.WHITE)
	var a2 := IdentityFallback.color("Croquettes & Cie", Color.WHITE)
	var b := IdentityFallback.color("Fanfan Fleurs", Color.WHITE)
	assert_eq(a1, a2, "the same name always gets the same color")
	assert_ne(a1, b, "different names get different colors (very likely, hash-based)")


func test_color_of_an_empty_name_is_the_fallback() -> void:
	assert_eq(IdentityFallback.color("", Color.RED), Color.RED)


func test_initials_skips_short_french_articles() -> void:
	assert_eq(IdentityFallback.initials("Le Fournil d'Hector"), "FD")
	assert_eq(IdentityFallback.initials("Au P'tit Marché"), "PM")


func test_initials_falls_back_to_raw_words_when_everything_is_a_filler() -> void:
	assert_eq(IdentityFallback.initials("Le La"), "LL")


func test_initials_of_empty_name_is_empty() -> void:
	assert_eq(IdentityFallback.initials(""), "")


func test_initials_of_a_single_word_name() -> void:
	assert_eq(IdentityFallback.initials("Croquettes"), "C")
