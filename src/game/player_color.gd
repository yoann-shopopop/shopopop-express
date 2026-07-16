class_name PlayerColor
extends RefCounted
## The four player identities. They are "just colors" for now; the color carries gameplay meaning
## (regular routes) and drives each block's outline.

enum Kind { BLUE, RED, PURPLE, YELLOW }

const _COLORS := {
	Kind.BLUE: Color("2d7dd2"),
	Kind.RED: Color("e84855"),
	Kind.PURPLE: Color("9b5de5"),
	Kind.YELLOW: Color("f4c430"),
}

const _NAMES := {
	Kind.BLUE: "Bleu",
	Kind.RED: "Rouge",
	Kind.PURPLE: "Violet",
	Kind.YELLOW: "Jaune",
}

# Single-letter initials for compact UI chips (colorblind accessibility: identity must not rest on
# color alone). Distinct even though two names could share a first letter by coincidence — they don't
# here, but pick from later letters if a future color collides ("Rouge"/"Rose" would both be "R").
const _INITIALS := {
	Kind.BLUE: "B",
	Kind.RED: "R",
	Kind.PURPLE: "V",  # Violet
	Kind.YELLOW: "J",
}


## The four colors in turn order.
static func all() -> Array[int]:
	return [Kind.BLUE, Kind.RED, Kind.PURPLE, Kind.YELLOW]


static func to_color(kind: int) -> Color:
	return _COLORS.get(kind, Color.WHITE)


static func name_of(kind: int) -> String:
	# TranslationServer.translate, not tr(): this is a static method, no Object instance to call tr() on.
	return TranslationServer.translate(_NAMES.get(kind, "?"))


## Single-letter initial for compact chips (order-bar dots, panels) — see [member _INITIALS].
static func initial_of(kind: int) -> String:
	return _INITIALS.get(kind, "?")
