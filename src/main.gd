extends Node3D
## Composition root for the placement prototype.
## Builds the orthographic top-down view, wires the board model to its view, the pointer
## controller and the UI. Everything it assembles is an independently-testable component.

const HEX_BLOCK := preload("res://resources/blocks/hex19.tres")
const BRIDGE_BLOCK := preload("res://resources/blocks/bridge3.tres")

var board: Board
var controller: PlacementController


func _ready() -> void:
	board = Board.new()
	var blocks: Array[BlockDefinition] = [HEX_BLOCK, BRIDGE_BLOCK]
	var palette := {}
	for block in blocks:
		palette[block.id] = block.color

	var camera := _build_camera()
	_build_light()
	_build_environment()

	var grid_view := HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, palette)

	var ghost := BlockGhost.new()
	add_child(ghost)

	controller = PlacementController.new()
	add_child(controller)
	controller.setup(camera, board, ghost)
	controller.select_block(HEX_BLOCK)

	_build_ui(blocks)


func _build_camera() -> CameraRig:
	var camera := CameraRig.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
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


func _build_ui(blocks: Array[BlockDefinition]) -> void:
	var ui := PlacementUI.new()
	add_child(ui)
	var entries: Array = []
	for block in blocks:
		entries.append({"id": block.id, "label": block.display_name})
	ui.build(entries)
	ui.set_active_block(HEX_BLOCK.id)
	ui.block_chosen.connect(_on_block_chosen)
	ui.rotate_requested.connect(controller.rotate_current)


func _on_block_chosen(id: StringName) -> void:
	match id:
		&"hex19":
			controller.select_block(HEX_BLOCK)
		&"bridge3":
			controller.select_block(BRIDGE_BLOCK)
