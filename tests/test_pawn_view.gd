extends GutTest
## Light test for PawnView — verifies it positions itself at the pawn's cell. No pixel assertions.


func _pawn() -> Pawn:
	var d := PawnDefinition.new()
	d.type = PawnDefinition.PawnType.COTRANSPORTER
	return Pawn.new(d)


func _expected_for(cell: Vector2i) -> Vector3:
	return HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE) \
		+ Vector3(0.0, GameConfig.TILE_HEIGHT * 0.5 + PawnView.SPRITE_LIFT, 0.0)


func test_view_sits_at_placed_cell_world_position() -> void:
	var view := PawnView.new()
	add_child_autofree(view)
	var pawn := _pawn()
	view.bind(pawn)
	var cell := Vector2i(2, -1)
	pawn.place(cell)
	assert_eq(view.position, _expected_for(cell))


func test_view_follows_move() -> void:
	var view := PawnView.new()
	add_child_autofree(view)
	var pawn := _pawn()
	view.bind(pawn)
	pawn.place(Vector2i(0, 0))
	pawn.move_to(Vector2i(3, -2))
	assert_eq(view.position, _expected_for(Vector2i(3, -2)))
