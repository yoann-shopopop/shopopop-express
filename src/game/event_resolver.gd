class_name EventResolver
extends RefCounted
## Resolves an [EventCardDefinition] by mutating a [TurnContext] — one [code]match[/code] mapping each
## effect to a context mutation, so the catalog stays data-driven (no scattered ifs). Pure & static.
##
## Interactive / positional effects (TELEPORT_QUARTIER, TELEPORT_PARALLELE, BUDGET_UN_DE,
## ROUTE_BLOQUEE, PONTS_FERMES) are stubbed in V1 (see CLAUDE.md "Points ouverts").

const E := EventCardDefinition.Effect


## Applies [param card] to [param ctx], if its condition holds.
static func resolve(card: EventCardDefinition, ctx: TurnContext) -> void:
	if not _condition_met(card.condition, ctx):
		return
	match card.effect:
		E.BONUS_CASES:
			ctx.movement.add_steps(card.amount)
		E.MALUS_CASES:
			ctx.movement.subtract_steps(card.amount)
		E.DOUBLE_DICE:
			ctx.movement.add_steps(ctx.movement.remaining())  # double what's left this turn
		E.EXTRA_DIE:
			ctx.extra_dice += 1
		E.REJOUER:
			ctx.replay = true
		E.FIN_TOUR:
			ctx.turn_ended = true
			ctx.movement.subtract_steps(ctx.movement.remaining())
		E.RETOUR_DRIVE:
			if ctx.current_delivery != null:
				ctx.movement.teleport_to(ctx.current_delivery.drive_cell)
		E.RETOUR_DEPART:
			ctx.movement.teleport_to(ctx.start_cell)
		E.TELEPORT_DESTINATION:
			if ctx.current_delivery != null:
				var target := ctx.current_delivery.recipient_cell \
					if ctx.current_delivery.status == DeliveryStatus.Kind.EN_COURS \
					else ctx.current_delivery.drive_cell
				ctx.movement.teleport_to(target)
		E.BONUS_SCORE:
			ctx.score_bonus += card.amount
		E.DOUBLE_SCORE_LIVRAISON:
			ctx.double_score = true
		_:
			pass  # NONE and stubbed interactive effects: no-op in V1


static func _condition_met(condition: int, ctx: TurnContext) -> bool:
	if condition == EventCardDefinition.Condition.VELO:
		return ctx.player != null and ctx.player.character != null \
			and ctx.player.character.transport == CharacterDefinition.Transport.VELO
	return true
