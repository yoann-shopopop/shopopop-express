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
	# A step is animated (a short hop), so the view settles on the target after the tween, not instantly.
	await get_tree().create_timer(0.4).timeout
	assert_eq(view.position, _expected_for(Vector2i(3, -2)))


# Colorblind accessibility: each of the 4 player identities gets a distinct top-down silhouette
# (circle/square/diamond/ring), doubling the color. -1 (unset) must still fall back to a figure.
func test_every_shape_kind_builds_a_figure_without_error() -> void:
	var shapes := [-1, PlayerColor.Kind.BLUE, PlayerColor.Kind.RED, PlayerColor.Kind.PURPLE, PlayerColor.Kind.YELLOW]
	for shape in shapes:
		var d := PawnDefinition.new()
		d.type = PawnDefinition.PawnType.COTRANSPORTER
		d.shape_kind = shape
		var view := PawnView.new()
		add_child_autofree(view)
		view.bind(Pawn.new(d))
		assert_gt(view.get_child_count(), 0, "a figure (body + head) was built for shape_kind %d" % shape)


# --- Textureless drive/recipient token fallback (graphics pass, 2026-07-16) --------------

# Without art, every drive/recipient used to render as the exact same blank grey disc — now a
# colored chip + initials label so different identities read as different tokens on the board.
func _token(display_name: String, texture: Texture2D = null) -> PawnView:
	var d := PawnDefinition.new()
	d.type = PawnDefinition.PawnType.DRIVE
	d.display_name = display_name
	d.texture = texture
	var view := PawnView.new()
	add_child_autofree(view)
	view.bind(Pawn.new(d))
	return view


func test_textureless_token_shows_an_initials_label() -> void:
	var view := _token("Le Fournil d'Hector")
	var label: Label3D = null
	for child in view.get_children():
		if child is Label3D:
			label = child
	assert_not_null(label, "a fallback label was built")
	assert_eq(label.text, "FD", "skips the filler article \"Le\"")


func test_textured_token_has_no_fallback_label() -> void:
	var view := _token("Le Fournil d'Hector", PlaceholderTexture2D.new())
	for child in view.get_children():
		assert_false(child is Label3D, "real art means no fallback label is needed")


func test_identity_color_is_deterministic_and_differs_across_names() -> void:
	var a1 := PawnView._identity_color("Croquettes & Cie")
	var a2 := PawnView._identity_color("Croquettes & Cie")
	var b := PawnView._identity_color("Fanfan Fleurs")
	assert_eq(a1, a2, "the same name always gets the same color")
	assert_ne(a1, b, "different names get different colors (very likely, hash-based)")


func test_initials_falls_back_to_raw_words_when_everything_is_a_filler() -> void:
	assert_eq(PawnView._initials("Le La"), "LL", "no meaningful word survives: fall back to the raw words")


func test_initials_of_empty_name_is_empty() -> void:
	assert_eq(PawnView._initials(""), "")
