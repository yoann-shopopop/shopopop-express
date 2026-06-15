extends GutTest
## Tests for PowerResolver — one-shot super-powers either mutate the turn TurnContext or arm a
## persistent benefit on the Player; a power can be used once. Interactive powers (Dépassement, Coup
## d'Accélérateur) are NOT resolved here (GamePhase drives them) — see test_game_phase.gd.


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


func test_carnet_adresses_arms_draw_two_on_the_player() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"carnet_adresses", ctx))
	assert_true(ctx.player.pending_draw_two, "Charlie arms a persistent draw-2")


func test_bouclier_vert_arms_the_shield_on_the_player() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"bouclier_vert", ctx))
	assert_true(ctx.player.shield_charged)


func test_habitue_quartier_arms_a_full_score_charge() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"habitue_quartier", ctx))
	assert_true(ctx.player.regular_route_charge)


func test_passage_secret_opens_water_this_turn() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"passage_secret", ctx))
	assert_true(ctx.water_crossing)


func test_chargement_pro_raises_capacity() -> void:
	var ctx := _ctx()
	assert_true(PowerResolver.resolve(&"chargement_pro", ctx))
	assert_eq(ctx.player.bonus_capacity, 1)


func test_interactive_powers_are_not_resolved_here() -> void:
	var ctx := _ctx()
	assert_false(PowerResolver.resolve(&"depassement", ctx), "Dépassement is interactive (GamePhase)")
	assert_false(PowerResolver.resolve(&"coup_accelerateur", ctx), "Coup d'Accélérateur is interactive")
	assert_false(ctx.player.power_used, "the one-shot is preserved for the interactive method")


func test_is_implemented_covers_all_eight_powers() -> void:
	for pid in [&"bonne_marcheuse", &"carnet_adresses", &"bouclier_vert", &"habitue_quartier",
			&"passage_secret", &"chargement_pro", &"depassement", &"coup_accelerateur"]:
		assert_true(PowerResolver.is_implemented(pid), "%s should be playable" % pid)
	assert_false(PowerResolver.is_implemented(&"inconnu"))


func test_is_interactive_flags_swap_and_reroll() -> void:
	assert_true(PowerResolver.is_interactive(&"depassement"))
	assert_true(PowerResolver.is_interactive(&"coup_accelerateur"))
	assert_false(PowerResolver.is_interactive(&"bonne_marcheuse"))
