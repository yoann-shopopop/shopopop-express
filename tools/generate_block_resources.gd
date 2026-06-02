extends SceneTree
## Generates the block resource library: several hexagon patterns (side-3 = 19 cells) plus the
## bridge. Each pattern has a road crossing it that terminates at edge-center cells (the
## connectors), one event cell, and water/urban/green regions — in the spirit of the board assets.
## Run headless:  godot --headless --path . -s res://tools/generate_block_resources.gd

const RADIUS := 2          # side-3 hexagon
const CENTER := Vector2i.ZERO

# A pattern = which edges the road exits through + the terrain of each angular region (sextant),
# aligned with HexUtils.DIRECTIONS. Designed for variety while keeping a connected road network
# and at least some green (start/recipient) and urban (pickup) cells.
const W := CellType.Kind.WATER
const G := CellType.Kind.GREEN
const U := CellType.Kind.URBAN

var _patterns := [
	{"id": "p1", "name": "Quartier A", "exits": [0, 3], "regions": [W, W, U, U, G, G]},
	{"id": "p2", "name": "Quartier B", "exits": [0, 2, 4], "regions": [U, W, W, G, G, U]},
	{"id": "p3", "name": "Quartier C", "exits": [1, 4], "regions": [G, U, U, W, W, G]},
	{"id": "p4", "name": "Quartier D", "exits": [0, 2, 3, 5], "regions": [W, U, G, G, U, W]},
	{"id": "p5", "name": "Quartier E", "exits": [1, 3, 5], "regions": [G, G, W, W, U, U]},
	{"id": "p6", "name": "Quartier F", "exits": [2, 5], "regions": [U, G, W, U, G, W]},
]


func _init() -> void:
	for spec in _patterns:
		_save_pattern(spec)
	_save_bridge()
	quit()


# Closest DIRECTIONS sextant (0..5) of a non-center cell, by world-space angle.
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


func _save_pattern(spec: Dictionary) -> void:
	var cells := BlockDefinition.make_hexagon_cells(RADIUS + 1)
	var exits: Array = spec["exits"]
	var regions: Array = spec["regions"]
	var edge_centers := BlockDefinition.hexagon_edge_centers(RADIUS)

	# 1) Base terrain from the angular region theme.
	var type_of := {}
	for cell in cells:
		if cell == CENTER:
			type_of[cell] = CellType.Kind.ROUTE
		else:
			type_of[cell] = regions[_region_of(cell)]

	# 2) Carve the road: hub at center, a spoke to each exit's edge-center.
	var connectors: Array[Vector2i] = []
	for i in exits:
		var inner: Vector2i = HexUtils.DIRECTIONS[i]      # distance-1 cell toward that edge
		type_of[inner] = CellType.Kind.ROUTE
		type_of[edge_centers[i]] = CellType.Kind.ROUTE
		connectors.append(edge_centers[i])

	# 3) One event cell on a free distance-1 cell (an unused spoke).
	for j in 6:
		if j not in exits:
			type_of[HexUtils.DIRECTIONS[j]] = CellType.Kind.EVENT
			break

	# 4) Emit cell_types parallel to cells.
	var cell_types: Array[int] = []
	for cell in cells:
		cell_types.append(type_of[cell])

	var block := BlockDefinition.new()
	block.id = StringName(spec["id"])
	block.display_name = spec["name"]
	block.color = Color.WHITE  # recolored per player at distribution time
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
	block.connectors = [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i]  # the two ends
	_save(block, "res://resources/blocks/bridge.tres")


func _save(block: BlockDefinition, path: String) -> void:
	var err := ResourceSaver.save(block, path)
	if err == OK:
		print("Saved ", path, " (", block.cells.size(), " cells, ", block.connectors.size(), " connectors)")
	else:
		push_error("Failed to save %s (error %d)" % [path, err])
