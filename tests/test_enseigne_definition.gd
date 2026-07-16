extends GutTest
## Tests for EnseigneDefinition — a pickup brand card's data.


func test_fields_are_assignable() -> void:
	var e := EnseigneDefinition.new()
	e.id = &"visse_et_vrille"
	e.display_name = "Visse & Vrille"
	e.color = Color.RED
	assert_eq(e.id, &"visse_et_vrille")
	assert_eq(e.display_name, "Visse & Vrille")
	assert_eq(e.color, Color.RED)
