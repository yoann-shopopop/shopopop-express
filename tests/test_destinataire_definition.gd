extends GutTest
## Tests for DestinataireDefinition — a recipient card's data.


func test_fields_are_assignable() -> void:
	var d := DestinataireDefinition.new()
	d.id = &"mamie_turbo"
	d.display_name = "Mamie Turbo"
	d.color = Color.BLUE
	d.manie = "Vous attend déjà sur le pas de la porte."
	assert_eq(d.id, &"mamie_turbo")
	assert_eq(d.display_name, "Mamie Turbo")
	assert_eq(d.color, Color.BLUE)
	assert_eq(d.manie, "Vous attend déjà sur le pas de la porte.")
