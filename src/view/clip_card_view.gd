class_name ClipCardView
extends Node3D
## 3D view of one delivery combo: the enseigne (left, with its brand logo), an optional status insert
## (center, hidden while DISPONIBLE), and the destinataire (right, name + banner color). Flat slabs laid
## on the XZ plane so they read under the top-down/orbit camera. Pure rendering — rebuilt via [method
## bind]/[method refresh]; the demo handles input.

const CARD := Vector2(2.0, 1.2)   # width, depth of an enseigne/destinataire slab
const INSERT := Vector2(0.7, 0.9)
const GAP := 0.08
const THICK := 0.08

var _combo: DeliveryCombo
var _insert: Node3D = null


## Builds (or rebuilds) the view for [param combo].
func bind(combo: DeliveryCombo) -> void:
	_combo = combo
	for child in get_children():
		child.queue_free()
	_insert = null
	var step := CARD.x * 0.5 + INSERT.x * 0.5 + GAP
	_add_card(Vector3(-step, 0.0, 0.0), CARD, combo.enseigne.color,
		combo.enseigne.display_name, combo.enseigne.texture)
	var dest_color: Color = combo.destinataire.color if combo.destinataire else Color("33384a")
	var dest_name: String = combo.destinataire.display_name if combo.destinataire else "(vide)"
	var dest_tex: Texture2D = combo.destinataire.texture if combo.destinataire else null
	_add_card(Vector3(step, 0.0, 0.0), CARD, dest_color, dest_name, dest_tex)
	refresh()


## Updates the status insert to match the combo's current status.
func refresh() -> void:
	if _insert != null:
		_insert.queue_free()
		_insert = null
	if _combo == null or _combo.is_available():
		return
	_insert = _make_slab(Vector3.ZERO, INSERT, Color("20242c"))
	_insert.add_child(_make_label(DeliveryStatus.label(_combo.status), Color.WHITE, INSERT.x))
	add_child(_insert)


## True when a status insert is currently shown (test hook / clarity).
func has_status_insert() -> bool:
	return _insert != null


func _add_card(at: Vector3, size: Vector2, color: Color, label_text: String, texture: Texture2D) -> void:
	var slab := _make_slab(at, size, color)
	if texture != null:
		slab.add_child(_make_image(texture, size))
	slab.add_child(_make_label(label_text, Color("101218"), size.x * 0.9))
	add_child(slab)


func _make_slab(at: Vector3, size: Vector2, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, THICK, size.y)
	inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	inst.material_override = mat
	inst.position = at
	return inst


func _make_image(texture: Texture2D, size: Vector2) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * 0.4, size.x * 0.4)
	inst.mesh = plane
	inst.position = Vector3(-size.x * 0.28, THICK * 0.5 + 0.004, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	inst.material_override = mat
	return inst


func _make_label(text: String, color: Color, width: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0026
	label.width = 420
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = color
	label.position = Vector3(width * 0.12, THICK * 0.5 + 0.006, 0.0)
	label.rotation_degrees = Vector3(-90, 0, 0)
	return label
