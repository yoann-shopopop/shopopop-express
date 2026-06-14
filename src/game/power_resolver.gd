class_name PowerResolver
extends RefCounted
## Resolves a character's one-shot super-power by mutating a [TurnContext], guarding single use via
## [member Player.power_used]. Data-driven like [EventResolver]. Pure & static.
##
## V1 implements the mechanically-simple powers; the positional/interactive ones (Passage Secret,
## Dépassement, Coup d'Accélérateur, Chargement Pro) are not available yet. Crucially, an unavailable
## power returns false WITHOUT spending the one-shot, so the player never wastes it on a no-op.


## Activates [param power_id] for the context's player. Returns false (without consuming the one-shot)
## when the power is already spent or not yet implemented.
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
			return false  # not implemented yet — do NOT consume the one-shot (no silent waste)
	ctx.player.power_used = true
	return true


## True when [param power_id] has a mechanical effect in V1 (so the UI can label/offer it honestly).
static func is_implemented(power_id: StringName) -> bool:
	return power_id in [&"bonne_marcheuse", &"carnet_adresses", &"bouclier_vert", &"habitue_quartier"]
