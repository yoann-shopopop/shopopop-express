extends GutTest
## Tests for PowerResolver — one-shot super-powers mutate the TurnContext; a power can be used once.


func _movement(budget: int) -> TurnMovement:
	return TurnMovement.new({Vector2i(0, 0): true, Vector2i(1, 0): true}, Vector2i(0, 0), budget)


func _ctx() -> TurnContext:
	var p := Player.new(PlayerColor.Kind.RED)
	p.character = CharacterDefinition.new()
	return TurnContext.new(_movement(3), p)


func test_bonne_marcheuse_adds_two_steps() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"bonne_marcheuse", ctx))
	assert_eq(ctx.movement.remaining(), 5)
	assert_true(ctx.player.power_used)


func test_a_power_can_only_be_used_once() -> void:
	var ctx := _ctx()
	PowerResolver.resolve(&"bonne_marcheuse", ctx)
	assert_false(PowerResolver.resolve(&"bonne_marcheuse", ctx), "already used")
	assert_eq(ctx.movement.remaining(), 5, "no second bonus")


func test_carnet_adresses_sets_draw_two() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"carnet_adresses", ctx))
	assert_true(ctx.draw_two)


func test_bouclier_vert_raises_the_shield() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"bouclier_vert", ctx))
	assert_true(ctx.shield)
