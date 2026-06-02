extends GutTest
## Smoke test for EventCardChoice: presenting two cards builds two readable CardViews without error.


func _card(name: String) -> EventCardDefinition:
	var c := EventCardDefinition.new()
	c.id = StringName(name)
	c.display_name = name
	return c


func test_present_builds_two_card_views() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var choice := EventCardChoice.new()
	add_child_autofree(choice)
	choice.present([_card("Grand Soleil"), _card("Feu Rouge")], camera, Vector3.ZERO)

	var cards := 0
	for child in choice.get_children():
		if child is CardView:
			cards += 1
	assert_eq(cards, 2, "two cards dealt")
