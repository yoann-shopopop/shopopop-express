# Cartes enseigne/destinataire & génération de livraisons — Implementation Plan

> ⚠️ **Caviardé le 2026-07-16** : les noms d'exemple d'origine (personnalités réelles et parodies de marques) ont été remplacés par le contenu fictif actuel, pour les mêmes raisons juridiques que la purge des `resources/`. Voir CLAUDE.md.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire un module autonome (logique pure testée + démo 3D interactive) qui apparie aléatoirement une enseigne et un destinataire en « combos » de livraison, gère leur statut (disponible/réservé/en cours/livré) et recycle les destinataires à la livraison.

**Architecture:** Découplage strict (CLAUDE.md) — données en `Resource` (`.tres`), logique en `RefCounted` pur testé en `--headless`, rendu en `Node3D`. Un `DeliveryGenerator` tient des emplacements d'enseignes fixes + une pioche de destinataires sans remise ; une scène de démo (sur le modèle de `src/card_demo.gd`) pilote tout au clic.

**Tech Stack:** Godot 4.6, GDScript, GUT (tests). Godot lancé via `flatpak run org.godotengine.Godot`.

**Spec:** `docs/superpowers/specs/2026-06-02-cartes-enseigne-destinataire-design.md`

**Commandes (rappel) :**
```bash
# import (obligatoire après tout nouveau class_name) :
flatpak run org.godotengine.Godot --headless --path . --import
# un test ciblé :
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_X.gd
# toute la suite :
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

---

## File Structure

| Fichier | Responsabilité |
|---|---|
| `src/enseignes/enseigne_definition.gd` | Donnée enseigne (id, nom, image, couleur) |
| `src/destinataires/destinataire_definition.gd` | Donnée destinataire (id, nom, image, couleur) |
| `src/livraisons/delivery_status.gd` | Enum des statuts + libellés FR |
| `src/livraisons/delivery_combo.gd` | Un combo enseigne×destinataire + son statut |
| `src/livraisons/delivery_generator.gd` | Appariement aléatoire, cycle de statut, recyclage |
| `src/view/clip_card_view.gd` | Rendu 3D d'un combo clipsé (enseigne + statut + destinataire) |
| `src/enseigne_demo.gd` + `scenes/enseigne_demo.tscn` | Démo autonome interactive |
| `resources/enseignes/*.tres` (9) | Enseignes (générées) |
| `resources/destinataires/*.tres` (~12) | Destinataires (générés) |
| `tools/generate_enseignes.gd`, `tools/generate_destinataires.gd` | Outils de génération des `.tres` |
| `tests/test_*.gd` | Tests GUT |

---

## Task 1: EnseigneDefinition (donnée)

**Files:**
- Create: `src/enseignes/enseigne_definition.gd`
- Test: `tests/test_enseigne_definition.gd`

- [ ] **Step 1: Write the failing test**

`tests/test_enseigne_definition.gd` :
```gdscript
extends GutTest
## Tests for EnseigneDefinition — a pickup brand card's data.


func test_fields_are_assignable() -> void:
	var e := EnseigneDefinition.new()
	e.id = &"visse_et_vrille"
	e.display_name = "VISSE & VRILLE"
	e.color = Color.RED
	assert_eq(e.id, &"visse_et_vrille")
	assert_eq(e.display_name, "VISSE & VRILLE")
	assert_eq(e.color, Color.RED)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flatpak run org.godotengine.Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_enseigne_definition.gd`
Expected: Parse Error — `EnseigneDefinition` not declared.

- [ ] **Step 3: Write minimal implementation**

`src/enseignes/enseigne_definition.gd` :
```gdscript
class_name EnseigneDefinition
extends Resource
## A pickup point (shop sign): a parody brand with its logo. Pure data (.tres), like PawnDefinition.

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D = null  ## the brand logo (assets/trades/*)
@export var color: Color = Color.WHITE  ## tab tint
```

- [ ] **Step 4: Run import then the test**

Run: `flatpak run org.godotengine.Godot --headless --path . --import` then the test command from Step 2.
Expected: PASS (1/1).

- [ ] **Step 5: Commit**

```bash
git add src/enseignes/enseigne_definition.gd tests/test_enseigne_definition.gd
git commit -m "feat(enseignes): EnseigneDefinition (donnée d'enseigne)"
```

---

## Task 2: DestinataireDefinition (donnée)

**Files:**
- Create: `src/destinataires/destinataire_definition.gd`
- Test: `tests/test_destinataire_definition.gd`

- [ ] **Step 1: Write the failing test**

`tests/test_destinataire_definition.gd` :
```gdscript
extends GutTest
## Tests for DestinataireDefinition — a recipient card's data.


func test_fields_are_assignable() -> void:
	var d := DestinataireDefinition.new()
	d.id = &"vero_locale"
	d.display_name = "Véro Locale"
	d.color = Color.BLUE
	assert_eq(d.id, &"vero_locale")
	assert_eq(d.display_name, "Véro Locale")
	assert_eq(d.color, Color.BLUE)
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command for `test_destinataire_definition.gd`.
Expected: Parse Error — `DestinataireDefinition` not declared.

- [ ] **Step 3: Write minimal implementation**

`src/destinataires/destinataire_definition.gd` :
```gdscript
class_name DestinataireDefinition
extends Resource
## A recipient (the client of a delivery): a parody name, optional portrait. Pure data (.tres).

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D = null  ## portrait (placeholder/null for now)
@export var color: Color = Color.WHITE  ## banner tint
```

- [ ] **Step 4: Run import then the test**

Expected: PASS (1/1).

- [ ] **Step 5: Commit**

```bash
git add src/destinataires/destinataire_definition.gd tests/test_destinataire_definition.gd
git commit -m "feat(destinataires): DestinataireDefinition (donnée de destinataire)"
```

---

## Task 3: DeliveryStatus + DeliveryCombo (statut & combo)

**Files:**
- Create: `src/livraisons/delivery_status.gd`, `src/livraisons/delivery_combo.gd`
- Test: `tests/test_delivery_combo.gd`

- [ ] **Step 1: Write the failing test**

`tests/test_delivery_combo.gd` :
```gdscript
extends GutTest
## Tests for DeliveryCombo — an enseigne×destinataire pairing and its status cycle.


func _enseigne() -> EnseigneDefinition:
	var e := EnseigneDefinition.new()
	e.id = &"visse_et_vrille"
	return e


func _destinataire() -> DestinataireDefinition:
	var d := DestinataireDefinition.new()
	d.id = &"vero_locale"
	return d


func test_new_combo_is_available() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	assert_eq(c.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_true(c.is_available())
	assert_false(c.is_done())


func test_advance_cycles_through_statuses() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	assert_true(c.advance())
	assert_eq(c.status, DeliveryStatus.Kind.RESERVE)
	assert_true(c.advance())
	assert_eq(c.status, DeliveryStatus.Kind.EN_COURS)
	assert_true(c.advance())
	assert_eq(c.status, DeliveryStatus.Kind.LIVREE)
	assert_true(c.is_done())


func test_advance_past_delivered_is_a_noop() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	c.advance(); c.advance(); c.advance()  # -> LIVREE
	assert_false(c.advance(), "cannot advance past LIVREE")


func test_status_label_is_french() -> void:
	assert_eq(DeliveryStatus.label(DeliveryStatus.Kind.EN_COURS), "En cours")
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command for `test_delivery_combo.gd`.
Expected: Parse Error — `DeliveryStatus` / `DeliveryCombo` not declared.

- [ ] **Step 3: Write minimal implementation**

`src/livraisons/delivery_status.gd` :
```gdscript
class_name DeliveryStatus
extends RefCounted
## The state of a delivery combo. No status insert = DISPONIBLE; then RESERVE / EN_COURS; LIVREE
## triggers recycling of the recipient.

enum Kind { DISPONIBLE, RESERVE, EN_COURS, LIVREE }

const _LABELS := {
	Kind.DISPONIBLE: "Disponible",
	Kind.RESERVE: "Réservé",
	Kind.EN_COURS: "En cours",
	Kind.LIVREE: "Livré",
}


static func label(kind: int) -> String:
	return _LABELS.get(kind, "?")
```

`src/livraisons/delivery_combo.gd` :
```gdscript
class_name DeliveryCombo
extends RefCounted
## A delivery: an enseigne (pickup) clipped with a destinataire (client), plus a status. Pure logic.

var enseigne: EnseigneDefinition
var destinataire: DestinataireDefinition
var status: int = DeliveryStatus.Kind.DISPONIBLE


func _init(p_enseigne: EnseigneDefinition, p_destinataire: DestinataireDefinition) -> void:
	enseigne = p_enseigne
	destinataire = p_destinataire


## Advances the status one step (DISPONIBLE→RESERVE→EN_COURS→LIVREE). False if already LIVREE.
func advance() -> bool:
	if status >= DeliveryStatus.Kind.LIVREE:
		return false
	status += 1
	return true


func is_available() -> bool:
	return status == DeliveryStatus.Kind.DISPONIBLE


func is_done() -> bool:
	return status == DeliveryStatus.Kind.LIVREE
```

- [ ] **Step 4: Run import then the test**

Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add src/livraisons/delivery_status.gd src/livraisons/delivery_combo.gd tests/test_delivery_combo.gd
git commit -m "feat(livraisons): DeliveryStatus + DeliveryCombo"
```

---

## Task 4: DeliveryGenerator (appariement + recyclage)

**Files:**
- Create: `src/livraisons/delivery_generator.gd`
- Test: `tests/test_delivery_generator.gd`

- [ ] **Step 1: Write the failing test**

`tests/test_delivery_generator.gd` :
```gdscript
extends GutTest
## Tests for DeliveryGenerator — random pairing, status advance/complete, recipient recycling.


func _enseignes(n: int) -> Array[EnseigneDefinition]:
	var result: Array[EnseigneDefinition] = []
	for i in n:
		var e := EnseigneDefinition.new()
		e.id = StringName("e%d" % i)
		result.append(e)
	return result


func _destinataires(n: int) -> Array[DestinataireDefinition]:
	var result: Array[DestinataireDefinition] = []
	for i in n:
		var d := DestinataireDefinition.new()
		d.id = StringName("d%d" % i)
		result.append(d)
	return result


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	return rng


func test_builds_one_combo_per_slot() -> void:
	var gen := DeliveryGenerator.new(_enseignes(4), _destinataires(10), 4, _seeded_rng())
	assert_eq(gen.combos().size(), 4)


func test_recipients_are_distinct_across_combos() -> void:
	var gen := DeliveryGenerator.new(_enseignes(4), _destinataires(10), 4, _seeded_rng())
	var ids := {}
	for combo in gen.combos():
		ids[combo.destinataire.id] = true
	assert_eq(ids.size(), 4, "no recipient reused simultaneously")


func test_advance_stops_at_en_cours() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	assert_true(gen.advance(0))   # RESERVE
	assert_true(gen.advance(0))   # EN_COURS
	assert_false(gen.advance(0), "advance does not reach LIVREE")
	assert_eq(gen.combos()[0].status, DeliveryStatus.Kind.EN_COURS)


func test_complete_recycles_a_new_recipient() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	var old_id := gen.combos()[0].destinataire.id
	gen.advance(0); gen.advance(0)  # -> EN_COURS
	assert_true(gen.complete(0))
	var combo := gen.combos()[0]
	assert_eq(combo.status, DeliveryStatus.Kind.DISPONIBLE, "recycled back to available")
	assert_ne(combo.destinataire, null, "a new recipient was clipped")
	assert_ne(combo.destinataire.id, old_id, "different recipient drawn from the pool")


func test_complete_requires_en_cours() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	assert_false(gen.complete(0), "cannot complete a DISPONIBLE combo")


func test_pool_exhaustion_leaves_an_empty_combo() -> void:
	# 2 recipients, 1 slot: 1 drawn at init, 1 left. Complete once -> last drawn. Complete again -> none.
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(2), 1, _seeded_rng())
	gen.advance(0); gen.advance(0); gen.complete(0)  # uses the 2nd recipient
	assert_eq(gen.remaining_recipients(), 0)
	gen.advance(0); gen.advance(0)
	assert_true(gen.complete(0))
	assert_null(gen.combos()[0].destinataire, "no recipient left to clip")
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command for `test_delivery_generator.gd`.
Expected: Parse Error — `DeliveryGenerator` not declared.

- [ ] **Step 3: Write minimal implementation**

`src/livraisons/delivery_generator.gd` :
```gdscript
class_name DeliveryGenerator
extends RefCounted
## Generates deliveries by clipping each enseigne slot with a random destinataire (drawn without
## replacement). Advancing a combo cycles its status; completing it recycles the recipient — a new one
## is drawn from the remaining pool, or the slot is left empty when the pool is exhausted. Pure logic;
## the RNG is injectable for deterministic tests. Mirrors SetupDistributor's seeded Fisher-Yates draw.

signal combo_changed(index: int)
signal recycled(index: int)
signal exhausted

var _combos: Array[DeliveryCombo] = []
var _pool: Array[DestinataireDefinition] = []  # remaining recipients (draw pile)
var _rng: RandomNumberGenerator


func _init(
	enseignes: Array[EnseigneDefinition],
	destinataires: Array[DestinataireDefinition],
	slots: int,
	rng: RandomNumberGenerator = null,
) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	_pool = destinataires.duplicate()
	_shuffle(_pool)
	var count := mini(slots, enseignes.size())
	for i in count:
		_combos.append(DeliveryCombo.new(enseignes[i], _draw()))


## The current combos (one per active slot).
func combos() -> Array[DeliveryCombo]:
	return _combos


## Recipients left in the draw pile.
func remaining_recipients() -> int:
	return _pool.size()


## Advances a combo's status up to EN_COURS (LIVREE is done via [method complete]).
func advance(index: int) -> bool:
	var combo := _combos[index]
	if combo.status >= DeliveryStatus.Kind.EN_COURS:
		return false
	combo.advance()
	combo_changed.emit(index)
	return true


## Completes an EN_COURS combo: removes its recipient and clips a new one (or leaves it empty).
func complete(index: int) -> bool:
	var combo := _combos[index]
	if combo.status != DeliveryStatus.Kind.EN_COURS:
		return false
	combo.destinataire = _draw()  # may be null when the pool is exhausted
	combo.status = DeliveryStatus.Kind.DISPONIBLE
	recycled.emit(index)
	if combo.destinataire == null:
		exhausted.emit()
	return true


# Pops the top recipient from the (shuffled) pool, or null when empty.
func _draw() -> DestinataireDefinition:
	if _pool.is_empty():
		return null
	return _pool.pop_back()


func _shuffle(pile: Array[DestinataireDefinition]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: DestinataireDefinition = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp
```

- [ ] **Step 4: Run import then the test**

Expected: PASS (6/6).

- [ ] **Step 5: Commit**

```bash
git add src/livraisons/delivery_generator.gd tests/test_delivery_generator.gd
git commit -m "feat(livraisons): DeliveryGenerator (appariement aléatoire + recyclage)"
```

---

## Task 5: Ressources enseignes & destinataires (générées)

**Files:**
- Create: `tools/generate_enseignes.gd`, `tools/generate_destinataires.gd`
- Generated: `resources/enseignes/*.tres` (9), `resources/destinataires/*.tres` (12)

- [ ] **Step 1: Write the enseigne generator**

`tools/generate_enseignes.gd` :
```gdscript
extends SceneTree
## Dev tool: builds resources/enseignes/*.tres from the brand images in assets/trades/.
## Run: godot --headless --path . -s res://tools/generate_enseignes.gd

const DIR := "res://resources/enseignes/"
const TRADES := "res://assets/trades/"
# A varied tab color per brand (cosmetic for now).
const COLORS := [
	Color("e84855"), Color("2d7dd2"), Color("f4c430"), Color("9b5de5"),
	Color("43aa8b"), Color("f3722c"), Color("577590"), Color("d62246"), Color("90be6d"),
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var dir := DirAccess.open(TRADES)
	var made := 0
	var i := 0
	for file in dir.get_files():
		if not file.ends_with(".webp"):
			continue
		var base := file.get_basename()  # e.g. VISSE_ET_VRILLE
		var e := EnseigneDefinition.new()
		e.id = StringName(base.to_lower())
		e.display_name = base.replace("_", " ").capitalize()
		e.texture = load(TRADES + file)
		e.color = COLORS[i % COLORS.size()]
		if ResourceSaver.save(e, DIR + e.id + ".tres") == OK:
			made += 1
		i += 1
	print("Generated %d enseignes." % made)
	quit()
```

- [ ] **Step 2: Write the destinataire generator**

`tools/generate_destinataires.gd` :
```gdscript
extends SceneTree
## Dev tool: builds resources/destinataires/*.tres from a built-in list of parody names.
## Run: godot --headless --path . -s res://tools/generate_destinataires.gd

const DIR := "res://resources/destinataires/"
# id, display_name, banner color
const NAMES := [
	["mamie_turbo", "Mamie Turbo", "9b5de5"],
	["jean_mi_carton", "Jean-Mi Carton", "d62246"],
	["vero_locale", "Véro Locale", "f3722c"],
	["capitaine_apero", "Capitaine Apéro", "2d7dd2"],
	["tata_ginette", "Tata Ginette", "e84855"],
	["dj_frigo", "DJ Frigo", "f4c430"],
	["m_pantoufle", "M. Pantoufle", "43aa8b"],
	["lea_du_5e", "Léa du 5ᵉ", "577590"],
	["papi_brouette", "Papi Brouette", "90be6d"],
	["mme_coupon", "Mme Coupon", "c77dff"],
	["famille_chut", "Famille Chut", "ff7043"],
	["coach_gilbert", "Coach Gilbert", "4cc9f0"],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var made := 0
	for row in NAMES:
		var d := DestinataireDefinition.new()
		d.id = StringName(row[0])
		d.display_name = row[1]
		d.color = Color(row[2])
		if ResourceSaver.save(d, DIR + row[0] + ".tres") == OK:
			made += 1
	print("Generated %d destinataires." % made)
	quit()
```

- [ ] **Step 3: Run both generators (after import)**

Run:
```bash
flatpak run org.godotengine.Godot --headless --path . --import
flatpak run org.godotengine.Godot --headless --path . -s res://tools/generate_enseignes.gd
flatpak run org.godotengine.Godot --headless --path . -s res://tools/generate_destinataires.gd
```
Expected: `Generated 9 enseignes.` and `Generated 12 destinataires.`

- [ ] **Step 4: Verify the files exist**

Run: `ls resources/enseignes/*.tres | wc -l && ls resources/destinataires/*.tres | wc -l`
Expected: `9` then `12`.

- [ ] **Step 5: Commit**

```bash
git add tools/generate_enseignes.gd tools/generate_destinataires.gd resources/enseignes resources/destinataires
git commit -m "feat(resources): enseignes (depuis assets/trades) + destinataires parodiques"
```

---

## Task 6: ClipCardView (rendu 3D d'un combo)

**Files:**
- Create: `src/view/clip_card_view.gd`
- Test: `tests/test_clip_card_view.gd`

- [ ] **Step 1: Write the failing smoke test**

`tests/test_clip_card_view.gd` :
```gdscript
extends GutTest
## Smoke test for ClipCardView: binding a combo builds the enseigne and destinataire parts; the status
## insert appears only when the combo is not DISPONIBLE.


func _combo(status: int) -> DeliveryCombo:
	var e := EnseigneDefinition.new()
	e.display_name = "VISSE & VRILLE"
	var d := DestinataireDefinition.new()
	d.display_name = "Véro Locale"
	var c := DeliveryCombo.new(e, d)
	c.status = status
	return c


func test_bind_available_has_no_status_insert() -> void:
	var view := ClipCardView.new()
	add_child_autofree(view)
	view.bind(_combo(DeliveryStatus.Kind.DISPONIBLE))
	assert_false(view.has_status_insert(), "no insert while available")


func test_bind_reserved_shows_status_insert() -> void:
	var view := ClipCardView.new()
	add_child_autofree(view)
	view.bind(_combo(DeliveryStatus.Kind.RESERVE))
	assert_true(view.has_status_insert(), "insert shown when reserved")
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command for `test_clip_card_view.gd`.
Expected: Parse Error — `ClipCardView` not declared.

- [ ] **Step 3: Write minimal implementation**

`src/view/clip_card_view.gd` :
```gdscript
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
	_add_card(Vector3(step, 0.0, 0.0), CARD, combo.destinataire.color if combo.destinataire else Color("33384a"),
		combo.destinataire.display_name if combo.destinataire else "(vide)", combo.destinataire.texture if combo.destinataire else null)
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


func _add_card(at: Vector3, size: Vector2, color: Color, name: String, texture: Texture2D) -> void:
	var slab := _make_slab(at, size, color)
	if texture != null:
		slab.add_child(_make_image(texture, size))
	slab.add_child(_make_label(name, Color("101218"), size.x * 0.9))
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
```

- [ ] **Step 4: Run import then the test**

Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```bash
git add src/view/clip_card_view.gd tests/test_clip_card_view.gd
git commit -m "feat(view): ClipCardView (combo enseigne/statut/destinataire en 3D)"
```

---

## Task 7: Démo autonome (scène + script)

**Files:**
- Create: `src/enseigne_demo.gd`, `scenes/enseigne_demo.tscn`

- [ ] **Step 1: Write the demo script**

`src/enseigne_demo.gd` (caméra orbite/zoom + tapis repris de `src/card_demo.gd`) :
```gdscript
extends Node3D
## Standalone demo for the delivery-combo generator. A felt mat shows a column of clipped combos
## (enseigne + status insert + destinataire). Click a combo to advance its status; once EN_COURS, the
## next click delivers it — the recipient is discarded and a new one is clipped from the pool until it
## runs out. Drag to orbit, wheel to zoom.

const ENSEIGNES_DIR := "res://resources/enseignes/"
const DESTINATAIRES_DIR := "res://resources/destinataires/"
const SLOTS := 4
const ROW_STEP := 1.7  # vertical spacing between combos on the mat

var _generator: DeliveryGenerator
var _views: Array[ClipCardView] = []
var _count_label: Label

var _camera_pivot: Node3D
var _camera: Camera3D
var _orbit_yaw := 0.0
var _orbit_pitch := -55.0
var _orbit_distance := 12.0
var _orbiting := false


func _ready() -> void:
	_build_camera()
	_build_light()
	_build_environment()
	_build_mat()
	_build_hud()

	_generator = DeliveryGenerator.new(_load_enseignes(), _load_destinataires(), SLOTS)
	_generator.combo_changed.connect(_on_combo_changed)
	_generator.recycled.connect(_on_combo_changed)
	_build_views()
	_refresh_count()


func _build_views() -> void:
	for view in _views:
		view.queue_free()
	_views.clear()
	var combos := _generator.combos()
	var top := (combos.size() - 1) * 0.5 * ROW_STEP
	for i in combos.size():
		var view := ClipCardView.new()
		add_child(view)
		view.bind(combos[i])
		view.position = Vector3(0.0, 0.0, top - i * ROW_STEP)
		_views.append(view)


func _on_combo_changed(index: int) -> void:
	if index < _views.size():
		_views[index].refresh()
	_refresh_count()


# --- Interaction -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_left_pressed(event.position)
				else:
					_orbiting = false
			MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(5.0, _orbit_distance - 0.7)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(28.0, _orbit_distance + 0.7)
				_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		_orbit_yaw -= event.relative.x * 0.4
		_orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.4, -85.0, -15.0)
		_update_camera()


func _on_left_pressed(screen_pos: Vector2) -> void:
	var index := _combo_under(screen_pos)
	if index < 0:
		_orbiting = true
		return
	var combo := _generator.combos()[index]
	if combo.status == DeliveryStatus.Kind.EN_COURS:
		_generator.complete(index)
	else:
		_generator.advance(index)


# Index of the combo view nearest the cursor ray (within a radius), or -1.
func _combo_under(screen_pos: Vector2) -> int:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best := -1
	var best_along := INF
	for i in _views.size():
		var to_center: Vector3 = _views[i].global_position - origin
		var along := to_center.dot(dir)
		if along <= 0.0:
			continue
		var closest := origin + dir * along
		if closest.distance_to(_views[i].global_position) <= 1.4 and along < best_along:
			best_along = along
			best = i
	return best


func _refresh_count() -> void:
	_count_label.text = "Destinataires restants dans la pioche : %d" % _generator.remaining_recipients()


# --- Data --------------------------------------------------------------------

func _load_enseignes() -> Array[EnseigneDefinition]:
	var result: Array[EnseigneDefinition] = []
	var dir := DirAccess.open(ENSEIGNES_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(ENSEIGNES_DIR + file))
	return result


func _load_destinataires() -> Array[DestinataireDefinition]:
	var result: Array[DestinataireDefinition] = []
	var dir := DirAccess.open(DESTINATAIRES_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(DESTINATAIRES_DIR + file))
	return result


# --- Scaffolding (mirrors card_demo) -----------------------------------------

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 50.0
	_camera_pivot.add_child(_camera)
	_camera.current = true
	_update_camera()


func _update_camera() -> void:
	_camera_pivot.rotation_degrees = Vector3(_orbit_pitch, _orbit_yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _orbit_distance)
	_camera.rotation = Vector3.ZERO


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -35, 0)
	light.shadow_enabled = true
	add_child(light)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2330")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a0")
	env.ambient_light_energy = 0.9
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _build_mat() -> void:
	var mat := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9.0, 9.0)
	mat.mesh = plane
	mat.position = Vector3(0.0, -0.06, 0.0)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("1f4a3a")
	mat.material_override = felt
	add_child(mat)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = "Clic sur une livraison : avancer son statut (Disponible → Réservé → En cours → Livrer = recyclage)   •   Glisser : orbiter   •   Molette : zoom"
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_count_label = Label.new()
	_count_label.position = Vector2(16, 36)
	layer.add_child(_count_label)
	add_child(layer)
```

- [ ] **Step 2: Create the demo scene**

`scenes/enseigne_demo.tscn` :
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/enseigne_demo.gd" id="1_demo"]

[node name="EnseigneDemo" type="Node3D"]
script = ExtResource("1_demo")
```

- [ ] **Step 3: Import and launch the demo to verify**

Run: `flatpak run org.godotengine.Godot --headless --path . --import` (expect no SCRIPT ERROR), then launch interactively:
`flatpak run org.godotengine.Godot --path res://scenes/enseigne_demo.tscn` (or open the scene in the editor and play it).
Expected: a felt mat with 4 clipped combos; clicking a combo advances its status (an insert appears at RÉSERVÉ/EN COURS); a 2nd click at EN COURS delivers and clips a fresh destinataire; the remaining-recipients counter decreases; orbit/zoom work.

- [ ] **Step 4: Commit**

```bash
git add src/enseigne_demo.gd scenes/enseigne_demo.tscn
git commit -m "feat(demo): scène enseigne_demo (clip de combos interactif)"
```

---

## Task 8: Vérification finale

- [ ] **Step 1: Run the whole suite**

Run: `flatpak run org.godotengine.Godot --headless --path . -s res://addons/gut/gut_cmdln.gd`
Expected: tous les tests passent (la base + les nouveaux : enseigne/destinataire definitions, delivery_combo, delivery_generator, clip_card_view).

- [ ] **Step 2: Manual playtest of the demo**

Launch the demo scene and confirm the full cycle (random pairing, status advance, recycling, pool exhaustion leaving an empty enseigne).

- [ ] **Step 3: Commit any fixes**

```bash
git add -A && git commit -m "test: vérification du module cartes enseigne/destinataire"
```

---

## Self-review notes

- **Spec coverage** : EnseigneDefinition (T1), DestinataireDefinition (T2), DeliveryStatus+Combo (T3), DeliveryGenerator avec appariement/cycle/recyclage/épuisement (T4), ressources (T5), ClipCardView rendu clipsé + encart statut (T6), démo 3D orbite/zoom/clic + recyclage animé visuel (T7), vérif (T8). ✓
- **Cohérence des types** : `DeliveryStatus.Kind`, `DeliveryCombo.advance()/is_available()/is_done()`, `DeliveryGenerator.combos()/advance()/complete()/remaining_recipients()`, `ClipCardView.bind()/refresh()/has_status_insert()` — utilisés de façon identique partout. ✓
- **Anti-collision** : aucun `Delivery`/`DeliverySetup` (réservés à la PR gameplay). ✓
- **Placeholder** : aucun — chaque étape porte le code/commande réels.
