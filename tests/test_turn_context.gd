extends GutTest
## Tests for TurnContext — it captures the start cell from the movement, and defaults its flags off.


func test_captures_the_start_cell_from_the_movement() -> void:
	var movement := TurnMovement.new({Vector2i(3, 0): true}, Vector2i(3, 0), 2)
	var ctx := TurnContext.new(movement, null)
	assert_eq(ctx.start_cell, Vector2i(3, 0))


func test_flags_default_off() -> void:
	var ctx := TurnContext.new()
	assert_false(ctx.turn_ended)
	assert_false(ctx.replay)
	assert_false(ctx.double_score)
	assert_eq(ctx.score_bonus, 0)
