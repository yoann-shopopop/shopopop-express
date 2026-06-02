class_name TilePreview
extends RefCounted
## Renders a block to a small texture for the UI: a transparent SubViewport with a top-down ortho
## camera and the block's real tiles. The SubViewport is parented to [param host] (must be in the
## scene tree) and its [ViewportTexture] is returned.

const SIZE := 128
const CAM_SIZE := 8.0


static func build(block: BlockDefinition, host: Node) -> ViewportTexture:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true  # isolate from the board world so preview tiles don't leak onto the board
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.position = Vector3(0, 10, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	vp.add_child(cam)

	var typed := block.get_typed_cells(Vector2i.ZERO, 0)
	var road_cells := TileSprite.road_cells_of(typed)
	for i in typed.size():
		var tc: Dictionary = typed[i]
		vp.add_child(TileSprite.make(tc["cell"], tc["type"], road_cells, 1.0, block.cells[i]))

	return vp.get_texture()
