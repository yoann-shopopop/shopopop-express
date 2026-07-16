class_name ScoreCalculator
extends RefCounted
## Scores a delivery for its carrier. Pure, static.
##
## Formule (règles 2026-06) : [constant BASE] points, +[constant PER_TILE_OWNED] si la tuile du drive
## est de la couleur du joueur, +[constant PER_TILE_OWNED] si la tuile du destinataire l'est aussi.
## Mono-tuile (drive et destinataire sur la même tuile) ⇒ 5 (aucune) ou 25 (tuile à soi).

const BASE := 5
const PER_TILE_OWNED := 10


## Points the [param delivery] is worth for a carrier of district color [param color] (PlayerColor.Kind).
static func score_delivery(delivery: Delivery, color: int) -> int:
	return breakdown_delivery(delivery, color)["subtotal"]


## Structured breakdown of [method score_delivery] — { base, drive_bonus, recipient_bonus, subtotal }
## — used by the UI to teach the territorial rule at the moment a delivery pays off. Event effects
## (Livraison Écologique's ×2, Habitué·e's full-score override) are NOT part of this: they show up as
## a difference between [code]subtotal[/code] and the delivery's actual awarded points.
static func breakdown_delivery(delivery: Delivery, color: int) -> Dictionary:
	var drive_bonus := PER_TILE_OWNED if delivery.drive_tile_owner() == color else 0
	var recipient_bonus := PER_TILE_OWNED if delivery.recipient_tile_owner() == color else 0
	return {
		"base": BASE,
		"drive_bonus": drive_bonus,
		"recipient_bonus": recipient_bonus,
		"subtotal": BASE + drive_bonus + recipient_bonus,
	}


## The most a single delivery can score (base + both tile bonuses). Habitué·e (Camille) makes one
## delivery count as if both its tiles were the player's color, regardless of the real owners.
static func full_score() -> int:
	return BASE + 2 * PER_TILE_OWNED
