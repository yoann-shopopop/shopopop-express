extends GutTest
## Tests for PlayerColor — the four district identities: color, name, and (colorblind accessibility)
## a distinct single-letter initial for each.


func test_all_returns_the_four_colors_in_turn_order() -> void:
	assert_eq(PlayerColor.all(), [
		PlayerColor.Kind.BLUE, PlayerColor.Kind.RED, PlayerColor.Kind.PURPLE, PlayerColor.Kind.YELLOW,
	])


func test_every_color_has_a_name() -> void:
	for kind in PlayerColor.all():
		assert_ne(PlayerColor.name_of(kind), "?")


func test_initials_are_distinct_for_every_color() -> void:
	var initials := {}
	for kind in PlayerColor.all():
		var letter := PlayerColor.initial_of(kind)
		assert_ne(letter, "?", "every real color has an initial")
		initials[letter] = true
	assert_eq(initials.size(), PlayerColor.all().size(), "four distinct initials")


func test_unknown_kind_falls_back_gracefully() -> void:
	assert_eq(PlayerColor.name_of(-1), "?")
	assert_eq(PlayerColor.initial_of(-1), "?")
	assert_eq(PlayerColor.to_color(-1), Color.WHITE)
