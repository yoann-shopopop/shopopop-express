extends SceneTree
## Generates the block library: the 3 board patterns (side-3 = 19 cells) + the bridge.
## Each pattern reproduces a board asset: a road crossing the centre with a branch (3 road exits =
## 3 connectors) and the SPECIAL (rainbow) cell at the centre. The other cells (water/urban/green)
## are generated procedurally per region, always keeping >=2 green and >=1 urban zones.
## Run: godot --headless --path . -s res://tools/generate_block_resources.gd

const RADIUS := 2
const CENTER := Vector2i.ZERO

const W := CellType.Kind.WATER
const G := CellType.Kind.GREEN
const U := CellType.Kind.URBAN

# The 3 patterns (from assets B1/B2/B3): road = straight line between opposite edge-centers
# [axis]/[axis+3] through the centre + a branch to a 3rd edge-center. Special = centre cell.
var _patterns := [
	{"id": "p1", "name": "Quartier A", "axis": 0, "branch": 2, "regions": [W, W, U, U, G, G]},
	{"id": "p2", "name": "Quartier B", "axis": 1, "branch": 3, "regions": [U, W, W, G, G, U]},
	{"id": "p3", "name": "Quartier C", "axis": 2, "branch": 5, "regions": [G, U, U, W, W, G]},
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
	var ec := BlockDefinition.hexagon_edge_centers(RADIUS)
	var axis: int = spec["axis"]
	var branch: int = spec["branch"]
	var regions: Array = spec["regions"]

	# Road cells = straight line across + optional T branch from the center.
	var road := {}
	for c in HexUtils.line(ec[axis], ec[(axis + 3) % 6]):
		road[c] = true
	var connectors: Array[Vector2i] = [ec[axis], ec[(axis + 3) % 6]]
	if branch >= 0:
		for c in HexUtils.line(CENTER, ec[branch]):
			road[c] = true
		connectors.append(ec[branch])

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
