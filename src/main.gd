extends Node3D
## Composition root for the setup phase. Builds the top-down view, asks the player count, then wires
## the distribution, the turn-by-turn placement phase, the board view, the pointer controller and UI.

const PATTERNS_DIR := "res://resources/blocks/patterns/"
const CHARACTERS_DIR := "res://resources/characters/"
const BRIDGE_PATH := "res://resources/blocks/bridge.tres"

var board: Board
var phase: SetupPhase
var controller: PlacementController
var grid_view: HexGridView

var _camera: CameraRig
var _ghost: BlockGhost
var _ui: PlacementUI
var _library: Array[BlockDefinition] = []
var _characters: Array[CharacterDefinition] = []
var _bridge: BlockDefinition
var _players: Array[Player] = []
var _game_root: GameRoot
var _initial_piece_counts: Dictionary = {}  # Player -> initial tile count, for the "Tour X/Y" header


func _ready() -> void:
	_library = _load_library()
	_characters = _load_characters()
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
	_players = SetupDistributor.build_players(count, _library, _bridge, rng, _characters)
	_initial_piece_counts.clear()
	for p in _players:
		_initial_piece_counts[p] = p.pieces.size()
	_ui.begin_game()

	board = Board.new()
	phase = SetupPhase.new(_players, board)

	grid_view = HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, _players)

	_ghost = BlockGhost.new()
	add_child(_ghost)

	controller = PlacementController.new()
	add_child(controller)
	controller.setup(_camera, board, _ghost, phase)

	phase.turn_changed.connect(_on_turn_changed)
	phase.turn_state_changed.connect(_on_turn_changed)
	phase.setup_finished.connect(_on_setup_finished)
	_ui.piece_drag_started.connect(controller.begin_drag)
	_ui.bridge_drag_started.connect(controller.begin_bridge_drag)
	_ui.finish_requested.connect(_on_finish_requested)
	_ui.rotate_requested.connect(controller.rotate_current)
	_ui.rotate_left_requested.connect(func() -> void: controller.rotate_active(-1))
	_ui.rotate_right_requested.connect(func() -> void: controller.rotate_active(1))
	_ui.remove_requested.connect(controller.remove_active)
	controller.controls_changed.connect(_ui.update_controls)
	controller.drag_changed.connect(_ui.set_dragging)
	_refresh_ui()


func _on_player_count_chosen(count: int) -> void:
	start_game(count)


func _on_turn_changed(_player: Player) -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	var player := phase.current_player()
	var total: int = _initial_piece_counts.get(player, player.pieces.size())
	var index := PlacementUI.compute_turn_index(total, player.pieces.size(), phase.block_placed_this_turn())
	_ui.set_current_player(player, phase.block_placed_this_turn(), index, total)
	_ui.set_dragging(false)


func _on_finish_requested() -> void:
	phase.finish_turn()


func _on_setup_finished() -> void:
	# Hand over from setup to the play phase: drop the placement UI/controller and start GameRoot,
	# which owns the moving pawns, dice, movement input and the in-game UI.
	_ui.queue_free()
	controller.queue_free()
	_game_root = GameRoot.new()
	add_child(_game_root)
	_game_root.setup(board, _players, _camera)


# --- Static library ---------------------------------------------------------

func _load_library() -> Array[BlockDefinition]:
	var result: Array[BlockDefinition] = []
	var dir := DirAccess.open(PATTERNS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(PATTERNS_DIR + file))
	return result


func _load_characters() -> Array[CharacterDefinition]:
	var result: Array[CharacterDefinition] = []
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(CHARACTERS_DIR + file))
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
	# Light, airy backdrop (mockup feel). A full-screen gradient on a background CanvasLayer sits behind
	# the 3D board; the 3D environment itself stays transparent-ish via a matching flat clear color.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c3d2df")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe7ef")
	env.ambient_light_energy = 0.8
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)

	# Vertical gradient drawn behind everything (light top -> slightly deeper bottom).
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100  # behind PlacementUI (layer 1) and the default layer (0)
	add_child(bg_layer)
	var rect := TextureRect.new()
	rect.texture = UITheme.vertical_gradient(Color("dce8f2"), Color("aebfd0"))
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(rect)
