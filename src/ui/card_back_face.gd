class_name CardBackFace
extends PanelContainer
## The 2D back of an event card — the Shopopop Express emblem on a branded panel with an "ÉVÉNEMENT"
## caption. Rendered off-screen into a texture (like [EventCardFace]) and applied to the [CardView]
## back, replacing the old placeholder logo + "CARD_TYPE" label. Shared by all event cards.

const SIZE := Vector2i(384, 538)   # ~1 : 1.4, matching CardView WIDTH:HEIGHT
const _LOGO := "res://assets/logo/logo_shopopop_express.png"


## Renders the shared back texture using an off-screen SubViewport parented to [param host].
static func build_texture(host: Node) -> ViewportTexture:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var back := CardBackFace.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(back)
	back.populate()
	return vp.get_texture()


func populate() -> void:
	var sb := UITheme.panel_card(Color("1b2436"))
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(6)
	sb.border_color = UITheme.BLUE
	sb.set_content_margin_all(26)
	add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	add_child(col)

	var logo := TextureRect.new()
	logo.texture = load(_LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(300, 240)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)

	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.make_title(caption, 34, UITheme.ORANGE)
	caption.text = tr("ÉVÉNEMENT")
	col.add_child(caption)
