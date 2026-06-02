extends Node3D
## Composition root for the setup phase. Builds the top-down view, asks the player count, then wires
## the distribution, the turn-by-turn placement phase, the board view, the pointer controller and UI.

const PATTERNS_DIR := "res://resources/blocks/patterns/"
const BRIDGE_PATH := "res://resources/blocks/bridge.tres"

var board: Board
var phase: SetupPhase
var controller: PlacementController
var grid_view: HexGridView

var _camera: CameraRig
var _ghost: BlockGhost
var _ui: PlacementUI
var _library: Array[BlockDefinition] = []
var _bridge: BlockDefinition


func _ready() -> void:
	_library = _load_library()
	_bridge = load(BRIDGE_PATH)
	_camera = _build_camera()
	_build_light()
	_build_environment()
	_ui = PlacementUI.new()
	add_child(_ui)
	_ui.player_count_chosen.connect(_on_player_count_chosen)


## Starts a game with [param count] players. [param rng_seed] >= 0 makes the draw deterministic.
func start_game(count: int, rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var players := SetupDistributor.build_players(count, _library, _bridge, rng)
	_ui.begin_game()

	board = Board.new()
	phase = SetupPhase.new(players, board)

	grid_view = HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, players)

	_ghost = BlockGhost.new()
	add_child(_ghost)

	controller = PlacementController.new()
	add_child(controller)
	controller.setup(_camera, board, _ghost, phase)

	phase.turn_changed.connect(_on_turn_changed)
	phase.setup_finished.connect(_on_setup_finished)
	_ui.piece_selected.connect(controller.select_piece)
	_ui.rotate_requested.connect(controller.rotate_current)
	_ui.set_current_player(phase.current_player())


func _on_player_count_chosen(count: int) -> void:
	start_game(count)


func _on_turn_changed(player: Player) -> void:
	controller.select_piece(0)
	_ui.set_current_player(player)


func _on_setup_finished() -> void:
	_ui.set_finished()
	grid_view.show_pawns()


# --- Static library ---------------------------------------------------------

func _load_library() -> Array[BlockDefinition]:
	var result: Array[BlockDefinition] = []
	var dir := DirAccess.open(PATTERNS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(PATTERNS_DIR + file))
	return result


# --- Scene scaffolding ------------------------------------------------------

func _build_camera() -> CameraRig:
	var camera := CameraRig.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.position = Vector3(0, 20, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.current = true
	add_child(camera)
	return camera


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.shadow_enabled = true
	add_child(light)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2330")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a0")
	env.ambient_light_energy = 0.6
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)
