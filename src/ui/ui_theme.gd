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


## A vertical two-stop gradient texture (top -> bottom). Used for the full-screen backdrop.
static func vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 16
	tex.height = 256
	return tex
