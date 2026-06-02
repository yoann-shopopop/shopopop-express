extends GutTest
## Tests for EnseigneDefinition — a pickup brand card's data.


func test_fields_are_assignable() -> void:
	var e := EnseigneDefinition.new()
	e.id = &"ikeo"
	e.display_name = "IKEO"
	e.color = Color.RED
	assert_eq(e.id, &"ikeo")
	assert_eq(e.display_name, "IKEO")
	assert_eq(e.color, Color.RED)
