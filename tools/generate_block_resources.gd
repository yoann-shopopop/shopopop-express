extends SceneTree
## One-shot generator for the canonical block resources.
## Run headless:  godot --headless --path . -s res://tools/generate_block_resources.gd
## Re-run whenever the canonical shapes change. Designers can still tweak the .tres afterwards.


func _init() -> void:
	_save_block(&"hex19", "Hexagone", Color("4caf50"), BlockDefinition.make_hexagon_cells(3))
	_save_block(&"bridge3", "Pont", Color("ff9800"), BlockDefinition.make_line_cells(3))
	quit()


func _save_block(id: StringName, display_name: String, color: Color, cells: Array[Vector2i]) -> void:
	var block := BlockDefinition.new()
	block.id = id
	block.display_name = display_name
	block.color = color
	block.cells = cells
	var path := "res://resources/blocks/%s.tres" % id
	var err := ResourceSaver.save(block, path)
	if err == OK:
		print("Saved ", path, " (", cells.size(), " cells)")
	else:
		push_error("Failed to save %s (error %d)" % [path, err])
