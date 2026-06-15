class_name PowerResolver
extends RefCounted
## Resolves a character's one-shot super-power, guarding single use via [member Player.power_used].
## Data-driven like [EventResolver]. Pure & static.
##
## Two kinds of power:
##  - NON-INTERACTIVE (resolved here): they mutate the turn [TurnContext] or arm a persistent benefit on
##    the [Player] (effects that pay off later — draw-two, shield, full-score, extra capacity — live on
##    the Player so they survive across turns and are never wasted).
##  - INTERACTIVE ([method is_interactive] = Dépassement, Coup d'Accélérateur): they need a target/die
##    chosen by the player, so [GamePhase] exposes dedicated methods (swap_positions / apply_reroll)
##    that the view drives. [method resolve] deliberately leaves them to those methods.
##
## An unavailable power returns false WITHOUT spending the one-shot, so the player never wastes it.


## Activates [param power_id] for the context's player. Returns false (without consuming the one-shot)
## when the power is already spent, interactive (handled elsewhere), or unknown.
static func resolve(power_id: StringName, ctx: TurnContext) -> bool:
	if ctx.player == null or ctx.player.power_used:
		return false
	match power_id:
		&"bonne_marcheuse":      # Dolly — +2 cases this turn
			ctx.movement.add_steps(2)
		&"carnet_adresses":      # Charlie — next event: draw 2, keep 1
			ctx.player.pending_draw_two = true
		&"bouclier_vert":        # Axel·le — cancel the next malus that hits you
			ctx.player.shield_charged = true
		&"habitue_quartier":     # Camille — next delivery scores as if on your colour
			ctx.player.regular_route_charge = true
		&"passage_secret":       # Gégé — water is passable this turn
			ctx.water_crossing = true
		&"chargement_pro":       # Margot — +1 in-flight delivery slot (kept for the game)
			ctx.player.bonus_capacity += 1
		_:
			return false  # interactive (depassement / coup_accelerateur) or unknown: not consumed here
	ctx.player.power_used = true
	return true


## True for every V1 power (all 8 are playable now). Lets the UI offer the power honestly.
static func is_implemented(power_id: StringName) -> bool:
	return power_id in [
		&"bonne_marcheuse", &"carnet_adresses", &"bouclier_vert", &"habitue_quartier",
		&"passage_secret", &"chargement_pro", &"depassement", &"coup_accelerateur",
	]


## True for powers that need a player choice (a target pawn / a die), driven by dedicated [GamePhase]
## methods rather than [method resolve].
static func is_interactive(power_id: StringName) -> bool:
	return power_id in [&"depassement", &"coup_accelerateur"]
