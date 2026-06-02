class_name PawnView
extends Node3D
## Top-down 3D view of a single [Pawn]. A cotransporter shows the classic board-game figure (a
## tapered cone with a ball head) tinted with the player color; a fixed pawn (drive/recipient) shows
## a flat poker-chip token carrying its shop image.
##
## Pure rendering — it listens to the pawn's signals and reads its identity, but never mutates
## state. Same pattern as [HexGridView], which reacts to [signal Board.changed].

## Extra height above the tile surface so the token never z-fights with the board.
const SPRITE_LIFT := 0.1
## Radius of the chip, in world units (a bit under the hexagon circumradius of 1.0).
const CHIP_RADIUS := 0.55
## Thickness of the chip — enough relief to read as a token under the top-down light.
const CHIP_HEIGHT := 0.18
## Neutral chip body color; the image on top carries the identity.
const CHIP_COLOR := Color("ececf0")

# Classic pawn figure (cotransporter): a tapered cone body topped by a ball head.
const _CONE_BOTTOM_RADIUS := 0.42
const _CONE_TOP_RADIUS := 0.14
const _CONE_HEIGHT := 0.82
const _HEAD_RADIUS := 0.3

# Spatial shader for the top face: samples the image but discards fragments outside the inscribed
# circle, so a square texture fills the round chip instead of overflowing its corners.
const _FACE_SHADER_CODE := "shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D image : source_color, filter_linear_mipmap;
void fragment() {
	vec2 d = UV - vec2(0.5);
	if (dot(d, d) > 0.25) { discard; }
	vec4 c = texture(image, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}"


## Binds this view to [param pawn]: builds its figure and follows its position via signals.
func bind(pawn: Pawn) -> void:
	if pawn.definition.is_mobile():
		_build_figure(pawn.definition.color)
	else:
		_build_token(pawn.definition.texture)
	pawn.placed.connect(_on_pawn_placed)
	pawn.moved.connect(_on_pawn_moved)
	if pawn.is_placed:
		_move_to_cell(pawn.position)


# Builds the classic pawn: a tapered cone body and a ball head, tinted [param color].
func _build_figure(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7

	var body := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.bottom_radius = _CONE_BOTTOM_RADIUS
	cone.top_radius = _CONE_TOP_RADIUS
	cone.height = _CONE_HEIGHT
	cone.radial_segments = 24
	body.mesh = cone
	body.position = Vector3(0.0, _CONE_HEIGHT * 0.5, 0.0)  # base sits on the tile
	body.material_override = material
	add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _HEAD_RADIUS
	sphere.height = _HEAD_RADIUS * 2.0
	head.mesh = sphere
	head.position = Vector3(0.0, _CONE_HEIGHT + _HEAD_RADIUS * 0.45, 0.0)
	head.material_override = material
	add_child(head)


# Builds the chip body plus, if any, the image plane on top.
func _build_token(texture: Texture2D) -> void:
	var chip := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = CHIP_RADIUS
	body.bottom_radius = CHIP_RADIUS
	body.height = CHIP_HEIGHT
	body.radial_segments = 48  # high enough to read as a smooth round disc
	chip.mesh = body
	var chip_material := StandardMaterial3D.new()
	chip_material.albedo_color = CHIP_COLOR
	chip.material_override = chip_material
	add_child(chip)

	if texture == null:
		return
	var face := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var diameter := CHIP_RADIUS * 2.0 * 0.98  # circle matches the rim, with a thin chip border
	plane.size = Vector2(diameter, diameter)
	face.mesh = plane
	face.position = Vector3(0.0, CHIP_HEIGHT * 0.5 + 0.01, 0.0)  # just above the top face
	var shader := Shader.new()
	shader.code = _FACE_SHADER_CODE
	var face_material := ShaderMaterial.new()
	face_material.shader = shader
	face_material.set_shader_parameter("image", texture)
	face.material_override = face_material
	add_child(face)


func _on_pawn_placed(cell: Vector2i) -> void:
	_move_to_cell(cell)


func _on_pawn_moved(_from: Vector2i, to: Vector2i) -> void:
	_move_to_cell(to)


func _move_to_cell(cell: Vector2i) -> void:
	var ground := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	position = ground + Vector3(0.0, GameConfig.TILE_HEIGHT * 0.5 + SPRITE_LIFT, 0.0)
