extends GutTest
## Tests for PawnDefinition — pawn identity data (name, image, type). No state, no rendering.


func _def(type: PawnDefinition.PawnType) -> PawnDefinition:
	var d := PawnDefinition.new()
	d.type = type
	return d


func test_default_type_is_cotransporter() -> void:
	assert_eq(PawnDefinition.new().type, PawnDefinition.PawnType.COTRANSPORTER)


func test_cotransporter_is_mobile() -> void:
	assert_true(_def(PawnDefinition.PawnType.COTRANSPORTER).is_mobile())


func test_drive_is_not_mobile() -> void:
	assert_false(_def(PawnDefinition.PawnType.DRIVE).is_mobile())


func test_recipient_is_not_mobile() -> void:
	assert_false(_def(PawnDefinition.PawnType.RECIPIENT).is_mobile())


func test_definition_holds_identity() -> void:
	var d := PawnDefinition.new()
	d.id = &"cotransporter_axelle"
	d.display_name = "Axel·le"
	var tex := PlaceholderTexture2D.new()
	d.texture = tex
	assert_eq(d.id, &"cotransporter_axelle")
	assert_eq(d.display_name, "Axel·le")
	assert_eq(d.texture, tex)
