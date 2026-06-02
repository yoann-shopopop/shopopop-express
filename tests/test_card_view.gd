extends GutTest
## Light test for CardView — builds meshes and flips. No pixel assertions.


func _card() -> CardDefinition:
	return CardDefinition.new()


func test_bind_builds_meshes() -> void:
	var view := CardView.new()
	add_child_autofree(view)
	view.bind(_card())
	assert_gt(view.get_child_count(), 0, "card view builds its body/front/back")


func test_face_up_has_no_flip() -> void:
	var view := CardView.new()
	add_child_autofree(view)
	view.bind(_card())
	view.set_face_up(true)
	assert_almost_eq(view.rotation_degrees.x, 0.0, 0.001)


func test_face_down_flips_card() -> void:
	var view := CardView.new()
	add_child_autofree(view)
	view.bind(_card())
	view.set_face_up(false)
	assert_almost_eq(view.rotation_degrees.x, 180.0, 0.001)
