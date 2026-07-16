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
## Duration of one cell-to-cell hop when the pawn steps (seconds). Snappy but readable.
const _STEP_TIME := 0.16
## Height of the little arc the figure makes mid-step (world units).
const _HOP_HEIGHT := 0.35

var _move_tween: Tween
## Radius of the chip, in world units — nearly fills the cell (its inscribed circle radius is ~0.87).
const CHIP_RADIUS := 0.82
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
		_build_figure(pawn.definition.color, pawn.definition.shape_kind)
	else:
		_build_token(pawn.definition.texture, pawn.definition.display_name)
	pawn.placed.connect(_on_pawn_placed)
	pawn.moved.connect(_on_pawn_moved)
	if pawn.is_placed:
		_move_to_cell(pawn.position)


# Builds the cotransporter figure, tinted [param color]. Under the fixed nadir top-down camera
# (main.gd, rotation -90° on X), only the shape's FOOTPRINT reads — not its height — so [param
# shape_kind] (a PlayerColor.Kind, -1 falls back to the classic cone) picks silhouettes that stay
# distinct from directly above: circle (cone), square, diamond (a square rotated 45°) and ring —
# never two shapes that would both project to a plain circle. Colorblind accessibility: identity
# must not depend on color alone.
func _build_figure(color: Color, shape_kind: int = -1) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	match shape_kind:
		PlayerColor.Kind.RED:
			_build_square_body(material)
		PlayerColor.Kind.PURPLE:
			_build_diamond_body(material)
		PlayerColor.Kind.YELLOW:
			_build_ring_body(material)
		_:
			_build_cone_body(material)  # BLUE, and any unset/demo shape (-1)
	_add_head(material)


func _build_cone_body(material: StandardMaterial3D) -> void:
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


func _build_square_body(material: StandardMaterial3D) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var side := _CONE_BOTTOM_RADIUS * 1.5
	box.size = Vector3(side, _CONE_HEIGHT * 0.82, side)
	body.mesh = box
	body.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	body.material_override = material
	add_child(body)


func _build_diamond_body(material: StandardMaterial3D) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var side := _CONE_BOTTOM_RADIUS * 1.5
	box.size = Vector3(side, _CONE_HEIGHT * 0.82, side)
	body.mesh = box
	body.rotation_degrees = Vector3(0, 45, 0)  # a square rotated 45°, distinct from the plain square
	body.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	body.material_override = material
	add_child(body)


func _build_ring_body(material: StandardMaterial3D) -> void:
	var body := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = _CONE_TOP_RADIUS
	torus.outer_radius = _CONE_BOTTOM_RADIUS * 1.15
	torus.ring_segments = 24
	torus.rings = 24
	body.mesh = torus  # lies flat by default: an annulus from directly above (hollow center)
	body.position = Vector3(0.0, _CONE_HEIGHT * 0.32, 0.0)
	body.material_override = material
	add_child(body)


# The small ball "head" every figure carries on top, for a consistent silhouette family.
func _add_head(material: StandardMaterial3D) -> void:
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _HEAD_RADIUS
	sphere.height = _HEAD_RADIUS * 2.0
	head.mesh = sphere
	head.position = Vector3(0.0, _CONE_HEIGHT + _HEAD_RADIUS * 0.45, 0.0)
	head.material_override = material
	add_child(head)


# Builds the chip body plus, if any, the image plane on top. Without a texture (no illustrator art
# yet for this enseigne/destinataire), falls back to a chip tinted from [param display_name]'s own
# hash plus its initials in a flat top-down label — "couleur + nom" per CLAUDE.md's i18n/art-gap
# notes — instead of every undressed drive/recipient reading as the exact same blank grey disc.
func _build_token(texture: Texture2D, display_name: String = "") -> void:
	var chip := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = CHIP_RADIUS
	body.bottom_radius = CHIP_RADIUS
	body.height = CHIP_HEIGHT
	body.radial_segments = 48  # high enough to read as a smooth round disc
	chip.mesh = body
	var chip_material := StandardMaterial3D.new()
	var fallback_color := _identity_color(display_name)
	chip_material.albedo_color = CHIP_COLOR if texture != null else fallback_color
	chip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if texture == null else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	chip.material_override = chip_material
	add_child(chip)

	if texture != null:
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
		return

	if display_name.is_empty():
		return
	var label := Label3D.new()
	label.text = _initials(display_name)
	label.font_size = 220
	label.pixel_size = 0.0065
	label.modulate = Color.BLACK if fallback_color.get_luminance() > 0.5 else Color.WHITE
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED  # flat on the chip, readable under the fixed top-down camera
	label.shaded = false
	label.position = Vector3(0.0, CHIP_HEIGHT * 0.5 + 0.02, 0.0)
	label.rotation_degrees = Vector3(-90, 0, 0)
	add_child(label)


## A stable color derived from [param name]'s hash — distinct-enough placeholder identities for
## drives/recipients before real art exists, without needing per-entity authored colors.
static func _identity_color(name: String) -> Color:
	if name.is_empty():
		return CHIP_COLOR
	var hue := float(hash(name) % 360) / 360.0
	return Color.from_hsv(hue, 0.55, 0.88)


const _INITIALS_SKIP_WORDS := ["le", "la", "les", "l'", "au", "aux", "du", "de", "des", "d'"]

## Up to two initials from [param name]'s meaningful words (short French articles skipped), e.g.
## "Le Fournil d'Hector" -> "FD". Falls back to the raw first letters if every word is skipped.
static func _initials(name: String) -> String:
	var all_words := name.split(" ", false)
	var words: Array = []
	for w in all_words:
		if not (w.to_lower() in _INITIALS_SKIP_WORDS):
			words.append(w)
	if words.is_empty():
		words = all_words
	var result := ""
	for w in words:
		if w.is_empty():
			continue
		result += w.substr(0, 1).to_upper()
		if result.length() >= 2:
			break
	return result


func _on_pawn_placed(cell: Vector2i) -> void:
	_move_to_cell(cell)  # placement / teleport: snap, no animation


func _on_pawn_moved(_from: Vector2i, to: Vector2i) -> void:
	_animate_to_cell(to)


# The world position of the centre of [param cell], at the figure's resting height.
func _cell_position(cell: Vector2i) -> Vector3:
	var ground := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	return ground + Vector3(0.0, GameConfig.TILE_HEIGHT * 0.5 + SPRITE_LIFT, 0.0)


func _move_to_cell(cell: Vector2i) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	position = _cell_position(cell)


# Slides the figure to [param cell] with a small hop, so steps read as movement rather than teleports.
# Snaps if the view is not in the tree yet (e.g. during initial binding).
func _animate_to_cell(cell: Vector2i) -> void:
	var target := _cell_position(cell)
	if not is_inside_tree():
		position = target
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var apex := position.lerp(target, 0.5) + Vector3(0.0, _HOP_HEIGHT, 0.0)
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "position", apex, _STEP_TIME * 0.5)
	_move_tween.tween_property(self, "position", target, _STEP_TIME * 0.5).set_ease(Tween.EASE_IN)
