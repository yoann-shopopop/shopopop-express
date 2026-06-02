extends SceneTree
## Dev-only visual smoke test for the setup phase: starts a deterministic 3-player game, places a
## handful of pieces (finding valid road-to-road spots by scanning), captures the viewport, quits.
## Run windowed (NOT headless) for a real frame:
##   godot --path . -s res://tools/capture_preview.gd

const PLACEMENTS := 5
const SCAN := 12

var _main: Node
var _frame: int = 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_main.start_game(3, 42)
		for _i in PLACEMENTS:
			_place_one()
		_center_camera()
	if _frame == 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("user://board_preview.png")
		print("SHOT_SAVED ", OS.get_user_data_dir())
		return true
	return false


# Places the current player's first remaining piece at the first valid spot found by scanning.
func _place_one() -> void:
	var phase = _main.phase
	var board = _main.board
	if phase.is_finished():
		return
	var block = phase.current_player().pieces[0]
	if board.is_empty():
		phase.try_place(0, Vector2i.ZERO, 0)
		return
	for rot in 6:
		for q in range(-SCAN, SCAN + 1):
			for r in range(-SCAN, SCAN + 1):
				if board.can_place(block, Vector2i(q, r), rot):
					phase.try_place(0, Vector2i(q, r), rot)
					return


# Frames the placed cluster by moving the camera to its centroid.
func _center_camera() -> void:
	var cells = _main.board.occupied_cells()
	if cells.is_empty():
		return
	var sum := Vector3.ZERO
	for c in cells:
		sum += HexUtils.axial_to_world(c, 1.0)
	var centroid: Vector3 = sum / float(cells.size())
	_main._camera.position.x = centroid.x
	_main._camera.position.z = centroid.z
	_main._camera.size = 22.0
