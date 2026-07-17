class_name UITheme
extends RefCounted
## Centralized style factory for the setup-phase UI ("C — intermediate" look: rounded corners, colored
## border, soft drop shadow, a light top highlight). Static; returns fresh StyleBox / texture resources.
## GL-Compatibility-safe (StyleBoxFlat, StyleBoxTexture, GradientTexture2D only). Tweak the look here.

const RADIUS := 9
const SHADOW := Color(0, 0, 0, 0.30)
const PANEL_DARK := Color("2b3440")
const PANEL_BORDER := Color("5a6675")
const TEXT := Color("f2f5f8")

# Toolbar / accent colors (mockup).
const ORANGE := Color("e8851f")
const RED := Color("d33a30")
const BLUE := Color("1f8fd0")
const GREEN := Color("4caf50")

# Bundled OFL fonts (see assets/fonts/OFL-*.txt). Nunito = clean body; Fredoka = rounded display.
const FONT_BODY := "res://assets/fonts/Nunito.ttf"
const FONT_DISPLAY := "res://assets/fonts/Fredoka.ttf"

static var _body_font: Font = null
static var _display_font: Font = null


## The UI body font (Nunito, OFL) — legible at small sizes. Cached; null if the file is missing.
static func body_font() -> Font:
	if _body_font == null and ResourceLoader.exists(FONT_BODY):
		_body_font = load(FONT_BODY)
	return _body_font


## The display font (Fredoka, OFL) — rounded and friendly, for titles, banners and the score. Cached.
static func display_font() -> Font:
	if _display_font == null and ResourceLoader.exists(FONT_DISPLAY):
		_display_font = load(FONT_DISPLAY)
	return _display_font


## Installs the body font as the app-wide default ([member ThemeDB.fallback_font]) so every label picks
## it up without per-control overrides. Call once at startup; titles still opt into [method display_font].
## A no-op (keeping Godot's default font) if the bundled font is unavailable.
static func install_fonts() -> void:
	var body := body_font()
	if body != null:
		ThemeDB.fallback_font = body


## Applies the rounded display font to [param label] at [param size] with the standard text colour.
static func make_title(label: Label, size: int, color: Color = TEXT) -> void:
	var font := display_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


## A rounded, bordered, shadowed button background tinted [param base]. [param emphasis] brightens it
## for the focused/normal state; a darker variant suits pressed/hover if needed by the caller.
static func button_style(base: Color, emphasis: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base.lightened(0.06 * emphasis)
	sb.set_corner_radius_all(RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.40)
	# Light top edge = faux bevel highlight.
	sb.border_width_top = 2
	sb.shadow_color = SHADOW
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(8)
	return sb


## A pressed/disabled-looking flatter variant of [method button_style] (darker, no shadow lift).
static func button_style_pressed(base: Color) -> StyleBoxFlat:
	var sb := button_style(base.darkened(0.12))
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 1)
	return sb


## The dark pill background for the header bandeau.
static func pill_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_DARK
	sb.set_corner_radius_all(RADIUS + 1)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.border_width_top = 2
	sb.shadow_color = SHADOW
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## A cohesive HUD panel/card background: rounded, subtle border + soft drop shadow. Shared by the side
## panels and the delivery cards so the whole 2D chrome reads as one design.
static func panel_card(bg: Color = Color("212734")) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.shadow_color = SHADOW
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(10)
	return sb


## A small filled, rounded status-pill background tinted [param color] (delivery status, badges).
static func status_pill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## A tray-tile frame tinted [param accent]. [param selected] thickens the border to mark the active tile.
static func tray_card_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.19, 0.23, 0.85)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(3 if selected else 2)
	sb.border_color = accent if selected else accent.darkened(0.25)
	sb.shadow_color = SHADOW
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 1)
	sb.set_content_margin_all(6)
	return sb


# --- dobo_ui pack ("Fantasy RPG UI Pack", itch.io) --------------------------------------
# Only the style-neutral reusable subset is copied in, lazily, under res://assets/ui_pack/ as each
# consumer is wired — never the whole pack (its license isn't bundled; verify the itch.io purchase
# terms before any public/Steam release — see CLAUDE.md). These StyleBoxTexture methods live ALONGSIDE
# the StyleBoxFlat ones above, adopted per call site, not a global swap.
#
# No RED/ORANGE role here: the pack's closest matches ("coral" = pale salmon, "yellow" = gold/mustard)
# don't read as UITheme.RED/ORANGE — callers needing those keep button_style()/panel_card() flat.
const _PACK_DIR := "res://assets/ui_pack/"

enum PackRole { BLUE, NEUTRAL, GREEN }

const _PACK_COLOR := {
	PackRole.BLUE: "blue",       # matches UITheme.BLUE
	PackRole.NEUTRAL: "darkBlue", # matches PANEL_DARK/PANEL_BORDER (NOT "_default", which is parchment)
	PackRole.GREEN: "green",     # matches UITheme.GREEN
}

static var _pack_tex_cache: Dictionary = {}


static func _pack_texture(rel_path: String) -> Texture2D:
	if not _pack_tex_cache.has(rel_path):
		var full := _PACK_DIR + rel_path
		_pack_tex_cache[rel_path] = load(full) if ResourceLoader.exists(full) else null
	return _pack_tex_cache[rel_path]


## The dobo_ui event-card back/frame art (Cards/CardsPrefab/Card1), for the FIXED-size SubViewport
## targets in [CardBackFace]/[EventCardFace] — a raw texture behind a full-rect
## [code]TextureRect[/code] ([code]STRETCH_KEEP_ASPECT_COVERED[/code]), not a StyleBox: the render
## target never resizes at runtime, so there's no 9-slice margin problem to solve here.
static func card_texture(role: int = PackRole.NEUTRAL) -> Texture2D:
	var color: String = _PACK_COLOR.get(role, "darkBlue")
	return _pack_texture("Cards/Card1_%s.png" % color)


## The dobo_ui "Button2" pill (401×107): fully-rounded end caps, so left/right margins are set to
## ~half the source height to keep the caps whole while the flat middle 9-slices; top/bottom just
## clear the thin highlight/shadow banding. Same geometry across colors — only the recolor changes.
const _BUTTON_MARGIN := {left = 52, right = 52, top = 16, bottom = 16}


## A [StyleBoxTexture] pill button tinted by [param role] (no RED/ORANGE — see the note above; those
## roles keep [method button_style]). [param pressed] darkens via [member StyleBoxTexture.modulate]
## since the source art itself can't be recolored per-state.
static func button_style_textured(role: int, pressed: bool = false) -> StyleBoxTexture:
	var color: String = _PACK_COLOR.get(role, "darkBlue")
	var sb := StyleBoxTexture.new()
	sb.texture = _pack_texture("Buttons/Button2_%s.png" % color)
	sb.texture_margin_left = _BUTTON_MARGIN.left
	sb.texture_margin_right = _BUTTON_MARGIN.right
	sb.texture_margin_top = _BUTTON_MARGIN.top
	sb.texture_margin_bottom = _BUTTON_MARGIN.bottom
	sb.set_content_margin_all(10)
	sb.content_margin_left = _BUTTON_MARGIN.left + 6
	sb.content_margin_right = _BUTTON_MARGIN.right + 6
	if pressed:
		sb.modulate_color = Color(0.72, 0.72, 0.72)
	return sb


## The dobo_ui "Container1" bandeau (721×129): a shallow rounded-rect frame with a faint corner
## sparkle — margins clear the corner radius + border without eating into the sparkle motifs.
const _PANEL_MARGIN := {left = 30, right = 30, top = 30, bottom = 30}


## A [StyleBoxTexture] panel/card background tinted by [param role] — the textured counterpart to
## [method panel_card], for HUD panels/bandeaux that should read as part of the same pack chrome.
static func panel_style_textured(role: int = PackRole.NEUTRAL) -> StyleBoxTexture:
	var color: String = _PACK_COLOR.get(role, "darkBlue")
	var sb := StyleBoxTexture.new()
	sb.texture = _pack_texture("Containers/Container1_%s.png" % color)
	sb.texture_margin_left = _PANEL_MARGIN.left
	sb.texture_margin_right = _PANEL_MARGIN.right
	sb.texture_margin_top = _PANEL_MARGIN.top
	sb.texture_margin_bottom = _PANEL_MARGIN.bottom
	sb.set_content_margin_all(14)
	return sb


## The dobo_ui "Modal4" frame (433×425): a black-bordered tech-panel look with a lighter title strip
## across the top — [param top] margin is set generously to keep that strip (and the rounded top
## corners) intact under 9-slice; the plain lower body stretches freely.
const _MODAL_MARGIN := {left = 20, right = 20, top = 58, bottom = 20}


## A [StyleBoxTexture] full-panel background for modal overlays (chooser/reference/settings/handoff) —
## single design, no role/color variants (the source art has none).
static func modal_style_textured() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _pack_texture("Modals/Modal4.png")
	sb.texture_margin_left = _MODAL_MARGIN.left
	sb.texture_margin_right = _MODAL_MARGIN.right
	sb.texture_margin_top = _MODAL_MARGIN.top
	sb.texture_margin_bottom = _MODAL_MARGIN.bottom
	sb.set_content_margin_all(24)
	sb.content_margin_top = _MODAL_MARGIN.top + 10
	return sb
