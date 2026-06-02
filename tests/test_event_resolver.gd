extends GutTest
## Tests for EventResolver — each effect mutates the TurnContext as expected; conditions gate effects.

const E := EventCardDefinition.Effect
const C := EventCardDefinition.Condition


func _movement(budget: int) -> TurnMovement:
	var walkable := {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true}
	return TurnMovement.new(walkable, Vector2i(0, 0), budget)


func _player(transport: int) -> Player:
	var p := Player.new(PlayerColor.Kind.RED)
	var c := CharacterDefinition.new()
	c.transport = transport
	p.character = c
	return p


func _card(effect: int, amount: int = 0, condition: int = C.NONE) -> EventCardDefinition:
	var card := EventCardDefinition.new()
	card.effect = effect
	card.amount = amount
	card.condition = condition
	return card


func _ctx(transport: int = CharacterDefinition.Transport.VOITURE) -> TurnContext:
	return TurnContext.new(_movement(4), _player(transport))


func test_bonus_cases_adds_steps() -> void:
	var ctx := _ctx()
	EventResolver.resolve(_card(E.BONUS_CASES, 3), ctx)
	assert_eq(ctx.movement.remaining(), 7)


func test_malus_cases_subtracts_steps() -> void:
	var ctx := _ctx()
	EventResolver.resolve(_card(E.MALUS_CASES, 2), ctx)
	assert_eq(ctx.movement.remaining(), 2)


func test_fin_tour_ends_turn_and_zeroes_budget() -> void:
	var ctx := _ctx()
	EventResolver.resolve(_card(E.FIN_TOUR), ctx)
	assert_true(ctx.turn_ended)
	assert_eq(ctx.movement.remaining(), 0)


func test_rejouer_sets_replay() -> void:
	var ctx := _ctx()
	EventResolver.resolve(_card(E.REJOUER), ctx)
	assert_true(ctx.replay)


func test_bonus_score_accumulates() -> void:
	var ctx := _ctx()
	EventResolver.resolve(_card(E.BONUS_SCORE, 20), ctx)
	assert_eq(ctx.score_bonus, 20)


func test_velo_condition_skips_for_a_car() -> void:
	var ctx := _ctx(CharacterDefinition.Transport.VOITURE)
	EventResolver.resolve(_card(E.BONUS_CASES, 5, C.VELO), ctx)
	assert_eq(ctx.movement.remaining(), 4, "no bonus for a car")


func test_velo_condition_applies_for_a_bike() -> void:
	var ctx := _ctx(CharacterDefinition.Transport.VELO)
	EventResolver.resolve(_card(E.BONUS_CASES, 5, C.VELO), ctx)
	assert_eq(ctx.movement.remaining(), 9, "bonus applies on a bike")


func test_retour_depart_teleports_to_start() -> void:
	var ctx := _ctx()
	ctx.movement.step(Vector2i(1, 0))
	EventResolver.resolve(_card(E.RETOUR_DEPART), ctx)
	assert_eq(ctx.movement.current(), Vector2i(0, 0))


func test_teleport_destination_goes_to_the_drive_before_pickup() -> void:
	var ctx := _ctx()
	ctx.current_delivery = Delivery.new(Vector2i(5, 5), Vector2i(6, 6), [] as Array[PlacedPiece])
	EventResolver.resolve(_card(E.TELEPORT_DESTINATION), ctx)
	assert_eq(ctx.movement.current(), Vector2i(5, 5))
