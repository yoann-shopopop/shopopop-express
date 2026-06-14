class_name BlockDefinition
extends Resource
## A modular board piece, defined purely by the axial cells it occupies.
##
## [member cells] are offsets relative to an anchor cell; the same definition can be placed
## anywhere and rotated. Designers create new pieces by making a new [code].tres[/code] —
## no code required. Shape helpers below generate the canonical Shopopop Express pieces.

## Stable identifier, e.g. [code]&"hex19"[/code] or [code]&"bridge3"[/code].
@export var id: StringName = &""
## Human-readable name shown in the UI.
@export var display_name: String = ""
## Tint applied to this piece's tiles when rendered.
@export var color: Color = Color.WHITE
## Axial cell offsets relative to the anchor. Filled from the shape helpers or the editor.
@export var cells: Array[Vector2i] = []
## Terrain type of each cell, parallel to [member cells] (values from [enum CellType.Kind]).
@export var cell_types: Array[int] = []
## Offsets of the road-connection cells used by the placement adjacency rule
## (a hexagon's road edge-centers, or a bridge's end cells).
@export var connectors: Array[Vector2i] = []


## Returns the absolute cells this piece would occupy at [param anchor] for the given
## [param rotation] (in 60-degree steps).
func get_cells(anchor: Vector2i, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in cells:
		result.append(HexUtils.rotate(offset, rotation) + anchor)
	return result


## Returns the placed cells paired with their type: [code][{ "cell": Vector2i, "type": int }, …][/code].
## Types travel with their cell through rotation.
func get_typed_cells(anchor: Vector2i, rotation: int) -> Array:
	var result: Array = []
	for i in cells.size():
		var cell := HexUtils.rotate(cells[i], rotation) + anchor
		var type: int = cell_types[i] if i < cell_types.size() else CellType.Kind.ROUTE
		result.append({"cell": cell, "type": type})
	return result


## Returns the absolute connection cells at [param anchor]/[param rotation].
func get_connectors(anchor: Vector2i, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in connectors:
		result.append(HexUtils.rotate(offset, rotation) + anchor)
	return result


## The six edge-center cells of a hexagon of the given [param radius] (where roads terminate).
static func hexagon_edge_centers(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in 6:
		var a := HexUtils.DIRECTIONS[i] * radius
		var b := HexUtils.DIRECTIONS[(i + 1) % 6] * radius
		result.append((a + b) / 2)
	return result


## Generates the offsets of a hexagon-shaped block of the given [param side] (in cells).
## A side-3 hexagon yields 19 cells.
static func make_hexagon_cells(side: int) -> Array[Vector2i]:
	var radius := side - 1
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r_min: int = maxi(-radius, -q - radius)
		var r_max: int = mini(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			result.append(Vector2i(q, r))
	return result


## Generates the offsets of a straight bridge of [param length] cells (width 1).
static func make_line_cells(length: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(length):
		result.append(Vector2i(i, 0))
	return result
