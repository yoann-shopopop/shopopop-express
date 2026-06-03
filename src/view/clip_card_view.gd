class_name ClipCardView
extends Node3D
## 3D view of one delivery as a compact card: a dark opaque backing (so it reads over the busy board
## and groups as one unit), the enseigne (left: logo + name) and destinataire (right: portrait + name)
## side by side, and a status banner across the top — tinted with the reserving player's color — once
## the delivery leaves DISPONIBLE. Flat on the XZ plane for the top-down camera. Rebuilt via
## [method bind] / [method bind_delivery] / [method refresh].

const CARD := Vector2(2.2, 1.5)        # width, depth of an enseigne/destinataire slab
const GAP := 0.12                      # gap between the two slabs
const STATUS_H := 0.55                 # depth of the status banner along the top
const PAD := 0.20                      # backing margin around the slabs
const THICK := 0.08
const IMG_FRAC := 0.62                 # image square as a fraction of the slab depth
const _NEUTRAL := Color("232838")
const _BACKING := Color(0.11, 0.13, 0.19, 0.98)
const _SOFT_BASE := Color("1b2030")    # raw brand colors are muted toward this calm slate

var _enseigne: EnseigneDefinition
var _destinataire: DestinataireDefinition
var _status: int = DeliveryStatus.Kind.DISPONIBLE
var _reserve_color: Color = _NEUTRAL
var _insert: Node3D = null
var _card_w: float = 0.0


## Builds (or rebuilds) the view for [param combo] (demo path).
func bind(combo: DeliveryCombo) -> void:
	_build(combo.enseigne, combo.destinataire, combo.status, _NEUTRAL)


## Builds (or rebuilds) the view for a spatial [Delivery] (game path). [param reserve_color] tints the
## status banner with the reserving player's color.
func bind_delivery(delivery: Delivery, reserve_color: Color = _NEUTRAL) -> void:
	_build(delivery.enseigne, delivery.destinataire, delivery.status, reserve_color)


func _build(enseigne: EnseigneDefinition, destinataire: DestinataireDefinition, status: int,
		reserve_color: Color) -> void:
	_enseigne = enseigne
	_destinataire = destinataire
	_status = status
	_reserve_color = reserve_color
	for child in get_children():
		child.queue_free()
	_insert = null

	var step := CARD.x * 0.5 + GAP * 0.5
	_card_w = step * 2.0 + CARD.x
	# Dark opaque backing behind everything (contrast over the board + groups the card).
	add_child(_make_slab(Vector3(0.0, -0.03, 0.0),
		Vector2(_card_w + PAD * 2.0, CARD.y + PAD * 2.0), _BACKING))
	_add_card(Vector3(-step, 0.0, 0.0), enseigne.color, enseigne.display_name, enseigne.texture)
	var dest_color: Color = destinataire.color if destinataire else Color("33384a")
	var dest_name: String = destinataire.display_name if destinataire else "(vide)"
	var dest_tex: Texture2D = destinataire.texture if destinataire else null
	_add_card(Vector3(step, 0.0, 0.0), dest_color, dest_name, dest_tex)
	refresh()


## Updates the status banner to match the current status (hidden while DISPONIBLE).
func refresh() -> void:
	if _insert != null:
		_insert.queue_free()
		_insert = null
	if _status == DeliveryStatus.Kind.DISPONIBLE:
		return
	# Colored banner across the top edge of the card, in the reserving player's color.
	var z := -(CARD.y * 0.5) + STATUS_H * 0.5
	_insert = _make_slab(Vector3(0.0, 0.05, z), Vector2(_card_w + PAD * 1.4, STATUS_H), _reserve_color)
	var text_color := Color.BLACK if _reserve_color.get_luminance() > 0.5 else Color.WHITE
	var label := _make_label(DeliveryStatus.label(_status), text_color, _card_w, 44)
	label.position = Vector3(0.0, THICK * 0.5 + 0.012, 0.0)
	_insert.add_child(label)
	add_child(_insert)


## True when a status banner is currently shown (test hook / clarity).
func has_status_insert() -> bool:
	return _insert != null


# One slab (enseigne or destinataire): image on the left, name on the right.
func _add_card(at: Vector3, color: Color, label_text: String, texture: Texture2D) -> void:
	var slab := _make_slab(at, CARD, _soften(color))
	if texture != null:
		slab.add_child(_make_image(texture))
	var label := _make_label(label_text, Color.WHITE, CARD.x * 0.52, 46)
	label.position = Vector3(CARD.x * 0.22, THICK * 0.5 + 0.006, 0.0)  # right of the image
	slab.add_child(label)
	add_child(slab)


# Mutes a raw brand color toward a deep slate, so saturated logos/portraits read calmly behind the
# white name and the card feels cohesive rather than garish.
func _soften(color: Color) -> Color:
	return color.lerp(_SOFT_BASE, 0.58)


func _make_slab(at: Vector3, size: Vector2, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, THICK, size.y)
	inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	inst.position = at
	return inst


func _make_image(texture: Texture2D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var s := CARD.y * IMG_FRAC
	plane.size = Vector2(s, s)
	inst.mesh = plane
	inst.position = Vector3(-CARD.x * 0.5 + s * 0.5 + 0.08, THICK * 0.5 + 0.004, 0.0)  # left, inset
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	inst.material_override = mat
	return inst


# A flat name label. [param wrap_world] is the wrap width in world units; [param font] the font size.
func _make_label(text: String, color: Color, wrap_world: float, font: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font
	label.pixel_size = 0.0075
	label.width = int(wrap_world / label.pixel_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Heavy contrasting outline so the name stays legible over any softened slab tint.
	label.outline_size = 11
	label.outline_modulate = Color(0, 0, 0, 0.8) if color.get_luminance() > 0.5 else Color(1, 1, 1, 0.55)
	label.modulate = color
	label.rotation_degrees = Vector3(-90, 0, 0)
	return label
