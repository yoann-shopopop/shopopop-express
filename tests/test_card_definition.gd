extends GutTest
## Tests for CardDefinition — a card's placeholder identity (id, name, front image).


func test_default_identity_is_empty() -> void:
	var c := CardDefinition.new()
	assert_eq(c.id, &"")
	assert_eq(c.display_name, "")
	assert_null(c.front_texture)


func test_holds_identity() -> void:
	var c := CardDefinition.new()
	c.id = &"card_event_42"
	c.display_name = "Carte test"
	var tex := PlaceholderTexture2D.new()
	c.front_texture = tex
	assert_eq(c.id, &"card_event_42")
	assert_eq(c.display_name, "Carte test")
	assert_eq(c.front_texture, tex)
