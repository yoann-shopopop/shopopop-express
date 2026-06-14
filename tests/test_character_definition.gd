extends GutTest
## Tests for CharacterDefinition — transport→dice count, and the two regular-route colors.


func _make(transport: int, colors: Array[int]) -> CharacterDefinition:
	var c := CharacterDefinition.new()
	c.transport = transport
	c.colors = colors
	return c


func test_bike_and_foot_roll_one_die() -> void:
	assert_eq(_make(CharacterDefinition.Transport.VELO, []).dice_count(), 1)
	assert_eq(_make(CharacterDefinition.Transport.A_PIED, []).dice_count(), 1)


func test_car_and_truck_roll_two_dice() -> void:
	assert_eq(_make(CharacterDefinition.Transport.VOITURE, []).dice_count(), 2)
	assert_eq(_make(CharacterDefinition.Transport.CAMION, []).dice_count(), 2)


func test_owns_color_checks_the_regular_route_colors() -> void:
	var c := _make(CharacterDefinition.Transport.VELO, [PlayerColor.Kind.RED, PlayerColor.Kind.YELLOW])
	assert_true(c.owns_color(PlayerColor.Kind.RED))
	assert_true(c.owns_color(PlayerColor.Kind.YELLOW))
	assert_false(c.owns_color(PlayerColor.Kind.BLUE))
