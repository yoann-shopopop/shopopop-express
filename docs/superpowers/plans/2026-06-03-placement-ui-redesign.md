# Refonte visuelle UI — Phase de placement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the setup-phase UI (`PlacementUI`) to match a provided mockup — header pill, recolored floating toolbar, labeled tile tray, big "Valider" button, light gradient backdrop — with zero gameplay or interaction-behavior change.

**Architecture:** Keep the existing all-in-code UI pattern (no UI `.tscn`). Add a static style factory `UITheme` (style "C": rounded `StyleBoxFlat` + `GradientTexture2D` gradients + soft shadow). Reorganize `PlacementUI` to the mockup layout, keeping its public surface/signals identical except for two new *optional* display params (turn index/total). Update `main.gd` to capture initial piece counts, feed the turn counter, and swap the dark 3D background for a light gradient.

**Tech Stack:** Godot 4.6, GDScript, GL Compatibility renderer, GUT for regression tests.

**Source spec:** `docs/superpowers/specs/2026-06-03-placement-ui-redesign-design.md`

---

## File Structure

- **Create** `src/ui/ui_theme.gd` (`class_name UITheme`) — static style factory: button styles per base color, header/pill style, tray-card styles, and a vertical `GradientTexture2D` helper.
- **Modify** `src/ui/placement_ui.gd` — reorganize layout to the mockup, apply `UITheme`, add team-name labels, recolor floating toolbar, add optional `turn_index`/`turn_total` params, show the drag-time rotate button only while dragging. Add a static pure helper `compute_turn_index()`.
- **Modify** `src/main.gd` — capture per-player initial piece counts, compute and pass `turn_index`/`turn_total`, replace the dark `Environment` background with a light vertical gradient backdrop.
- **Create** `tests/test_placement_ui.gd` — GUT test for the pure `compute_turn_index()` helper.

A note on TDD scope: this is mostly visual Node/rendering work with no unit-test surface. The one piece of pure logic — the `Tour X/Y` counter — is extracted into a static function and is TDD'd (Task 1). Every other task ends by running the full GUT suite to confirm **no regression** (logic is untouched) plus a manual visual check in the Godot editor.

---

## Task 1: Pure turn-index helper (TDD)

The mockup header shows `Tour X/Y`. `Y` = the player's initial tile count; `X` = how many placement turns deep we are. The formula must hold both before and after the turn's block is placed (because placing removes the block from `pieces`). Extract it as a static pure function so it can be tested without any Node.

**Files:**
- Modify: `src/ui/placement_ui.gd` (add static function only — safe, no behavior change)
- Test: `tests/test_placement_ui.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/test_placement_ui.gd`:

```gdscript
extends GutTest
## Tests for PlacementUI's pure helpers. compute_turn_index derives the 1-based placement-turn number
## from the player's initial tile count, the tiles still in their tray, and whether this turn's block
## has been placed yet (placing removes the block from the tray, so the count must absorb that).


func test_first_turn_nothing_placed() -> void:
	# 3 tiles total, 3 still in tray, no block placed yet -> turn 1.
	assert_eq(PlacementUI.compute_turn_index(3, 3, false), 1)


func test_first_turn_after_placing() -> void:
	# Block placed this turn -> tray dropped to 2, but it's still turn 1.
	assert_eq(PlacementUI.compute_turn_index(3, 2, true), 1)


func test_second_turn_nothing_placed() -> void:
	assert_eq(PlacementUI.compute_turn_index(3, 2, false), 2)


func test_last_turn_after_placing() -> void:
	# Last tile placed -> tray empty, turn 3 of 3.
	assert_eq(PlacementUI.compute_turn_index(3, 0, true), 3)


func test_clamped_to_at_least_one() -> void:
	# Defensive: never report turn 0 or negative.
	assert_eq(PlacementUI.compute_turn_index(0, 0, false), 1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_placement_ui.gd
```
Expected: FAIL — `Invalid call. Nonexistent function 'compute_turn_index' in base 'PlacementUI'`.

- [ ] **Step 3: Add the minimal implementation**

In `src/ui/placement_ui.gd`, add this static function (place it near the top, after the consts):

```gdscript
## 1-based placement-turn number for the header's "Tour X/Y". [param total] is the player's initial
## tile count, [param remaining] the tiles still in their tray, [param block_placed] whether this
## turn's block is already down (placing removes it from the tray, so we add it back here). Clamped
## to >= 1. Pure — no state, unit-tested.
static func compute_turn_index(total: int, remaining: int, block_placed: bool) -> int:
	var index := total - remaining + (0 if block_placed else 1)
	return maxi(index, 1)
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_placement_ui.gd
```
Expected: PASS — 5 passing tests.

- [ ] **Step 5: Commit**

```bash
git add src/ui/placement_ui.gd tests/test_placement_ui.gd
git commit -m "feat(ui): pure compute_turn_index helper for header Tour X/Y"
```

---

## Task 2: `UITheme` style factory

A static factory for the "C" look. All UI elements pull their styles from here so the look is centralized and tweakable. `StyleBoxFlat` is not gradient-capable, so buttons and the pill use a single tinted fill plus a colored border, a light 2px top border (faux bevel highlight) and a soft drop shadow — this reads as the style-C look without needing per-widget textures. `GradientTexture2D` is reserved for the full-screen backdrop (Task 5). All three are GL-Compatibility-safe.

**Files:**
- Create: `src/ui/ui_theme.gd`

- [ ] **Step 1: Create the file**

Create `src/ui/ui_theme.gd`:

```gdscript
class_name UITheme
extends RefCounted
## Centralized style factory for the setup-phase UI ("C — intermediate" look: rounded corners, colored
## border, soft drop shadow, a light top highlight). Static; returns fresh StyleBox / texture resources.
## GL-Compatibility-safe (StyleBoxFlat, StyleBoxTexture, GradientTexture2D only). Tweak the look here.

const RADIUS := 9
const SHADOW := Color(0, 0, 0, 0.30)
const HIGHLIGHT := Color(1, 1, 1, 0.28)  # faux top-bevel via a light top border
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
```

- [ ] **Step 2: Re-import so the new `class_name` registers**

Run:
```
godot --headless --path . --import
```
Expected: import completes with no script errors mentioning `ui_theme.gd`.

- [ ] **Step 3: Run the full GUT suite (no regression)**

Run:
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Expected: same pass count as before this task (the new class is referenced by nothing yet).

- [ ] **Step 4: Commit**

```bash
git add src/ui/ui_theme.gd
git commit -m "feat(ui): UITheme style factory (style C — rounded, bevel, gradient)"
```

---

## Task 3: Recolor & restyle the floating toolbar

The floating toolbar already works (`_build_controls`, `update_controls`) and anchors above the placed piece. Only its look changes: bigger buttons, style-C frames, recolored ⟲ orange / ✕ red / ⟳ blue. No behavior, no signal changes.

**Files:**
- Modify: `src/ui/placement_ui.gd:116-139` (`_build_controls`) and `CONTROL_BTN` const at line 20

- [ ] **Step 1: Enlarge the control button size**

In `src/ui/placement_ui.gd`, change the const:

```gdscript
const CONTROL_BTN := Vector2(56, 56)
```

- [ ] **Step 2: Restyle the three buttons**

Replace the body of `_build_controls` (lines 116-139) with:

```gdscript
# Floating toolbar shown above the piece just placed: rotate left, remove, rotate right (in order).
func _build_controls() -> void:
	_controls = HBoxContainer.new()
	_controls.add_theme_constant_override("separation", 10)
	_controls.top_level = true
	_controls.hide()
	add_child(_controls)

	_controls.add_child(_make_control_button("⟲", UITheme.ORANGE, func() -> void: rotate_left_requested.emit()))
	_controls.add_child(_make_control_button("✕", UITheme.RED, func() -> void: remove_requested.emit()))
	_controls.add_child(_make_control_button("⟳", UITheme.BLUE, func() -> void: rotate_right_requested.emit()))


# A single round-ish accent button for the floating toolbar.
func _make_control_button(glyph: String, accent: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = CONTROL_BTN
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.add_theme_stylebox_override("normal", UITheme.button_style(accent))
	b.add_theme_stylebox_override("hover", UITheme.button_style(accent, 1.6))
	b.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(accent))
	b.add_theme_stylebox_override("focus", UITheme.button_style(accent))
	b.pressed.connect(on_press)
	return b
```

- [ ] **Step 3: Re-import and run the full GUT suite (no regression)**

Run:
```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Expected: same pass count as before this task.

- [ ] **Step 4: Visual check (manual)**

Open the project in the Godot editor, run `scenes/main.tscn`, start a 2-player game, place a tile. Confirm the floating toolbar shows three larger colored buttons (orange/red/blue) above the placed tile and that rotate-left, remove, rotate-right still work.

- [ ] **Step 5: Commit**

```bash
git add src/ui/placement_ui.gd
git commit -m "feat(ui): recolor & restyle floating piece toolbar (style C)"
```

---

## Task 4: Reorganize the game panel to the mockup layout

Rebuild the in-game layout: top-center header pill + player sub-line, a centered `19 Hex` label above the tray, the tray of labeled tile cards (`Block 1`…, `Pont`), a bottom-right `VALIDER LE PLACEMENT` button, and the drag-time rotate button shown only while dragging. Team names use feminine agreement to match the mockup ("Équipe Bleue"). `set_current_player` gains two **optional** display params so `main.gd` keeps compiling until Task 5.

**Files:**
- Modify: `src/ui/placement_ui.gd` — consts (lines 18-20), member vars (22-29), `_build_game_panel` (82-112), `set_current_player` (144-188), `set_finished` (198-204), `_on_piece_pressed` (207-212); add team-name map + a `dragging`-state hook for the rotate button.

- [ ] **Step 1: Add team-name labels and new member vars**

In `src/ui/placement_ui.gd`, add after the existing consts (after line 20):

```gdscript
const TEAM_NAMES := {
	PlayerColor.Kind.BLUE: "Équipe Bleue",
	PlayerColor.Kind.RED: "Équipe Rouge",
	PlayerColor.Kind.PURPLE: "Équipe Violette",
	PlayerColor.Kind.YELLOW: "Équipe Jaune",
}
```

Add new member vars alongside the existing ones (near lines 22-29):

```gdscript
var _header_label: Label          # "PHASE DE PLACEMENT | Équipe ... · Tour X/Y"
var _subline_label: Label         # "J1 : Équipe ..."
var _hex_label: Label             # "19 Hex"
var _tray_rotate: Button          # cycles magnet orientation; only visible while dragging
var _validate_button: Button      # "VALIDER LE PLACEMENT" (was _finish_button)
```

You can remove the old `_turn_label`, `_status_label`, and `_finish_button` declarations (they are replaced by `_header_label`/`_subline_label` and `_validate_button`).

- [ ] **Step 2: Rebuild `_build_game_panel`**

Replace `_build_game_panel` (lines 82-112) with:

```gdscript
func _build_game_panel() -> void:
	_game_panel = MarginContainer.new()
	_game_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_panel.add_theme_constant_override("margin_left", 16)
	_game_panel.add_theme_constant_override("margin_right", 16)
	_game_panel.add_theme_constant_override("margin_top", 16)
	_game_panel.add_theme_constant_override("margin_bottom", 16)
	_game_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let board presses through empty areas
	add_child(_game_panel)

	# --- Top-center header: pill + player sub-line -------------------------
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	_game_panel.add_child(top)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.pill_style())
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(pill)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", UITheme.TEXT)
	pill.add_child(_header_label)

	_subline_label = Label.new()
	_subline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subline_label.add_theme_font_size_override("font_size", 15)
	top.add_child(_subline_label)

	# --- Bottom: 19 Hex + tray + Valider -----------------------------------
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 6)
	_game_panel.add_child(bottom)

	_hex_label = Label.new()
	_hex_label.text = "19 Hex"
	_hex_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hex_label.add_theme_color_override("font_color", UITheme.TEXT)
	bottom.add_child(_hex_label)

	# A row that holds (left spacer) | centered tray | right-aligned Valider.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_spacer)

	_pieces_bar = HBoxContainer.new()
	_pieces_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_pieces_bar.add_theme_constant_override("separation", 10)
	row.add_child(_pieces_bar)

	# Drag-time rotate (cycles magnet orientation) — hidden unless dragging.
	_tray_rotate = Button.new()
	_tray_rotate.text = "⟳"
	_tray_rotate.custom_minimum_size = Vector2(52, 52)
	_tray_rotate.add_theme_font_size_override("font_size", 20)
	_tray_rotate.add_theme_color_override("font_color", UITheme.TEXT)
	_tray_rotate.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.PANEL_DARK))
	_tray_rotate.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.PANEL_DARK, 1.6))
	_tray_rotate.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.PANEL_DARK))
	_tray_rotate.hide()
	_tray_rotate.pressed.connect(func() -> void: rotate_requested.emit())
	row.add_child(_tray_rotate)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)

	_validate_button = Button.new()
	_validate_button.text = "VALIDER\nLE PLACEMENT"
	_validate_button.custom_minimum_size = Vector2(150, 64)
	_validate_button.add_theme_font_size_override("font_size", 15)
	_validate_button.add_theme_color_override("font_color", UITheme.TEXT)
	_validate_button.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BLUE))
	_validate_button.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.BLUE, 1.6))
	_validate_button.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.BLUE))
	_validate_button.add_theme_stylebox_override("disabled", UITheme.button_style_pressed(UITheme.PANEL_BORDER))
	_validate_button.pressed.connect(func() -> void: finish_requested.emit())
	right.add_child(_validate_button)
```

- [ ] **Step 3: Rewrite `set_current_player` with optional turn params and tray cards**

Replace `set_current_player` (lines 144-188) with:

```gdscript
## Refreshes the bar for [param player]'s turn. While [param block_placed] is true the tray blocks are
## locked (one block per turn) and "Valider" is enabled; otherwise the reverse. [param turn_index] /
## [param turn_total] feed the header's "Tour X/Y" (display only; default 0 hides it).
func set_current_player(player: Player, block_placed: bool, turn_index: int = 0, turn_total: int = 0) -> void:
	var team: String = TEAM_NAMES.get(player.color, PlayerColor.name_of(player.color))
	var team_color := PlayerColor.to_color(player.color)
	var turn_suffix := ""
	if turn_total > 0:
		turn_suffix = " · Tour %d/%d" % [turn_index, turn_total]
	_header_label.text = "PHASE DE PLACEMENT  |  %s%s" % [team, turn_suffix]
	_subline_label.text = "J%d : %s" % [player.index + 1, team]
	_subline_label.add_theme_color_override("font_color", team_color)

	for child in _pieces_bar.get_children():
		child.queue_free()
	for child in _vp_host.get_children():
		child.queue_free()

	for i in player.pieces.size():
		_pieces_bar.add_child(_make_tray_card(
			TilePreview.build(player.pieces[i], _vp_host),
			"Block %d" % (i + 1), team_color, false, block_placed,
			_on_piece_pressed.bind(i)))

	# The free bridge, if still held — draggable any time during the turn.
	if player.bridge != null:
		_pieces_bar.add_child(_make_tray_card(
			TilePreview.build(player.bridge, _vp_host),
			"Pont", Color("8fd0ec"), false, false,
			func() -> void: bridge_drag_started.emit()))

	_validate_button.disabled = not block_placed


# Builds one labeled tray card: a textured tile button over a small caption, in a styled frame.
func _make_tray_card(tex: Texture2D, caption: String, accent: Color, selected: bool, disabled: bool, on_down: Callable) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.tray_card_style(accent, selected))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)

	var button := TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = PREVIEW_SIZE
	button.disabled = disabled
	button.modulate = Color(0.45, 0.45, 0.45) if disabled else Color.WHITE
	button.button_down.connect(on_down)
	box.add_child(button)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 12)
	caption_label.add_theme_color_override("font_color", UITheme.TEXT)
	box.add_child(caption_label)

	return frame
```

- [ ] **Step 4: Update `set_finished` and `_on_piece_pressed` for the new nodes**

Replace `set_finished` (lines 198-204) with:

```gdscript
func set_finished() -> void:
	_header_label.text = "MISE EN PLACE TERMINÉE"
	_subline_label.text = "Tous les blocs sont posés."
	_subline_label.add_theme_color_override("font_color", UITheme.TEXT)
	_controls.hide()
	_tray_rotate.hide()
	for child in _pieces_bar.get_children():
		child.queue_free()
```

Replace `_on_piece_pressed` (lines 207-212) with a version that re-frames the selected card (the card is now a `PanelContainer` wrapping the `TextureButton`):

```gdscript
func _on_piece_pressed(index: int) -> void:
	var i := 0
	for child in _pieces_bar.get_children():
		if child is PanelContainer:
			# Only the player's own tiles count for selection accent; the bridge stays neutral.
			var tex_button := child.get_child(0).get_child(0)
			if tex_button is TextureButton:
				tex_button.modulate = Color.WHITE if i == index else Color(0.55, 0.55, 0.55)
			i += 1
	piece_drag_started.emit(index)
```

- [ ] **Step 5: Show the drag-time rotate button only while dragging**

The controller already emits `controls_changed(shown, pos)` for the floating toolbar via `update_controls`. The drag-rotate visibility instead keys off drag start/stop. Add a public method and call it from `main.gd` in Task 5. For now add the method:

```gdscript
## Shows/hides the drag-time magnet-rotate button (visible only while a piece is being dragged).
func set_dragging(dragging: bool) -> void:
	_tray_rotate.visible = dragging
```

- [ ] **Step 6: Re-import and run the full GUT suite (no regression)**

Run:
```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Expected: same pass count as before this task (including the 5 `compute_turn_index` tests from Task 1).

- [ ] **Step 7: Commit**

```bash
git add src/ui/placement_ui.gd
git commit -m "feat(ui): mockup layout — header pill, labeled tray, Valider button"
```

---

## Task 5: Wire turn counter, drag state, and light backdrop in `main.gd`

Feed the new display params, toggle the drag-rotate button on drag start/release, and replace the dark 3D background with a light vertical gradient backdrop.

**Files:**
- Modify: `src/interaction/placement_controller.gd` — add a `drag_changed` notification signal (additive; does not change any interaction behavior).
- Modify: `src/main.gd` — member vars (lines 16-21), `start_game` (37-71), `_refresh_ui` (82-83), `_build_environment` (142-152).

- [ ] **Step 1: Add a drag-state signal to the controller**

The drag-time `⟳` button must show only while a piece is being dragged. The controller is the single source of truth for that, so add a notification signal — purely additive, it changes no interaction behavior.

In `src/interaction/placement_controller.gd`, add next to the existing signal (line 14):

```gdscript
signal drag_changed(active: bool)          # drag started / ended — for drag-only UI affordances
```

In `_start_drag` (after `_ghost.visible = true`, around line 118) add:

```gdscript
	drag_changed.emit(true)
```

In `_end_drag` (after `_ghost.set_block(null)`, around line 196) add:

```gdscript
	drag_changed.emit(false)
```

- [ ] **Step 2: Capture each player's initial tile count**

In `src/main.gd`, add a member var near the others (after line 20):

```gdscript
var _initial_piece_counts: Dictionary = {}  # Player -> initial tile count, for the "Tour X/Y" header
```

In `start_game`, right after `_players = SetupDistributor.build_players(...)` (line 43), add:

```gdscript
	_initial_piece_counts.clear()
	for p in _players:
		_initial_piece_counts[p] = p.pieces.size()
```

- [ ] **Step 3: Wire the controller's drag-state signal to the UI**

In `start_game`, alongside the other `controller`/`_ui` connections (lines 63-70), add:

```gdscript
	controller.drag_changed.connect(_ui.set_dragging)
```

This single connection drives the drag-time `⟳` button: the controller emits `true` on `_start_drag` and `false` on `_end_drag` (Task 5 Step 1), covering every case including a drag cancelled on an invalid drop. Keep all existing connections unchanged.

- [ ] **Step 4: Pass turn index/total in `_refresh_ui`**

Replace `_refresh_ui` (lines 82-83) with:

```gdscript
func _refresh_ui() -> void:
	var player := phase.current_player()
	var total: int = _initial_piece_counts.get(player, player.pieces.size())
	var index := PlacementUI.compute_turn_index(total, player.pieces.size(), phase.block_placed_this_turn())
	_ui.set_current_player(player, phase.block_placed_this_turn(), index, total)
	_ui.set_dragging(false)
```

- [ ] **Step 5: Replace the dark background with a light gradient backdrop**

Replace `_build_environment` (lines 142-152) with:

```gdscript
func _build_environment() -> void:
	# Light, airy backdrop (mockup feel). A full-screen gradient on a background CanvasLayer sits behind
	# the 3D board; the 3D environment itself stays transparent-ish via a matching flat clear color.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c3d2df")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe7ef")
	env.ambient_light_energy = 0.8
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)

	# Vertical gradient drawn behind everything (light top -> slightly deeper bottom).
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100
	add_child(bg_layer)
	var rect := TextureRect.new()
	rect.texture = UITheme.vertical_gradient(Color("dCe8f2"), Color("aebfd0"))
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(rect)
```

- [ ] **Step 6: Re-import and run the full GUT suite (no regression)**

Run:
```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Expected: same pass count as before this task.

- [ ] **Step 7: Visual check (manual)**

Run `scenes/main.tscn` in the editor. Verify: light gradient backdrop; header pill reads `PHASE DE PLACEMENT | Équipe Bleue · Tour 1/3`; sub-line `J1 : Équipe Bleue`; `19 Hex` above the tray; tray cards labeled `Block 1..3` (+ `Pont`); `VALIDER LE PLACEMENT` bottom-right, disabled until a tile is placed; the `⟳` magnet button appears only while dragging a tile. Place tiles across turns and confirm `Tour X/3` increments correctly and all interactions (drag, magnet, rotate, remove, finish) behave exactly as before.

- [ ] **Step 8: Commit**

```bash
git add src/interaction/placement_controller.gd src/main.gd
git commit -m "feat(ui): wire Tour X/Y counter, drag-rotate toggle, light backdrop"
```

---

## Task 6: Apply the theme to the start screen

Give the "Nombre de joueurs" start screen the same look for consistency (layout unchanged).

**Files:**
- Modify: `src/ui/placement_ui.gd:43-67` (`_build_start_panel`)

- [ ] **Step 1: Style the title and count buttons**

Replace `_build_start_panel` (lines 43-67) with:

```gdscript
func _build_start_panel() -> void:
	_start_panel = CenterContainer.new()
	_start_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_start_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_start_panel.add_child(box)

	var title := Label.new()
	title.text = "Nombre de joueurs"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.TEXT)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for n in [2, 3, 4, 5, 6]:
		var button := Button.new()
		button.text = str(n)
		button.custom_minimum_size = BUTTON_MIN
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", UITheme.TEXT)
		button.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BLUE))
		button.add_theme_stylebox_override("hover", UITheme.button_style(UITheme.BLUE, 1.6))
		button.add_theme_stylebox_override("pressed", UITheme.button_style_pressed(UITheme.BLUE))
		button.pressed.connect(_on_count_pressed.bind(n))
		row.add_child(button)
```

- [ ] **Step 2: Re-import and run the full GUT suite (no regression)**

Run:
```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Expected: same pass count as before this task.

- [ ] **Step 3: Visual check (manual)**

Run `scenes/main.tscn`; the start screen shows a larger title and five blue style-C count buttons. Picking a count still starts the game.

- [ ] **Step 4: Commit**

```bash
git add src/ui/placement_ui.gd
git commit -m "feat(ui): apply UITheme to the player-count start screen"
```

---

## Task 7: Final regression sweep & cleanup

**Files:** none (verification only)

- [ ] **Step 1: Full re-import + full GUT suite**

Run:
```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Expected: all tests pass, including `tests/test_placement_ui.gd` (5 tests). Confirm the total pass count matches the pre-refactor baseline plus 5.

- [ ] **Step 2: Confirm no leftover references to removed members**

Search the two modified scripts for the removed member names:
```
rg -n "_turn_label|_status_label|_finish_button" src/ui/placement_ui.gd src/main.gd
```
Expected: no matches. (Parse/compile errors would also have surfaced during the `--import` step above.)

- [ ] **Step 3: Manual end-to-end visual pass**

Run `scenes/main.tscn`, play a full setup with 2–4 players: every interaction (drag, magnet snap, drag-rotate `⟳`, floating toolbar ⟲/✕/⟳, re-position by dragging a placed tile, Valider) must behave exactly as before the refactor. Confirm the visual matches the mockup direction (style C).

- [ ] **Step 4: No commit needed** (verification only). If Step 2 surfaced stale references, fix them and commit:

```bash
git add -A
git commit -m "fix(ui): remove stale references after placement UI redesign"
```
