class_name CardView
extends Node3D
## Minimal 3D view of a single card: a thin slab with a placeholder front and a shared back
## (logo + "CARD_TYPE"). Flip it with [method set_face_up]. Pure rendering, no game logic.

const WIDTH := 1.0
const HEIGHT := 1.4
const THICKNESS := 0.06
## Radius used by the demo for mouse picking (treats the card as a sphere).
const PICK_RADIUS := 0.85

const _LOGO := preload("res://assets/logo/logo_shopopop_express.png")
const _BODY_COLOR := Color("f5f5f0")
const _FRONT_PLACEHOLDER := Color("cfe3ff")

const _DEAL_TIME := 0.5
const _DEAL_ARC_HEIGHT := 1.6
const _SLIDE_TIME := 0.35


## Builds the card meshes for [param card]. The front uses the card's placeholder art (or a flat
## color when none); the back is the shared logo + "CARD_TYPE".
func bind(card: CardDefinition) -> void:
	_build_body()
	_build_front(card.front_texture)
	_build_front_label(card.display_name)
	_build_back()


## Face up (front on top) or face down (back/logo on top).
func set_face_up(up: bool) -> void:
	rotation_degrees.x = 0.0 if up else 180.0


## Deals the card: it lifts off the pile in an arc and flips face up on the way to [param target].
## [param delay] staggers several cards dealt together. Must already be in the tree, face down.
func animate_deal(target: Vector3, delay: float = 0.0) -> void:
	set_face_up(false)
	var start := position
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_arc_to.bind(start, target), 0.0, 1.0, _DEAL_TIME) \
		.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:x", 0.0, _DEAL_TIME) \
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Smoothly slides the card to [param target] (e.g. the active slot).
func animate_move_to(target: Vector3) -> void:
	create_tween().tween_property(self, "position", target, _SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A quick "power fires" pop on the card. Awaitable — resolves when the pop finishes.
func animate_activate() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.2, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Flies the card back toward the draw pile in an arc, flipping face down (for a reshuffle).
func animate_gather(target: Vector3, delay: float = 0.0) -> void:
	var start := position
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_arc_to.bind(start, target), 0.0, 1.0, _SLIDE_TIME) \
		.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:x", 180.0, _SLIDE_TIME).set_delay(delay)


## Slides the card to [param target] face down, then frees it (e.g. onto the discard pile).
func animate_discard(target: Vector3) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", target, _SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees:x", 180.0, _SLIDE_TIME)
	tween.chain().tween_callback(queue_free)


func _arc_to(t: float, start: Vector3, target: Vector3) -> void:
	var p := start.lerp(target, t)
	p.y += sin(t * PI) * _DEAL_ARC_HEIGHT
	position = p


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


func _build_front_label(text: String) -> void:
	if text.is_empty():
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0028
	label.width = 360
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color("20242c")
	label.position = Vector3(0.0, THICKNESS * 0.5 + 0.006, 0.0)
	label.rotation_degrees = Vector3(-90, 0, 0)  # lie flat on the front face, readable from above
	add_child(label)


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
