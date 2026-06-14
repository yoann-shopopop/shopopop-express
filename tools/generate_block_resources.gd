extends SceneTree
## Generates the block library: the 3 board patterns (side-3 = 19 cells) + the bridge.
## Each pattern reproduces a board asset: roads built from straight segments crossing the centre,
## which is the SPECIAL (rainbow) cell. Two patterns are a straight road with one bifurcation toward
## an adjacent edge (Y, mirrored left/right = 3 connectors); one is two straight roads crossing (X =
## 4 connectors). The other cells (water/urban/green) are generated procedurally per region, always
## keeping >=2 green and >=1 urban.
## Run: godot --headless --path . -s res://tools/generate_block_resources.gd

const RADIUS := 2
const CENTER := Vector2i.ZERO

const W := CellType.Kind.WATER
const G := CellType.Kind.GREEN
const U := CellType.Kind.URBAN

# The 3 quarter patterns (originally traced from the physical board tiles). "roads" is a list of segments (HexUtils corner indices
# 0..5; corner i = DIRECTIONS[i] * RADIUS): a 2-corner segment [a, b] is a straight road between
# opposite corners (grain-aligned, perfectly straight through the centre); a 1-corner segment [d] is
# a bifurcation from the centre out to that corner. p1/p2 = a straight road {0-3} + one fork toward
# an adjacent corner (1 vs 5 = mirrored Y, fork left/right); p3 = two straight roads crossing
# {0-3}+{1-4} (X). Every corner touched is a connector (where tiles join road-to-road).
var _patterns := [
	{"id": "p1", "name": "Quartier A", "roads": [[0, 3], [1]], "regions": [W, W, U, U, G, G]},
	{"id": "p2", "name": "Quartier B", "roads": [[0, 3], [5]], "regions": [U, W, W, G, G, U]},
	{"id": "p3", "name": "Quartier C", "roads": [[0, 3], [1, 4]], "regions": [G, U, U, W, W, G]},
]


func _init() -> void:
	for spec in _patterns:
		_save_pattern(spec)
	_save_bridge()
	quit()


func _region_of(cell: Vector2i) -> int:
	var world := HexUtils.axial_to_world(cell, 1.0)
	var best := 0
	var best_dot := -INF
	for d in 6:
		var dir_world := HexUtils.axial_to_world(HexUtils.DIRECTIONS[d], 1.0)
		var dot := world.normalized().dot(dir_world.normalized())
		if dot > best_dot:
			best_dot = dot
			best = d
	return best


# Guarantees at least [param count] cells of [param kind], converting rim terrain cells if needed.
func _ensure_count(type_of: Dictionary, cells: Array, kind: int, count: int) -> void:
	var have := 0
	for cell in cells:
		if type_of[cell] == kind:
			have += 1
	for cell in cells:
		if have >= count:
			return
		var t: int = type_of[cell]
		if t != CellType.Kind.ROUTE and t != CellType.Kind.EVENT and t != kind and HexUtils.distance(CENTER, cell) == RADIUS:
			type_of[cell] = kind
			have += 1


func _save_pattern(spec: Dictionary) -> void:
	var cells := BlockDefinition.make_hexagon_cells(RADIUS + 1)
	var roads: Array = spec["roads"]
	var regions: Array = spec["regions"]

	# Road cells from segments, built between the big hexagon's CORNERS (HexUtils.DIRECTIONS[i] * R).
	# A line between two opposite corners runs along a grid grain axis, so it is perfectly straight;
	# edge-centers are not grain-aligned and would make the road stagger. A 2-corner segment is a
	# straight road across; a 1-corner segment is a bifurcation from the centre. Every corner reached
	# becomes a connector.
	var road := {}
	var connector_set := {}
	for seg in roads:
		var a: Vector2i = HexUtils.DIRECTIONS[seg[0]] * RADIUS
		var b: Vector2i = HexUtils.DIRECTIONS[seg[-1]] * RADIUS
		var endpoints := HexUtils.line(a, b) if seg.size() == 2 else HexUtils.line(CENTER, a)
		for c in endpoints:
			road[c] = true
		for e in seg:
			connector_set[HexUtils.DIRECTIONS[e] * RADIUS] = true
	var connectors: Array[Vector2i] = []
	for c in connector_set:
		connectors.append(c)

	# Terrain: road cells, then regions for the rest (water kept to the outer ring so it never
	# appears in the middle of a block).
	var type_of := {}
	for cell in cells:
		if road.has(cell):
			type_of[cell] = CellType.Kind.ROUTE
			continue
		var t: int = regions[_region_of(cell)]
		if t == CellType.Kind.WATER and HexUtils.distance(CENTER, cell) < RADIUS:
			t = CellType.Kind.GREEN
		type_of[cell] = t

	# The special (rainbow) cell sits at the centre — a ROAD with a unique texture (like the assets).
	type_of[CENTER] = CellType.Kind.EVENT

	_ensure_count(type_of, cells, CellType.Kind.GREEN, 2)
	_ensure_count(type_of, cells, CellType.Kind.URBAN, 1)

	var cell_types: Array[int] = []
	for cell in cells:
		cell_types.append(type_of[cell])

	var block := BlockDefinition.new()
	block.id = StringName(spec["id"])
	block.display_name = spec["name"]
	block.color = Color.WHITE
	block.cells = cells
	block.cell_types = cell_types
	block.connectors = connectors
	_save(block, "res://resources/blocks/patterns/%s.tres" % spec["id"])


func _save_bridge() -> void:
	var block := BlockDefinition.new()
	block.id = &"bridge"
	block.display_name = "Pont"
	block.color = Color.WHITE
	block.cells = BlockDefinition.make_line_cells(3)
	block.cell_types = [CellType.Kind.WATER, CellType.Kind.ROUTE, CellType.Kind.WATER]
	# Only the central ROAD cell connects — never the water ends, never along the length.
	block.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	_save(block, "res://resources/blocks/bridge.tres")


func _save(block: BlockDefinition, path: String) -> void:
	var err := ResourceSaver.save(block, path)
	if err == OK:
		print("Saved ", path, " (", block.cells.size(), " cells, ", block.connectors.size(), " connectors)")
	else:
		push_error("Failed to save %s (error %d)" % [path, err])
