class_name EventModal
extends Control
## A crisp 2D modal shown when a pawn lands on a rainbow cell: one event card (forced), or two when
## Carnet d'Adresses (Charlie) is armed — keep one. Each card has a real face: an Avantage/Malus band,
## the title, the key effect highlighted, and a plain-language description. A SINGLE click keeps and
## plays a card. Replaces the old 3D placeholder card; emits [signal resolved] unchanged so GameRoot
## stays the same. Lives on the HUD CanvasLayer (no camera / world pinning).

signal resolved(chosen: EventCardDefinition, discarded: Array)

const E := EventCardDefinition.Effect
const CARD_SIZE := Vector2(300, 416)

var _cards: Array = []
var _done := false


## Shows [param cards] (1 or 2) as a centered modal over a dimmed backdrop.
func present(cards: Array) -> void:
	_cards = cards
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.06, 0.09, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # block the board while choosing
	add_child(backdrop)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	backdrop.add_child(col)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.make_title(title, 40, UITheme.ORANGE)
	title.text = "Événement !"
	col.add_child(title)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UITheme.PANEL_BORDER)
	hint.text = "Clique la carte pour la jouer." if cards.size() == 1 else "Pioche 2 — clique celle que tu gardes."
	col.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	col.add_child(row)
	for card in cards:
		row.add_child(_make_card(card))


func _make_card(card: EventCardDefinition) -> Control:
	var accent := UITheme.RED if card.is_malus else UITheme.GREEN
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var sb := UITheme.panel_card(Color("232a38"))
	sb.set_border_width_all(3)
	sb.border_color = accent
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_card_input.bind(card))
	panel.mouse_entered.connect(func() -> void: panel.modulate = Color(1.1, 1.1, 1.1))
	panel.mouse_exited.connect(func() -> void: panel.modulate = Color.WHITE)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(_pill("MALUS" if card.is_malus else "AVANTAGE", accent, 16, Control.SIZE_SHRINK_CENTER))

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_title(name_lbl, 28)
	name_lbl.text = card.display_name
	box.add_child(name_lbl)

	box.add_child(_pill(_headline(card), accent.darkened(0.12), 24, Control.SIZE_SHRINK_CENTER))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", UITheme.TEXT)
	desc.text = _describe(card)
	box.add_child(desc)

	if card.condition == EventCardDefinition.Condition.VELO:
		var velo := Label.new()
		velo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		velo.add_theme_font_size_override("font_size", 14)
		velo.add_theme_color_override("font_color", UITheme.BLUE)
		velo.text = "À vélo uniquement"
		box.add_child(velo)
	return panel


# A rounded coloured pill with centered [param text].
func _pill(text: String, color: Color, font_size: int, size_flags: int) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = size_flags
	var sb := UITheme.status_pill(color)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	UITheme.make_title(label, font_size, Color.WHITE)
	label.text = text
	pill.add_child(label)
	return pill


func _on_card_input(event: InputEvent, card: EventCardDefinition) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_keep(card)


func _keep(chosen: EventCardDefinition) -> void:
	if _done:
		return
	_done = true
	AudioManager.sfx(&"ui_click")
	var discarded: Array = []
	for c in _cards:
		if c != chosen:
			discarded.append(c)
	resolved.emit(chosen, discarded)
	queue_free()


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
