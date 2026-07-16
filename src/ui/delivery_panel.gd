class_name DeliveryPanel
extends Control
## The left HUD column: every delivery as a crisp 2D card — enseigne logo → destinataire medallion, the
## brand name and a coloured status pill, with a left accent bar in the reserving player's colour. A
## ScrollContainer makes ALL of them reachable. Replaces the old 3D ClipCardView list (which rendered
## Label3D slabs scaled by the camera zoom, capped at 4 rows). Pure rendering: built once, re-read on
## status change. Cards are sorted so the actionable ones (en cours / réservé) sit on top.

## Hovering a card: GameRoot highlights that delivery's drive/recipient cells on the board. Since
## the cross-tile pairing can put them far apart with nothing on-card to show WHERE they are, this
## is the cheapest way to answer "where is this delivery" without a click.
signal delivery_hovered(delivery: Delivery)
signal delivery_unhovered(delivery: Delivery)

const WIDTH := 318
const IMG := 50                       # logo / medallion square (px)
const _DISPONIBLE := Color("3a9d5b")  # calm green
const _EN_COURS := Color("f2c037")    # bright amber
const _NEUTRAL_ACCENT := Color("39414f")

var _deliveries: Array[Delivery] = []
var _players: Array[Player] = []
var _current_index: int = -1
var _remaining: int = 0
var _header: Label
var _list: VBoxContainer
var _upcoming_row: HBoxContainer  # "À venir" preview of the next recycled recipients (peek_upcoming)


func _ready() -> void:
	# Left strip, under the top bar, near full height.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 12
	offset_right = 12 + WIDTH
	offset_top = 50
	offset_bottom = -12

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UITheme.panel_card())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_header = Label.new()
	UITheme.make_title(_header, 20)
	box.add_child(_header)

	_upcoming_row = HBoxContainer.new()
	_upcoming_row.add_theme_constant_override("separation", 6)
	_upcoming_row.hide()  # only shown once set_upcoming has something to preview (recycling generator)
	box.add_child(_upcoming_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_update_header()


## Builds the cards once from [param deliveries]; [param players] resolves reserving colours.
func build(deliveries: Array[Delivery], players: Array[Player]) -> void:
	_deliveries = deliveries
	_players = players
	refresh()


## The seat index whose in-flight deliveries to highlight (the current player). Rebuilds only on an
## actual change — _refresh_ui calls this every step, and a rebuild would reset the scroll position.
func set_current_player(index: int) -> void:
	if index == _current_index:
		return
	_current_index = index
	refresh()


## Updates the "N restantes" counter shown in the header.
func set_remaining(count: int) -> void:
	_remaining = count
	_update_header()


## Previews the next [param destinataires] due to recycle onto a drive (in draw order) — "file des
## prochaines livraisons" for La Tournée's recycling pool. Hidden when empty (a session with no
## recycling generator, or the pool exhausted).
func set_upcoming(destinataires: Array[DestinataireDefinition]) -> void:
	if _upcoming_row == null:
		return
	for child in _upcoming_row.get_children():
		child.queue_free()
	if destinataires.is_empty():
		_upcoming_row.hide()
		return
	_upcoming_row.show()
	var label := Label.new()
	label.text = tr("À venir :")
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UITheme.TEXT.darkened(0.15))
	_upcoming_row.add_child(label)
	for d in destinataires:
		_upcoming_row.add_child(_image_chip(d.texture, 8, d.display_name))


## Rebuilds the cards, re-reading every delivery's status and re-sorting (actionable first).
func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	for i in _sorted_indices():
		_list.add_child(_make_card(_deliveries[i]))
	_update_header()


func _update_header() -> void:
	if _header != null:
		_header.text = tr("Livraisons · %d restantes") % _remaining


# Visible deliveries (those still carrying a recipient or in flight), ordered: en cours, réservé,
# disponible. Empty/exhausted drives are dropped — the header counter still reflects the total.
func _sorted_indices() -> Array:
	var shown: Array = []
	for i in _deliveries.size():
		var d := _deliveries[i]
		if d.destinataire != null or d.status != DeliveryStatus.Kind.DISPONIBLE:
			shown.append(i)
	shown.sort_custom(func(a: int, b: int) -> bool:
		return _rank(_deliveries[a]) < _rank(_deliveries[b]))
	return shown


func _rank(delivery: Delivery) -> int:
	match delivery.status:
		DeliveryStatus.Kind.EN_COURS:
			return 0
		DeliveryStatus.Kind.RESERVE:
			return 1
		_:
			return 2


func _make_card(delivery: Delivery) -> Control:
	var card := PanelContainer.new()
	var mine := delivery.reserved_by == _current_index and _current_index >= 0 \
		and delivery.status != DeliveryStatus.Kind.DISPONIBLE
	card.add_theme_stylebox_override("panel", UITheme.panel_card(Color("28303f") if mine else Color("212734")))
	card.mouse_entered.connect(func() -> void: delivery_hovered.emit(delivery))
	card.mouse_exited.connect(func() -> void: delivery_unhovered.emit(delivery))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(5, 0)
	accent.color = _accent_color(delivery)
	row.add_child(accent)

	var enseigne_name := delivery.enseigne.display_name if delivery.enseigne else ""
	row.add_child(_image_chip(delivery.enseigne.texture if delivery.enseigne else null, 8, enseigne_name))

	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 22)
	arrow.add_theme_color_override("font_color", UITheme.PANEL_BORDER)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)

	var dest_tex: Texture2D = delivery.destinataire.texture if delivery.destinataire else null
	var dest_name := delivery.destinataire.display_name if delivery.destinataire else ""
	row.add_child(_image_chip(dest_tex, IMG / 2, dest_name))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var name_label := Label.new()
	name_label.text = delivery.enseigne.display_name if delivery.enseigne else "?"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UITheme.TEXT)
	name_label.clip_text = true
	col.add_child(name_label)

	col.add_child(_status_pill(delivery))
	return card


const _CHIP_FALLBACK_BG := Color("11141c")

# A fixed-size chip holding an image, corner radius [param radius] (use IMG/2 for a round medallion).
# Without [param texture] (no illustrator art yet), falls back to a chip tinted from [param entity_name]
# plus its initials — same "couleur + nom" placeholder as the 3D board tokens (IdentityFallback) —
# instead of an identical dark, imageless void for every enseigne/destinataire.
func _image_chip(texture: Texture2D, radius: int, entity_name: String = "") -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(IMG, IMG)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg_color := _CHIP_FALLBACK_BG if texture != null else IdentityFallback.color(entity_name, _CHIP_FALLBACK_BG)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(0)
	if texture == null and not entity_name.is_empty():
		# A faint top-light bevel — same "badge" treatment as UITheme.button_style — so the fallback
		# chip reads as a designed badge rather than a flat paint swatch next to real logo art.
		sb.border_width_top = 2
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 1)
	holder.add_theme_stylebox_override("panel", sb)
	holder.clip_contents = true
	if texture != null:
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(IMG, IMG)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.texture = texture
		holder.add_child(tex)
	elif not entity_name.is_empty():
		var label := Label.new()
		label.text = IdentityFallback.initials(entity_name)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color.BLACK if bg_color.get_luminance() > 0.5 else Color.WHITE)
		holder.add_child(label)
	return holder


func _status_pill(delivery: Delivery) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var color := _status_color(delivery)
	pill.add_theme_stylebox_override("panel", UITheme.status_pill(color))
	var label := Label.new()
	label.text = _status_text(delivery)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE)
	pill.add_child(label)
	return pill


func _status_text(delivery: Delivery) -> String:
	# The icon doubles the status color (colorblind accessibility): ● dispo / ◐ réservé / ▶ en cours.
	var base := "%s %s" % [DeliveryStatus.icon(delivery.status), DeliveryStatus.label(delivery.status)]
	if delivery.status == DeliveryStatus.Kind.RESERVE or delivery.status == DeliveryStatus.Kind.EN_COURS:
		if delivery.reserved_by >= 0 and delivery.reserved_by < _players.size():
			return "%s · %s" % [base, PlayerColor.name_of(_players[delivery.reserved_by].color)]
	return base


func _status_color(delivery: Delivery) -> Color:
	match delivery.status:
		DeliveryStatus.Kind.EN_COURS:
			return _EN_COURS
		DeliveryStatus.Kind.RESERVE:
			return _reserve_color(delivery)
		DeliveryStatus.Kind.LIVREE:
			return _NEUTRAL_ACCENT
		_:
			return _DISPONIBLE


func _accent_color(delivery: Delivery) -> Color:
	if delivery.status == DeliveryStatus.Kind.RESERVE or delivery.status == DeliveryStatus.Kind.EN_COURS:
		return _reserve_color(delivery)
	return _NEUTRAL_ACCENT


func _reserve_color(delivery: Delivery) -> Color:
	if delivery.reserved_by < 0 or delivery.reserved_by >= _players.size():
		return _NEUTRAL_ACCENT
	return PlayerColor.to_color(_players[delivery.reserved_by].color)
