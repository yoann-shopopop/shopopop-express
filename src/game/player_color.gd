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


## The four colors in turn order.
static func all() -> Array[int]:
	return [Kind.BLUE, Kind.RED, Kind.PURPLE, Kind.YELLOW]


static func to_color(kind: int) -> Color:
	return _COLORS.get(kind, Color.WHITE)


static func name_of(kind: int) -> String:
	return _NAMES.get(kind, "?")
