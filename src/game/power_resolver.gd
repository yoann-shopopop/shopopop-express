class_name PowerResolver
extends RefCounted
## Resolves a character's one-shot super-power by mutating a [TurnContext], guarding single use via
## [member Player.power_used]. Data-driven like [EventResolver]. Pure & static.
##
## V1 implements the mechanically-simple powers; the positional/interactive ones (Passage Secret,
## Dépassement, Coup d'Accélérateur, Chargement Pro) are accepted but stubbed (see CLAUDE.md).


## Activates [param power_id] for the context's player. Returns false if the power was already used.
static func resolve(power_id: StringName, ctx: TurnContext) -> bool:
	if ctx.player == null or ctx.player.power_used:
		return false
	match power_id:
		&"bonne_marcheuse":      # Dolly — +2 cases this turn
			ctx.movement.add_steps(2)
		&"carnet_adresses":      # Charlie — draw 2 event cards, keep 1
			ctx.draw_two = true
		&"bouclier_vert":        # Axel·le — cancel the next malus targeting you
			ctx.shield = true
		&"habitue_quartier":     # Camille — count one delivery as regular-route
			ctx.force_regular_route = true
		_:
			pass  # accepted but stubbed in V1 (passage_secret, depassement, coup_accelerateur, chargement_pro)
	ctx.player.power_used = true
	return true
