class_name CardBackFace
extends PanelContainer
## The 2D back of an event card — the Shopopop Express emblem over the dobo_ui pack's card-back art
## (task: "dobo_ui" integration), with an "ÉVÉNEMENT" caption. Rendered off-screen into a texture
## (like [EventCardFace]) and applied to the [CardView] back. Shared by all event cards.

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
	# No StyleBox background here — the dobo_ui card art below already bakes in the frame/border/
	# corners; an empty override keeps PanelContainer's default theme panel from drawing underneath it.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var bg := TextureRect.new()
	bg.texture = UITheme.card_texture()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED, not a StyleBoxTexture stretch: the source art's aspect (285:429) is close to but not
	# identical to SIZE's (384:538) — COVERED crops evenly instead of distorting the art to fit exactly.
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
