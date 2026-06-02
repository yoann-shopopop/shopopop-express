extends GutTest
## Light test for DieView — builds, and orients the requested value to the top. No pixel assertions.


func test_build_creates_body_and_pips() -> void:
	var die := DieView.new()
	add_child_autofree(die)
	assert_gt(die.get_child_count(), 1, "a body plus pip meshes")


func test_show_value_sets_face_up_rotation() -> void:
	var die := DieView.new()
	add_child_autofree(die)
	die.show_value(3)
	assert_eq(die.rotation_degrees, Vector3(-90, 0, 0))


func test_show_value_one_is_neutral() -> void:
	var die := DieView.new()
	add_child_autofree(die)
	die.show_value(1)
	assert_eq(die.rotation_degrees, Vector3.ZERO)
