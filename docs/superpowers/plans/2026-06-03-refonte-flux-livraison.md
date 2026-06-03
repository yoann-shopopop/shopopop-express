# Refonte du flux de livraison — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Doter le jeu spatial d'un cycle de livraison à 4 statuts (Disponible → Réservé → En cours → Terminé) piloté par la position du pion, avec un scoring fondé sur la couleur unique du joueur.

**Architecture:** Approche A — porter le cycle sur le `Delivery` spatial (`src/game/`), réutiliser l'enum `DeliveryStatus` de `src/livraisons/`, conserver `DeliveryGenerator` pour le recyclage. La démo `enseigne_demo` n'est pas modifiée. Logique pure testée en GUT ; vue/UI (`GameRoot`/`GameUI`) vérifiées par import + boot.

**Tech Stack:** Godot 4.6, GDScript, GUT (tests headless).

**Conventions de commande** (binaire macOS) :
- Import : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Un fichier de test : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/<fichier>.gd -gexit`
- Suite complète : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit`

> Référence rapide : `DeliveryStatus.Kind` ∈ `{ DISPONIBLE, RESERVE, EN_COURS, LIVREE }` (`src/livraisons/delivery_status.gd`).

---

## Task 1 : `Delivery` — statut + réservation

**Files:**
- Modify: `src/game/delivery.gd`
- Test: `tests/test_delivery.gd`

- [ ] **Step 1 : Réécrire le test `tests/test_delivery.gd`**

Remplacer intégralement le contenu par :

```gdscript
extends GutTest
## Tests for Delivery — a drive→recipient link, its tile owners, and its status lifecycle.


func _piece(owner: int) -> PlacedPiece:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return PlacedPiece.new(b, Vector2i.ZERO, 0, owner)


func _delivery(owner: int) -> Delivery:
	return Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [_piece(owner)] as Array[PlacedPiece])


func test_single_tile_delivery() -> void:
	var d := _delivery(PlayerColor.Kind.RED)
	assert_true(d.is_single_tile())
	assert_eq(d.drive_tile_owner(), PlayerColor.Kind.RED)
	assert_eq(d.recipient_tile_owner(), PlayerColor.Kind.RED)


func test_two_tile_delivery_owners_are_drive_then_recipient() -> void:
	var tiles := [_piece(PlayerColor.Kind.RED), _piece(PlayerColor.Kind.BLUE)] as Array[PlacedPiece]
	var d := Delivery.new(Vector2i(0, 0), Vector2i(5, 0), tiles)
	assert_eq(d.drive_tile_owner(), PlayerColor.Kind.RED)
	assert_eq(d.recipient_tile_owner(), PlayerColor.Kind.BLUE)


func test_starts_disponible_and_unreserved() -> void:
	var d := _delivery(0)
	assert_eq(d.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_eq(d.reserved_by, -1)


func test_is_reservable_requires_disponible_with_a_recipient() -> void:
	var d := _delivery(0)
	assert_false(d.is_reservable(), "no recipient yet")
	d.destinataire = DestinataireDefinition.new()
	assert_true(d.is_reservable(), "disponible + recipient")
	d.status = DeliveryStatus.Kind.RESERVE
	assert_false(d.is_reservable(), "already reserved")


func test_recycle_clips_a_new_recipient_and_resets_state() -> void:
	var d := _delivery(0)
	d.status = DeliveryStatus.Kind.EN_COURS
	d.reserved_by = 2
	var fresh := DestinataireDefinition.new()
	fresh.id = &"fresh"
	d.recycle(fresh)
	assert_eq(d.destinataire, fresh)
	assert_eq(d.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_eq(d.reserved_by, -1)
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_delivery.gd -gexit`
Expected : FAIL (méthodes `drive_tile_owner`/`recipient_tile_owner`/`is_reservable` et champ `status`/`reserved_by` inexistants).

- [ ] **Step 3 : Modifier `src/game/delivery.gd`**

Remplacer les champs `picked_up`/`delivered`/`carrier_index` et la méthode `recycle`, et ajouter les accesseurs. Le fichier devient :

```gdscript
class_name Delivery
extends RefCounted
## A delivery links a drive (pickup, on a grey/urban cell) to a recipient (on a green cell). It spans
## one or two tiles ([member tiles]). Its lifecycle is the 4-status cycle ([DeliveryStatus]); scoring
## rewards the drive tile and the recipient tile when they are the carrier's color. Pure data — no
## nodes. [ScoreCalculator] reads it; [GamePhase] drives its status.

var drive_cell: Vector2i
var recipient_cell: Vector2i
var tiles: Array[PlacedPiece]          ## the 1 or 2 placed pieces this delivery covers
var enseigne: EnseigneDefinition       ## the pickup brand at the drive (fixed per tile)
var destinataire: DestinataireDefinition  ## the current recipient at the green cell (recycled on delivery)
var status: int = DeliveryStatus.Kind.DISPONIBLE  ## DeliveryStatus.Kind
var reserved_by: int = -1              ## seat index of the player who reserved/carries it, or -1


func _init(p_drive: Vector2i, p_recipient: Vector2i, p_tiles: Array[PlacedPiece]) -> void:
	drive_cell = p_drive
	recipient_cell = p_recipient
	tiles = p_tiles


## Clips a new recipient and makes the delivery available again (used at setup and when recycling after
## delivery). A null recipient leaves the drive "free" (inactive — nothing left to deliver).
func recycle(p_destinataire: DestinataireDefinition) -> void:
	destinataire = p_destinataire
	status = DeliveryStatus.Kind.DISPONIBLE
	reserved_by = -1


## True when the delivery can be reserved: available and still carrying a recipient.
func is_reservable() -> bool:
	return status == DeliveryStatus.Kind.DISPONIBLE and destinataire != null


## True when the drive and recipient sit on the same single tile.
func is_single_tile() -> bool:
	return tiles.size() == 1


## District color (PlayerColor.Kind) of the tile holding the drive (first tile), or -1.
func drive_tile_owner() -> int:
	return tiles[0].owner if not tiles.is_empty() else -1


## District color (PlayerColor.Kind) of the tile holding the recipient (last tile), or -1.
func recipient_tile_owner() -> int:
	return tiles[tiles.size() - 1].owner if not tiles.is_empty() else -1
```

- [ ] **Step 4 : Lancer le test, vérifier le succès**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_delivery.gd -gexit`
Expected : PASS (5/5).

- [ ] **Step 5 : Commit**

```bash
git add src/game/delivery.gd tests/test_delivery.gd
git commit -m "feat(livraison): Delivery porte le cycle de statut (Disponible/Réservé/En cours/Livré)"
```

---

## Task 2 : `ScoreCalculator` — score sur la couleur du joueur

**Files:**
- Modify: `src/game/score_calculator.gd`
- Test: `tests/test_score_calculator.gd`

- [ ] **Step 1 : Réécrire `tests/test_score_calculator.gd`**

```gdscript
extends GutTest
## Tests for ScoreCalculator — BASE(5) + 10 si la tuile du drive est ma couleur + 10 si la tuile du
## destinataire est ma couleur. Mono-tuile ⇒ 5 ou 25.


const RED := PlayerColor.Kind.RED
const BLUE := PlayerColor.Kind.BLUE


func _piece(owner: int) -> PlacedPiece:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return PlacedPiece.new(b, Vector2i.ZERO, 0, owner)


func _delivery(owners: Array[int]) -> Delivery:
	var tiles: Array[PlacedPiece] = []
	for o in owners:
		tiles.append(_piece(o))
	return Delivery.new(Vector2i(0, 0), Vector2i(1, 0), tiles)


func test_single_tile_that_is_mine_scores_twentyfive() -> void:
	var d := _delivery([RED])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 25)


func test_single_tile_not_mine_scores_only_the_base() -> void:
	var d := _delivery([BLUE])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 5)


func test_two_tiles_only_drive_is_mine_scores_fifteen() -> void:
	var d := _delivery([RED, BLUE])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 15)


func test_two_tiles_only_recipient_is_mine_scores_fifteen() -> void:
	var d := _delivery([BLUE, RED])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 15)


func test_two_tiles_both_mine_score_twentyfive() -> void:
	var d := _delivery([RED, RED])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 25)
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_score_calculator.gd -gexit`
Expected : FAIL (signature `score_delivery(delivery, character)` incompatible avec un `int`).

- [ ] **Step 3 : Réécrire `src/game/score_calculator.gd`**

```gdscript
class_name ScoreCalculator
extends RefCounted
## Scores a delivery for its carrier. Pure, static.
##
## Formule (règles 2026-06) : [constant BASE] points, +[constant PER_TILE_OWNED] si la tuile du drive
## est de la couleur du joueur, +[constant PER_TILE_OWNED] si la tuile du destinataire l'est aussi.
## Mono-tuile (drive et destinataire sur la même tuile) ⇒ 5 (aucune) ou 25 (tuile à soi).

const BASE := 5
const PER_TILE_OWNED := 10


## Points the [param delivery] is worth for a carrier of district color [param color] (PlayerColor.Kind).
static func score_delivery(delivery: Delivery, color: int) -> int:
	var score := BASE
	if delivery.drive_tile_owner() == color:
		score += PER_TILE_OWNED
	if delivery.recipient_tile_owner() == color:
		score += PER_TILE_OWNED
	return score
```

- [ ] **Step 4 : Lancer le test, vérifier le succès**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_score_calculator.gd -gexit`
Expected : PASS (5/5).

- [ ] **Step 5 : Commit**

```bash
git add src/game/score_calculator.gd tests/test_score_calculator.gd
git commit -m "feat(score): livraison = 5 + 10 (tuile drive) + 10 (tuile destinataire) sur la couleur du joueur"
```

---

## Task 3 : `GamePhase` — réservation manuelle + transitions auto + recyclage

**Files:**
- Modify: `src/game/game_phase.gd`
- Test: `tests/test_game_phase.gd`

- [ ] **Step 1 : Remplacer la section « Deliveries » des tests**

Dans `tests/test_game_phase.gd`, remplacer les fonctions de test entre le commentaire `# --- Deliveries ---` (ligne ~80) et le commentaire `# --- Events & powers ---` (exclu) par le bloc suivant. Conserver le helper `_red_character()` (réutilisé), `_phase_with_delivery()`, et **remplacer** les trois tests `test_select_delivery_reserves_it`, `test_pickup_costs_one_extra_step`, `test_delivering_scores_and_finishes_the_game` :

```gdscript
# --- Deliveries -------------------------------------------------------------

# A character (kept for parity with real players; scoring now uses player.color).
func _red_character() -> CharacterDefinition:
	var c := CharacterDefinition.new()
	c.colors = [PlayerColor.Kind.RED]
	return c


# A phase with one RED tile and a delivery drive=(1,0) / recipient=(2,0) (both road cells, walkable).
# One RED player starting on the tile's green cell (0,0). The delivery has a recipient clipped.
func _phase_with_delivery() -> GamePhase:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	var delivery := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
	delivery.destinataire = DestinataireDefinition.new()  # reservable
	return GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery])


func test_reserve_delivery_on_the_tile_sets_reserve() -> void:
	var phase := _phase_with_delivery()
	phase.begin_movement(3)  # pawn on (0,0), which belongs to the tile
	assert_true(phase.reserve_delivery(), "reservable from the tile")
	assert_eq(phase.available_deliveries().size(), 0, "no longer available")
	assert_eq(phase.deliveries_in_flight(0).size(), 1)


func test_cannot_reserve_outside_deplacement() -> void:
	var phase := _phase_with_delivery()
	assert_false(phase.reserve_delivery(), "still PLANIFICATION")


func test_stepping_onto_the_drive_cell_sets_en_cours() -> void:
	var phase := _phase_with_delivery()
	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))  # the drive cell
	assert_eq(phase.deliveries_in_flight(0)[0].status, DeliveryStatus.Kind.EN_COURS)


func test_stepping_onto_the_recipient_scores_and_is_free() -> void:
	var phase := _phase_with_delivery()
	var player := phase.current_player()
	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))  # drive -> EN_COURS
	phase.try_step(Vector2i(2, 0))  # recipient -> delivered
	assert_eq(phase.score_of(player), 25, "single tile that is mine")
	assert_eq(phase.movement().remaining(), 1, "two steps from a budget of 3, reservation is free")
	assert_true(phase.is_finished(), "the only delivery is done, no recycling")


func test_cannot_reserve_more_than_two_in_flight() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	# Three deliveries pinned to the same tile (unrealistic, but exercises the cap purely).
	var deliveries: Array[Delivery] = []
	for i in 3:
		var d := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
		d.destinataire = DestinataireDefinition.new()
		deliveries.append(d)
	var phase := GamePhase.new([player] as Array[Player], board, deliveries)
	phase.begin_movement(3)
	# Mark two as already in flight for player 0.
	deliveries[0].status = DeliveryStatus.Kind.RESERVE
	deliveries[0].reserved_by = 0
	deliveries[1].status = DeliveryStatus.Kind.EN_COURS
	deliveries[1].reserved_by = 0
	assert_eq(phase.deliveries_in_flight(0).size(), 2)
	assert_null(phase.reservable_delivery(), "cap of 2 reached")
	assert_false(phase.reserve_delivery())
```

- [ ] **Step 2 : Adapter la section recyclage des tests**

Remplacer `_deliver_once()` et les deux tests de recyclage par :

```gdscript
# Reserves on the start tile then walks drive->recipient (all free now).
func _deliver_once(phase: GamePhase) -> void:
	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(2, 0))


func test_delivery_recycles_and_game_continues_when_pool_has_spares() -> void:
	var ctx := _phase_with_generator(2)  # 1 used at init, 1 spare
	var phase: GamePhase = ctx["phase"]
	var delivery: Delivery = ctx["delivery"]
	_deliver_once(phase)
	assert_eq(delivery.status, DeliveryStatus.Kind.DISPONIBLE, "recycled, available again")
	assert_not_null(delivery.destinataire, "a new recipient was clipped")
	assert_false(phase.is_finished())
	assert_eq(phase.available_deliveries().size(), 1)


func test_game_finishes_when_the_recipient_pool_is_exhausted() -> void:
	var ctx := _phase_with_generator(1)  # no spare
	var phase: GamePhase = ctx["phase"]
	var delivery: Delivery = ctx["delivery"]
	_deliver_once(phase)
	assert_null(delivery.destinataire, "pool empty -> drive left free")
	assert_eq(delivery.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_true(phase.is_finished())
```

> `_phase_with_generator()` reste inchangé sauf sa dernière ligne de mapping qui utilise déjà
> `delivery.destinataire = generator.combos()[0].destinataire` — OK.

- [ ] **Step 3 : Lancer le test, vérifier l'échec**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_phase.gd -gexit`
Expected : FAIL (`reserve_delivery`/`reservable_delivery`/`deliveries_in_flight` inexistants ; ancien score 20).

- [ ] **Step 4 : Réécrire la section livraisons de `src/game/game_phase.gd`**

a) Dans la liste des signaux (lignes ~19-22), **remplacer** :
```gdscript
## A delivery was reserved by the current player during planning.
signal delivery_picked(delivery: Delivery)
```
par :
```gdscript
## A delivery was reserved by the current player (stepping onto its tile).
signal delivery_reserved(delivery: Delivery)
## A reserved delivery became EN_COURS (the pawn reached its drive cell).
signal delivery_in_progress(delivery: Delivery)
```

b) Ajouter une constante près du haut de la classe (après les `var` d'état, avant `_init`) :
```gdscript
const MAX_IN_FLIGHT := 2  # deliveries a player may hold (RESERVE + EN_COURS) at once
```

c) **Supprimer** le champ `var _carrying: Dictionary = {} ...`.

d) Dans `begin_movement`, remplacer `_context.current_delivery = current_delivery()` par :
```gdscript
	_context.current_delivery = _primary_delivery(_current)
```

e) À la fin de `try_step`, **avant** le bloc `if _board.cell_type_at(cell) == CellType.Kind.EVENT:`, insérer :
```gdscript
	_check_delivery_transitions()
```

f) **Remplacer tout le bloc `# --- Deliveries ---`** (depuis `func available_deliveries()` jusqu'à `func _score_for(...)` inclus, c.-à-d. les méthodes `available_deliveries`, `current_delivery`, `select_delivery`, `confirm_pickup`, `_available_delivery_at`, `confirm_delivery`, `score_of`, `scores`, `is_finished`, `_score_for`) par :

```gdscript
# --- Deliveries -------------------------------------------------------------

## Deliveries still reservable: DISPONIBLE with a recipient clipped (drive not "free").
func available_deliveries() -> Array[Delivery]:
	var result: Array[Delivery] = []
	for delivery in _deliveries:
		if delivery.is_reservable():
			result.append(delivery)
	return result


## In-flight deliveries (RESERVE or EN_COURS) held by [param player_index].
func deliveries_in_flight(player_index: int) -> Array[Delivery]:
	var result: Array[Delivery] = []
	for delivery in _deliveries:
		if delivery.reserved_by == player_index \
				and (delivery.status == DeliveryStatus.Kind.RESERVE \
					or delivery.status == DeliveryStatus.Kind.EN_COURS):
			result.append(delivery)
	return result


## The reservable delivery on the current pawn's tile, or null. Requires the player to hold fewer than
## [constant MAX_IN_FLIGHT] deliveries.
func reservable_delivery() -> Delivery:
	if deliveries_in_flight(_current).size() >= MAX_IN_FLIGHT:
		return null
	var tile := _board.piece_at(position_of(current_player()))
	if tile == null:
		return null
	for delivery in _deliveries:
		if delivery.is_reservable() and not delivery.tiles.is_empty() and delivery.tiles[0] == tile:
			return delivery
	return null


## Reserves the delivery on the current tile for the current player (only during DEPLACEMENT).
func reserve_delivery() -> bool:
	if _subphase != SubPhase.DEPLACEMENT:
		return false
	var delivery := reservable_delivery()
	if delivery == null:
		return false
	delivery.status = DeliveryStatus.Kind.RESERVE
	delivery.reserved_by = _current
	delivery_reserved.emit(delivery)
	_check_delivery_transitions()
	return true


# Drives automatic transitions from the current pawn position; called after each step and after a
# reservation. RESERVE -> EN_COURS on the drive cell; EN_COURS -> delivery on the recipient cell.
func _check_delivery_transitions() -> void:
	var cell := position_of(current_player())
	for delivery in deliveries_in_flight(_current):
		if delivery.status == DeliveryStatus.Kind.RESERVE and cell == delivery.drive_cell:
			delivery.status = DeliveryStatus.Kind.EN_COURS
			delivery_in_progress.emit(delivery)
		if delivery.status == DeliveryStatus.Kind.EN_COURS and cell == delivery.recipient_cell:
			_complete_delivery(delivery)
	if _context != null:
		_context.current_delivery = _primary_delivery(_current)


# Scores [param delivery], recycles a new recipient (or leaves the drive free), checks for game end.
func _complete_delivery(delivery: Delivery) -> void:
	var points := _score_for(current_player(), delivery)
	if _context != null and _context.double_score:
		points *= 2  # Livraison Écologique
	_scores[_current] += points
	if _generator != null:
		var idx := _deliveries.find(delivery)
		var next: DestinataireDefinition = null
		if idx >= 0:
			next = _generator.recycle(idx)
		delivery.recycle(next)
	else:
		delivery.recycle(null)  # no recycling source: the drive is done
	delivery_completed.emit(delivery, points)
	if is_finished():
		game_finished.emit(scores())


# The delivery "in hand" for [param player_index]: the EN_COURS one if any, else a RESERVE one, else
# null. Used by event teleports.
func _primary_delivery(player_index: int) -> Delivery:
	var reserved: Delivery = null
	for delivery in deliveries_in_flight(player_index):
		if delivery.status == DeliveryStatus.Kind.EN_COURS:
			return delivery
		reserved = delivery
	return reserved


## Total points scored by [param player].
func score_of(player: Player) -> int:
	return _scores.get(player.index, 0)


## All players' totals, keyed by seat index.
func scores() -> Dictionary:
	return _scores.duplicate()


## True once no delivery remains actionable: every delivery is DISPONIBLE with no recipient (pool
## exhausted, nothing in flight). False on a board that never had a delivery.
func is_finished() -> bool:
	if _deliveries.is_empty():
		return false
	for delivery in _deliveries:
		if delivery.status != DeliveryStatus.Kind.DISPONIBLE or delivery.destinataire != null:
			return false
	return true


func _score_for(player: Player, delivery: Delivery) -> int:
	return ScoreCalculator.score_delivery(delivery, player.color)
```

- [ ] **Step 5 : Lancer le test, vérifier le succès**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_phase.gd -gexit`
Expected : PASS (tous les tests du fichier, dont événements/pouvoirs inchangés).

- [ ] **Step 6 : Commit**

```bash
git add src/game/game_phase.gd tests/test_game_phase.gd
git commit -m "feat(game): cycle de livraison piloté par la position (réserve sur la tuile, En cours/Livré auto, gratuit, 2 max)"
```

---

## Task 4 : `EventResolver` — migrer `picked_up` vers le statut

**Files:**
- Modify: `src/game/event_resolver.gd`
- Test: `tests/test_event_resolver.gd` (déjà compatible, on vérifie)

- [ ] **Step 1 : Modifier `src/game/event_resolver.gd`**

Dans le cas `E.TELEPORT_DESTINATION` (lignes ~35-39), remplacer :
```gdscript
		E.TELEPORT_DESTINATION:
			if ctx.current_delivery != null:
				var target := ctx.current_delivery.recipient_cell if ctx.current_delivery.picked_up \
					else ctx.current_delivery.drive_cell
				ctx.movement.teleport_to(target)
```
par :
```gdscript
		E.TELEPORT_DESTINATION:
			if ctx.current_delivery != null:
				var target := ctx.current_delivery.recipient_cell \
					if ctx.current_delivery.status == DeliveryStatus.Kind.EN_COURS \
					else ctx.current_delivery.drive_cell
				ctx.movement.teleport_to(target)
```

- [ ] **Step 2 : Lancer les tests d'événements + game_phase, vérifier le succès**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_event_resolver.gd,res://tests/test_game_phase.gd -gexit`
Expected : PASS (le test `test_teleport_destination_goes_to_the_drive_before_pickup` reste vert : statut DISPONIBLE par défaut ⇒ drive).

- [ ] **Step 3 : Commit**

```bash
git add src/game/event_resolver.gd
git commit -m "refactor(events): téléport destination lit le statut EN_COURS au lieu de picked_up"
```

---

## Task 5 : `GameUI` — bouton « Réserver »

**Files:**
- Modify: `src/ui/game_ui.gd`

> Couche Node, non testée par GUT : validée par import + boot (Task 7).

- [ ] **Step 1 : Modifier les signaux de `src/ui/game_ui.gd`**

Remplacer (lignes ~7-11) :
```gdscript
signal roll_requested
signal end_turn_requested
signal pickup_requested
signal deliver_requested
signal power_requested
```
par :
```gdscript
signal roll_requested
signal end_turn_requested
signal reserve_requested
signal power_requested
```

Et la docstring de classe (lignes 3-5) : remplacer `(roll dice, pick up, deliver, power, end turn)` par `(lancer les dés, réserver, pouvoir, fin de tour)`.

- [ ] **Step 2 : Modifier `refresh()`**

Remplacer la signature et le bloc pickup/deliver. Remplacer :
```gdscript
func refresh(player: Player, score: int, can_roll: bool, carrying: Delivery) -> void:
```
par :
```gdscript
func refresh(player: Player, score: int, can_roll: bool, can_reserve: bool) -> void:
```

Puis remplacer le bloc (lignes ~101-108) :
```gdscript
	if carrying == null:
		var pickup := _button("Prendre", Vector2(120, 48))
		pickup.pressed.connect(func() -> void: pickup_requested.emit())
		_actions.add_child(pickup)
	else:
		var deliver := _button("Livrer", Vector2(120, 48))
		deliver.pressed.connect(func() -> void: deliver_requested.emit())
		_actions.add_child(deliver)
```
par :
```gdscript
	var reserve := _button("Réserver", Vector2(120, 48))
	reserve.disabled = not can_reserve
	reserve.pressed.connect(func() -> void: reserve_requested.emit())
	_actions.add_child(reserve)
```

- [ ] **Step 3 : Vérifier la compilation (import)**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
Expected : DONE sans erreur de parse (`game_ui.gd`).

- [ ] **Step 4 : Commit**

```bash
git add src/ui/game_ui.gd
git commit -m "feat(ui): bouton Réserver (remplace Prendre/Livrer, devenus automatiques)"
```

---

## Task 6 : `GameRoot` — câblage réservation + transitions + repère de statut

**Files:**
- Modify: `src/game/game_root.gd`

- [ ] **Step 1 : Ajouter un dictionnaire de repères de statut**

Après la ligne `var _recipient_markers: Dictionary = {}  # Delivery -> Node3D (rebuilt on recycle)` (~ligne 20), ajouter (var membre au niveau classe, **sans** tabulation de tête) :
```gdscript
var _status_rings: Dictionary = {}     # Delivery -> Node3D (status disc on the drive cell)
```

- [ ] **Step 2 : Mettre à jour les branchements de signaux dans `setup()`**

Remplacer (lignes ~68-69) :
```gdscript
	_ui.pickup_requested.connect(_on_pickup)
	_ui.deliver_requested.connect(_on_deliver)
```
par :
```gdscript
	_ui.reserve_requested.connect(_on_reserve)
	_phase.delivery_reserved.connect(_on_delivery_changed)
	_phase.delivery_in_progress.connect(_on_delivery_changed)
```

- [ ] **Step 3 : Remplacer `_on_pickup`/`_on_deliver` par `_on_reserve` + repère de statut**

Remplacer les deux fonctions `_on_pickup()` et `_on_deliver()` (lignes ~254-266) par :
```gdscript
func _on_reserve() -> void:
	if _phase.reserve_delivery():
		_ui.set_status("Livraison réservée.")
	else:
		_ui.set_status("Aucune livraison à réserver sur cette tuile.")
	_refresh_highlights()
	_refresh_ui()


# A delivery's status changed (reserved / en cours): refresh its status disc and the action bar.
func _on_delivery_changed(delivery: Delivery) -> void:
	_update_status_ring(delivery)
	_refresh_ui()


# A small disc on the drive cell echoing the delivery status: the reserving player's color when
# RESERVE, a brighter accent when EN_COURS, removed otherwise.
func _update_status_ring(delivery: Delivery) -> void:
	var existing = _status_rings.get(delivery, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
		_status_rings.erase(delivery)
	var color: Color
	match delivery.status:
		DeliveryStatus.Kind.RESERVE:
			color = PlayerColor.to_color(_players[delivery.reserved_by].color)
			color.a = 0.55
		DeliveryStatus.Kind.EN_COURS:
			color = Color(1.0, 0.95, 0.4, 0.85)
		_:
			return  # DISPONIBLE / LIVREE: no ring
	var inst := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = GameConfig.HEX_SIZE * 0.42
	mesh.outer_radius = GameConfig.HEX_SIZE * 0.6
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(delivery.drive_cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + 0.08
	inst.position = pos
	add_child(inst)
	_status_rings[delivery] = inst
```

- [ ] **Step 4 : Rafraîchir le bouton Réserver quand le pion bouge, et le statut au recyclage**

Dans `_on_pawn_moved` (lignes ~303-306), ajouter `_refresh_ui()` à la fin :
```gdscript
func _on_pawn_moved(player: Player, _from: Vector2i, to: Vector2i) -> void:
	var pawn: Pawn = _pawns[player.index]
	pawn.move_to(to)
	_refresh_highlights()
	_refresh_ui()
```

Dans `_on_delivery_completed` (lignes ~317-321), retirer le repère de statut après livraison/recyclage :
```gdscript
func _on_delivery_completed(delivery: Delivery, points: int) -> void:
	# The destinataire was recycled (or cleared) — refresh that delivery's recipient card + status.
	_rebuild_recipient_marker(delivery)
	_update_status_ring(delivery)  # back to DISPONIBLE -> ring removed
	_ui.set_status("Livré ! +%d points." % points)
	_refresh_ui()
```

- [ ] **Step 5 : Mettre à jour `_refresh_ui()`**

Remplacer (ligne ~330) :
```gdscript
	_ui.refresh(player, _phase.score_of(player), _can_roll, _phase.current_delivery())
```
par :
```gdscript
	_ui.refresh(player, _phase.score_of(player), _can_roll, _phase.reservable_delivery() != null)
```

- [ ] **Step 6 : Vérifier la compilation (import)**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
Expected : DONE sans erreur de parse (`game_root.gd`).

- [ ] **Step 7 : Boot de bout en bout (sans erreur runtime)**

Run : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30 scenes/main.tscn 2>&1 | grep -iE "error|invalid|nil|SCRIPT"`
Expected : aucune ligne d'erreur.

- [ ] **Step 8 : Commit**

```bash
git add src/game/game_root.gd
git commit -m "feat(game): câble la réservation + transitions auto et un repère de statut sur le drive"
```

---

## Task 7 : Suite complète + nettoyage

**Files:** aucun (vérification)

- [ ] **Step 1 : Import + suite GUT complète**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit
```
Expected : « All tests passed! » (203+ tests, ajustés).

- [ ] **Step 2 : Vérifier l'absence de références mortes**

```bash
grep -rn "picked_up\|\.delivered\|carrier_index\|confirm_pickup\|confirm_delivery\|select_delivery\|delivery_picked\|pickup_requested\|deliver_requested\|current_delivery()" src/
```
Expected : aucune correspondance (hors `current_delivery` champ de `TurnContext`, qui reste).

- [ ] **Step 3 : Commit éventuel des correctifs**

```bash
git commit -am "fix(livraison): nettoyage des références au modèle de livraison précédent" || echo "rien à committer"
```

---

## Task 8 : Documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD`

- [ ] **Step 1 : Mettre à jour `CLAUDE.md`**

Dans la section « Modèle de domaine », remplacer la puce **Drive/destinataire/livraison**, la puce **Tour de jeu** et la puce **Scoring** par une description du nouveau flux :
- Livraison = 1 drive + 1 destinataire sur la **même tuile** ; cycle **Disponible → Réservé → En cours → Terminé**.
- **Réservation manuelle** quand le pion est sur la tuile du drive (pendant le déplacement), **2 livraisons max** par joueur.
- **En cours** automatique sur la case du drive ; **Terminé** automatique sur la case du destinataire ; **tout est gratuit** (plus de coût de prise en charge).
- **Recyclage** : à la livraison, un nouveau destinataire est tiré (roulement) ; pool épuisé ⇒ drive libre. Fin de partie quand plus aucune livraison n'est actionnable.
- **Scoring** : `5` + `10` si la tuile du drive est de la **couleur du joueur** + `10` si la tuile du destinataire l'est ⇒ **5 ou 25** (mono-tuile). Identité = **couleur du joueur** (les personnages restent pour transport/dés/pouvoirs/événements).

Dans la section « Architecture implémentée », mettre à jour la ligne `src/game/` pour refléter le cycle de statut sur `Delivery` et la suppression des booléens.

- [ ] **Step 2 : Mettre à jour `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD`**

Répercuter les mêmes changements (flux de livraison + scoring) dans la copie synchronisée.

- [ ] **Step 3 : Commit**

```bash
git add CLAUDE.md docs/SHOPOPOP-EXPRESS-GAME-RULES.MD
git commit -m "docs: aligne CLAUDE.md et les règles sur le nouveau flux de livraison"
```

---

## Task 9 : Synchroniser Notion (source de vérité)

**Files:** aucun (action externe)

- [ ] **Step 1 : Localiser la page Notion**

Récupérer la page « SHOPOPOP Express 2 - LE Retour » (id `3732c5c7-9816-8027-bddc-e78f7729d8a5`) via le MCP Notion (`notion-fetch`).

- [ ] **Step 2 : Mettre à jour la section livraison/score**

Via `notion-update-page`, répercuter : cycle à 4 statuts, réservation manuelle sur la tuile (2 max), En cours/Terminé automatiques, gratuité, recyclage, scoring 5/+10/+10 sur la couleur du joueur.

- [ ] **Step 3 : Mettre à jour la date de synchro**

Dans `CLAUDE.md`, ajuster la mention « dernière synchro » à la date du jour (2026-06-03) ; commit.

```bash
git commit -am "docs(claude): date de synchro Notion mise à jour"
```

---

## Récapitulatif des changements de signatures (pour cohérence)

- `Delivery` : `status: int`, `reserved_by: int`, `is_reservable()`, `drive_tile_owner()`, `recipient_tile_owner()` ; **supprimés** : `picked_up`, `delivered`, `carrier_index`.
- `ScoreCalculator.score_delivery(delivery: Delivery, color: int) -> int` (était `(delivery, character)`).
- `GamePhase` : **ajoutés** `deliveries_in_flight(idx)`, `reservable_delivery()`, `reserve_delivery()`, `MAX_IN_FLIGHT`, signaux `delivery_reserved`/`delivery_in_progress` ; **supprimés** `select_delivery`, `confirm_pickup`, `confirm_delivery`, `current_delivery()`, `_available_delivery_at`, `_carrying`, signal `delivery_picked`.
- `GameUI.refresh(player, score, can_roll, can_reserve: bool)` (était `carrying: Delivery`) ; signal `reserve_requested` (remplace `pickup_requested`/`deliver_requested`).
- `EventResolver` : `current_delivery.status == DeliveryStatus.Kind.EN_COURS` (était `.picked_up`).
