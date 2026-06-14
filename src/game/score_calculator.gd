class_name ScoreCalculator
extends RefCounted
## Scores a delivery for its carrier. Pure, static.
##
## Formula (Notion rules): [constant BASE] points, plus [constant PER_OWNED_TILE] for each tile of the
## delivery whose district color belongs to the character, with one exception: a delivery on a single
## tile that is the character's own scores [constant SINGLE_OWNED_TILE] instead.
## So: 2 owned tiles = 25 · 1 owned single tile = 20 · 1 of 2 owned = 15 · none owned = 5.
## The constants are kept tweakable on purpose — the Notion score table is internally inconsistent
## (see CLAUDE.md "Points ouverts"), so the literal formula is the source of truth, not the table.

const BASE := 5
const PER_OWNED_TILE := 10
const SINGLE_OWNED_TILE := 20


## Points the [param delivery] is worth for [param character].
static func score_delivery(delivery: Delivery, character: CharacterDefinition) -> int:
	var owners := delivery.tile_owners()
	if delivery.is_single_tile() and character.owns_color(owners[0]):
		return SINGLE_OWNED_TILE
	var score := BASE
	for owner in owners:
		if character.owns_color(owner):
			score += PER_OWNED_TILE
	return score
