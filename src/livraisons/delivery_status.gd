class_name DeliveryStatus
extends RefCounted
## The state of a delivery combo. No status insert = DISPONIBLE; then RESERVE / EN_COURS; LIVREE
## triggers recycling of the recipient.

enum Kind { DISPONIBLE, RESERVE, EN_COURS, LIVREE }

const _LABELS := {
	Kind.DISPONIBLE: "Disponible",
	Kind.RESERVE: "Réservé",
	Kind.EN_COURS: "En cours",
	Kind.LIVREE: "Livré",
}


static func label(kind: int) -> String:
	return _LABELS.get(kind, "?")
