extends GutTest
## Tests for DestinataireDefinition — a recipient card's data.


func test_fields_are_assignable() -> void:
	var d := DestinataireDefinition.new()
	d.id = &"keiona"
	d.display_name = "Keiona"
	d.color = Color.BLUE
	assert_eq(d.id, &"keiona")
	assert_eq(d.display_name, "Keiona")
	assert_eq(d.color, Color.BLUE)
