class_name PlacedPiece
extends RefCounted
## A block instance committed to the board: its owner, source definition, placement transform, and
## the resolved (absolute) typed cells and connectors. Identity matters for rendering (one outline
## per piece, in the owner's color).

var owner: int                              ## Player id/color (PlayerColor.Kind), or -1 if none.
var block_def: BlockDefinition
var anchor: Vector2i
var rotation: int
var typed_cells: Array                      ## [{ "cell": Vector2i, "type": int }, …]
var connector_cells: Array[Vector2i]


func _init(p_block: BlockDefinition, p_anchor: Vector2i, p_rotation: int, p_owner: int) -> void:
	block_def = p_block
	anchor = p_anchor
	rotation = p_rotation
	owner = p_owner
	typed_cells = p_block.get_typed_cells(p_anchor, p_rotation)
	connector_cells = p_block.get_connectors(p_anchor, p_rotation)


## The absolute cells this piece occupies.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tc in typed_cells:
		result.append(tc["cell"])
	return result
