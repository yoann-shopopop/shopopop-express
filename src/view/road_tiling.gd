class_name RoadTiling
extends RefCounted
## Chooses how to draw a road cell from the set of directions it connects to: which texture
## (straight or T), how many 60° steps to rotate, and whether to mirror. Directions are HexUtils
## indices. Base orientations: straight links {N=2, S=5}; the T links {N, S, NE=1} (mirror → NW=3).
## Only these two textures exist, so unrepresentable graphs fall back to a straight axis.

const STRAIGHT := 1
const T := 2

const _STRAIGHT_BASE: Array[int] = [2, 5]
const _T_BASE: Array[int] = [1, 2, 5]      # NE branch
const _T_BASE_FLIP: Array[int] = [2, 3, 5] # NW branch (mirror)


## The directions a tile of [param variant] connects to once rotated by [param steps] and mirrored.
static func connected_dirs(variant: int, steps: int, flip: bool) -> Array[int]:
	var base: Array[int] = _STRAIGHT_BASE
	if variant == T:
		base = _T_BASE_FLIP if flip else _T_BASE
	var out: Array[int] = []
	for d in base:
		out.append((d + steps) % 6)
	out.sort()
	return out


## Maps a connection set to { "variant", "steps", "flip" }.
static func classify(dirs: Array) -> Dictionary:
	var target := _normalized(dirs)

	if target.size() == 1:
		return {"variant": STRAIGHT, "steps": _axis_steps(target[0]), "flip": false}

	for k in 6:
		if connected_dirs(STRAIGHT, k, false) == target:
			return {"variant": STRAIGHT, "steps": k, "flip": false}

	for k in 6:
		for flip in [false, true]:
			if connected_dirs(T, k, flip) == target:
				return {"variant": T, "steps": k, "flip": flip}

	# Unrepresentable (bend, 4-way…): fall back to a straight road on the first axis.
	var a: int = target[0] if target.size() > 0 else 2
	return {"variant": STRAIGHT, "steps": _axis_steps(a), "flip": false}


## Steps to render [param dirs] as a single STRAIGHT segment along its main axis (junction branches
## are implied by neighbours — used when only a straight road texture is available). Prefers a
## through-axis (a connected pair of opposite directions), else the first connected direction.
static func straight_steps(dirs: Array) -> int:
	var set := _normalized(dirs)
	for d in set:
		if ((d + 3) % 6) in set:
			return _axis_steps(d)
	return _axis_steps(set[0]) if set.size() > 0 else 0


# Rotation steps that bring the straight base's N end onto direction [param a].
static func _axis_steps(a: int) -> int:
	return ((a - 2) % 6 + 6) % 6


static func _normalized(dirs: Array) -> Array[int]:
	var seen := {}
	for d in dirs:
		seen[int(d)] = true
	var out: Array[int] = []
	for d in seen:
		out.append(d)
	out.sort()
	return out
