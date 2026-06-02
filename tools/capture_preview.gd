extends SceneTree
## Dev-only visual smoke test: loads the main scene, seeds a couple of placements, captures the
## viewport to user://board_preview.png, then quits. Run windowed (NOT headless) for a real frame.

var _main: Node
var _frame: int = 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		var hex: BlockDefinition = load("res://resources/blocks/hex19.tres")
		var bridge: BlockDefinition = load("res://resources/blocks/bridge3.tres")
		_main.board.place(hex, Vector2i.ZERO, 0)            # left hexagon
		_main.board.place(bridge, Vector2i(3, 0), 0)        # bridge off its right edge
		_main.board.place(hex, Vector2i(8, 0), 0)           # right hexagon off the bridge's end
		# Truthful, valid (green) ghost of the next bridge on a free adjacent cell.
		_main.controller.select_block(bridge)
		_main.controller.preview_at(Vector2i(0, 3))
	if _frame == 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("user://board_preview.png")
		print("SHOT_SAVED ", OS.get_user_data_dir())
		return true
	return false
