class_name EventCardFace
extends PanelContainer
## The 2D face of an event card — Avantage/Malus band, title, the key effect highlighted, and a plain
## description — laid out to FILL its rect. Rendered off-screen into a texture by [method build_texture]
## and applied to the animated 3D [CardView], so the deck's deal/discard animations run with this crisp
## 2D design. (The card stays data-driven: descriptions are derived from effect + amount.)

const E := EventCardDefinition.Effect
const SIZE := Vector2i(384, 538)   # ~1 : 1.4, matching CardView WIDTH:HEIGHT


## Renders a face texture for [param card] using an off-screen SubViewport parented to [param host]
## (must be in the tree). Returns the live [ViewportTexture] — keep [param host] alive while shown.
static func build_texture(card: EventCardDefinition, host: Node) -> ViewportTexture:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var face := EventCardFace.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(face)
	face.populate(card)
	return vp.get_texture()


## Builds the face content for [param card].
func populate(card: EventCardDefinition) -> void:
	var accent := UITheme.RED if card.is_malus else UITheme.GREEN
	var sb := UITheme.panel_card(Color("232a38"))
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(6)
	sb.border_color = accent
	sb.set_content_margin_all(22)
	add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	box.add_child(_pill("MALUS" if card.is_malus else "AVANTAGE", accent, 22))

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_title(name_lbl, 36)
	name_lbl.text = card.display_name
	box.add_child(name_lbl)

	box.add_child(_pill(_headline(card), accent.darkened(0.12), 30))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 23)
	desc.add_theme_color_override("font_color", UITheme.TEXT)
	desc.text = _describe(card)
	box.add_child(desc)

	if card.condition == EventCardDefinition.Condition.VELO:
		var velo := Label.new()
		velo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		velo.add_theme_font_size_override("font_size", 18)
		velo.add_theme_color_override("font_color", UITheme.BLUE)
		velo.text = "À vélo uniquement"
		box.add_child(velo)


func _pill(text: String, color: Color, font_size: int) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UITheme.status_pill(color)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	UITheme.make_title(label, font_size, Color.WHITE)
	label.text = text
	pill.add_child(label)
	return pill


# The headline (key effect) shown big on the card.
func _headline(card: EventCardDefinition) -> String:
	match card.effect:
		E.BONUS_CASES:
			return "+%d cases" % card.amount
		E.MALUS_CASES:
			return "−%d cases" % card.amount
		E.BONUS_SCORE:
			return "+%d pts" % card.amount
		E.DOUBLE_DICE:
			return "Déplacement ×2"
		E.DOUBLE_SCORE_LIVRAISON:
			return "Livraison ×2"
		E.EXTRA_DIE:
			return "Dé bonus"
		E.REJOUER:
			return "Rejoue !"
		E.FIN_TOUR:
			return "Fin du tour"
		E.RETOUR_DRIVE:
			return "Retour drive"
		E.RETOUR_DEPART:
			return "Retour départ"
		E.TELEPORT_DESTINATION:
			return "Téléportation"
		E.TELEPORT_QUARTIER:
			return "Faille"
		E.TELEPORT_PARALLELE:
			return "Raccourci"
		E.BUDGET_UN_DE:
			return "Budget ÷2"
		E.ROUTE_BLOQUEE:
			return "−3 cases"
		E.PONTS_FERMES:
			return "−2 cases"
		_:
			return "—"


# A full plain-language description of the effect.
func _describe(card: EventCardDefinition) -> String:
	match card.effect:
		E.BONUS_CASES:
			return "Avance de %d cases supplémentaires ce tour." % card.amount
		E.MALUS_CASES:
			return "Tu perds %d cases de déplacement." % card.amount
		E.BONUS_SCORE:
			return "Gagne %d points immédiatement." % card.amount
		E.DOUBLE_DICE:
			return "Double ton déplacement restant."
		E.DOUBLE_SCORE_LIVRAISON:
			return "Ta prochaine livraison rapporte le double."
		E.EXTRA_DIE:
			return "Lance un dé de plus, ajouté à ton déplacement."
		E.REJOUER:
			return "Tu rejoues un tour complet juste après."
		E.FIN_TOUR:
			return "Ton déplacement s'arrête immédiatement."
		E.RETOUR_DRIVE:
			return "Retourne au point de retrait de ta livraison."
		E.RETOUR_DEPART:
			return "Retourne à ton point de départ."
		E.TELEPORT_DESTINATION:
			return "Saute directement à ta livraison en cours."
		E.TELEPORT_QUARTIER:
			return "Une faille te projette dans un quartier lointain."
		E.TELEPORT_PARALLELE:
			return "Un raccourci te mène au prochain drive disponible."
		E.BUDGET_UN_DE:
			return "Embouteillage : tu perds la moitié de ton déplacement."
		E.ROUTE_BLOQUEE:
			return "Une route est bloquée : détour de 3 cases."
		E.PONTS_FERMES:
			return "Les ponts sont fermés : détour de 2 cases."
		_:
			return "Rien ne se passe ce tour-ci."
