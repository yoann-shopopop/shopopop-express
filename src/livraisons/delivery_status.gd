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

# Colorblind accessibility: an icon doubles the status color on the delivery panel's pills.
const _ICONS := {
	Kind.DISPONIBLE: "●",
	Kind.RESERVE: "◐",
	Kind.EN_COURS: "▶",
	Kind.LIVREE: "✓",
}


static func label(kind: int) -> String:
	# TranslationServer.translate, not tr(): this is a static method, no Object instance to call tr() on.
	return TranslationServer.translate(_LABELS.get(kind, "?"))


## Icon glyph doubling the status color (see [member _ICONS]).
static func icon(kind: int) -> String:
	return _ICONS.get(kind, "?")
