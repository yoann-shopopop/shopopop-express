extends SceneTree
## Generates the block library: hexagon patterns (side-3 = 19 cells) + the bridge.
## Roads use ONLY the two available textures (straight, T), so each pattern's road is a straight
## line between two opposite edge-centers (through the center) plus an optional T branch to a third
## edge-center. Edge-centers carrying a road are the connectors. The rest is water/urban/green by
## region, with one event cell. Run: godot --headless --path . -s res://tools/generate_block_resources.gd

const RADIUS := 2
const CENTER := Vector2i.ZERO

const W := CellType.Kind.WATER
const G := CellType.Kind.GREEN
const U := CellType.Kind.URBAN

# axis = straight road between opposite edge-centers [axis] and [axis+3], crossing the center.
# Single 1-wide road (no T-junction, to avoid wide road clumps). branch kept for future use (-1).
var _patterns := [
	{"id": "p1", "name": "Quartier A", "axis": 0, "branch": -1, "regions": [W, W, U, U, G, G]},
	{"id": "p2", "name": "Quartier B", "axis": 1, "branch": -1, "regions": [U, W, W, G, G, U]},
	{"id": "p3", "name": "Quartier C", "axis": 2, "branch": -1, "regions": [G, U, U, W, W, G]},
	{"id": "p4", "name": "Quartier D", "axis": 0, "branch": -1, "regions": [W, U, G, G, U, W]},
	{"id": "p5", "name": "Quartier E", "axis": 1, "branch": -1, "regions": [G, G, W, W, U, U]},
	{"id": "p6", "name": "Quartier F", "axis": 2, "branch": -1, "regions": [U, G, W, U, G, W]},
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


# Guarantees at least one cell of [param kind] by converting a rim cell if none is present.
func _ensure_present(type_of: Dictionary, cells: Array, kind: int) -> void:
	for cell in cells:
		if type_of[cell] == kind:
			return
	for cell in cells:
		var t: int = type_of[cell]
		if t != CellType.Kind.ROUTE and t != CellType.Kind.EVENT and HexUtils.distance(CENTER, cell) == RADIUS:
			type_of[cell] = kind
			return


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

	# The special cell is a ROAD with a unique texture: replace one inner road cell (a spoke next to
	# the center, never an edge-center connector) by EVENT.
	for d in 6:
		if road.has(HexUtils.DIRECTIONS[d]):
			type_of[HexUtils.DIRECTIONS[d]] = CellType.Kind.EVENT
			break

	_ensure_present(type_of, cells, CellType.Kind.GREEN)
	_ensure_present(type_of, cells, CellType.Kind.URBAN)

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
	block.connectors = [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i]
	_save(block, "res://resources/blocks/bridge.tres")


func _save(block: BlockDefinition, path: String) -> void:
	var err := ResourceSaver.save(block, path)
	if err == OK:
		print("Saved ", path, " (", block.cells.size(), " cells, ", block.connectors.size(), " connectors)")
	else:
		push_error("Failed to save %s (error %d)" % [path, err])
