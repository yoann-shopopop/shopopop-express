class_name CardView
extends Node3D
## Minimal 3D view of a single card: a thin slab with a placeholder front and a shared back
## (logo + "CARD_TYPE"). Flip it with [method set_face_up]. Pure rendering, no game logic.

const WIDTH := 1.0
const HEIGHT := 1.4
const THICKNESS := 0.06
## Radius used by the demo for mouse picking (treats the card as a sphere).
const PICK_RADIUS := 0.85

const _LOGO := preload("res://assets/logo/LOGO-SHOPOPOP-EXPRESS.png")
const _BODY_COLOR := Color("f5f5f0")
const _FRONT_PLACEHOLDER := Color("cfe3ff")


## Builds the card meshes for [param card]. The front uses the card's placeholder art (or a flat
## color when none); the back is the shared logo + "CARD_TYPE".
func bind(card: CardDefinition) -> void:
	_build_body()
	_build_front(card.front_texture)
	_build_back()


## Face up (front on top) or face down (back/logo on top).
func set_face_up(up: bool) -> void:
	rotation_degrees.x = 0.0 if up else 180.0


func _build_body() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, THICKNESS, HEIGHT)
	body.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = _BODY_COLOR
	body.material_override = material
	add_child(body)


func _build_front(texture: Texture2D) -> void:
	var front := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH * 0.92, HEIGHT * 0.92)
	front.mesh = plane
	front.position = Vector3(0.0, THICKNESS * 0.5 + 0.004, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if texture != null:
		material.albedo_texture = texture
	else:
		material.albedo_color = _FRONT_PLACEHOLDER
	front.material_override = material
	add_child(front)


func _build_back() -> void:
	# Logo on the underside (normal -Y), so it reads as the top face once the card is flipped down.
	var logo := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH * 0.66, WIDTH * 0.66)
	logo.mesh = plane
	logo.position = Vector3(0.0, -THICKNESS * 0.5 - 0.004, -HEIGHT * 0.16)
	logo.rotation_degrees = Vector3(180, 0, 0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _LOGO
	logo.material_override = material
	add_child(logo)

	var label := Label3D.new()
	label.text = "CARD_TYPE"
	label.font_size = 72
	label.pixel_size = 0.004
	label.modulate = Color("20242c")
	label.position = Vector3(0.0, -THICKNESS * 0.5 - 0.005, HEIGHT * 0.30)
	label.rotation_degrees = Vector3(-90, 180, 0)  # lie flat on the back, readable once flipped up
	add_child(label)
