class_name DeckPileView
extends Control
## A 2D "deck of cards" pile for the HUD (PIOCHE / DÉFAUSSE), à la Balatro: a top card with a few
## offset layers behind it for thickness + a drop shadow, a round count badge, and a caption. The
## PIOCHE shows a card back (logo); the DÉFAUSSE shows the last discarded card's face (or a dim slot
## when empty). Pure rendering — fed by [PlayHud].

const CARD_W := 104.0
const CARD_H := 146.0
const LAYER_OFFSET := 3.0
const MAX_LAYERS := 5
const _LOGO := preload("res://assets/logo/logo_shopopop_express.png")

var _accent: Color = Color.WHITE
var _caption_text: String = ""
var _is_discard: bool = false
var _count: int = -1
var _stack: Control          # holds the offset layers + the top card (rebuilt on count change)
var _badge: Label
var _face_texture: Texture2D = null
var _face_vp: SubViewport = null  # owns the discard's top-face texture (freed on replace)


## Configures the pile. [param is_discard] switches the top card from a back (PIOCHE) to a face slot.
func setup(caption: String, accent: Color, is_discard: bool) -> void:
	_caption_text = caption
	_accent = accent
	_is_discard = is_discard
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var span := LAYER_OFFSET * (MAX_LAYERS - 1)
	custom_minimum_size = Vector2(CARD_W + span, CARD_H + span + 30.0)

	_stack = Control.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stack)

	var caption_lbl := Label.new()
	caption_lbl.text = _caption_text
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.add_theme_font_size_override("font_size", 16)
	caption_lbl.add_theme_color_override("font_color", UITheme.TEXT)
	caption_lbl.position = Vector2(0.0, CARD_H + span + 6.0)
	caption_lbl.size = Vector2(CARD_W + span, 22.0)
	add_child(caption_lbl)

	_badge = _build_badge()
	add_child(_badge)
	_rebuild(0)


## Sets the number of cards in the pile (drives the badge and the stack thickness).
func set_count(n: int) -> void:
	if n == _count:
		return
	_rebuild(n)


## Shows [param card]'s face on top of the DÉFAUSSE (null clears it). Owns the render viewport.
func set_top_face(card: EventCardDefinition) -> void:
	if _face_vp != null and is_instance_valid(_face_vp):
		_face_vp.queue_free()
	_face_vp = null
	_face_texture = null
	if card != null:
		_face_vp = SubViewport.new()
		_face_vp.size = EventCardFace.SIZE
		_face_vp.transparent_bg = true
		_face_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_face_vp)
		var face := EventCardFace.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_face_vp.add_child(face)
		face.populate(card)
		_face_texture = _face_vp.get_texture()
	_rebuild(maxi(_count, 0))


## The screen-space center of the top card (so flying cards aim at the visible pile).
func top_card_center() -> Vector2:
	return get_global_rect().position + Vector2(CARD_W * 0.5, CARD_H * 0.5)


func _rebuild(n: int) -> void:
	_count = n
	for child in _stack.get_children():
		child.queue_free()
	# Drop shadow behind the whole stack.
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = Vector2(4.0, 5.0)
	shadow.size = Vector2(CARD_W, CARD_H)
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0, 0, 0, 0.35)
	shadow_sb.set_corner_radius_all(10)
	shadow.add_theme_stylebox_override("panel", shadow_sb)
	_stack.add_child(shadow)
	# Offset layers behind the top card (deepest first), more cards = thicker pile.
	var behind := clampi(n - 1, 0, MAX_LAYERS - 1)
	for i in range(behind, 0, -1):
		var layer := Panel.new()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.position = Vector2(i * LAYER_OFFSET, i * LAYER_OFFSET)
		layer.size = Vector2(CARD_W, CARD_H)
		layer.add_theme_stylebox_override("panel", _card_style(false))
		layer.clip_contents = true
		layer.add_child(_card_art())
		_stack.add_child(layer)
	_stack.add_child(_build_top_card(n > 0))
	_badge.text = str(maxi(n, 0))


# The top card: a face (discard, when set) or a back (logo). Dim when the pile is empty.
func _build_top_card(filled: bool) -> Control:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2.ZERO
	card.size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", _card_style(true))
	card.modulate = Color.WHITE if filled else Color(1, 1, 1, 0.4)
	card.clip_contents = true

	if _is_discard and _face_texture != null:
		var face := TextureRect.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.texture = _face_texture
		card.add_child(face)
	else:
		card.add_child(_card_art())
		var logo := TextureRect.new()
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.texture = _LOGO
		card.add_child(logo)
	return card


# The dobo_ui card-back art, full-rect — the same asset [CardBackFace] uses, reused here for every
# card-back layer of the pile (only the DÉFAUSSE's own top face, set via set_top_face, differs).
func _card_art() -> TextureRect:
	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = UITheme.card_texture()
	return art


func _card_style(top: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1b2436")
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2 if top else 1)
	sb.border_color = _accent if top else _accent.darkened(0.4)
	return sb


func _build_badge() -> Label:
	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(34, 34)
	badge.size = Vector2(34, 34)
	badge.position = Vector2(CARD_W - 26.0, CARD_H - 26.0)
	UITheme.make_title(badge, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _accent.darkened(0.1)
	sb.set_corner_radius_all(17)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.shadow_color = UITheme.SHADOW
	sb.shadow_size = 3
	badge.add_theme_stylebox_override("normal", sb)
	badge.text = "0"
	return badge
