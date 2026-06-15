# Prompt — Prochaine session : randomiser drives & destinataires (livraisons cross-tuile)

> À coller comme prompt de départ de la prochaine session. Travaille sur la branche
> `feat/finition-shippable`. Lis d'abord `CLAUDE.md` et
> `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD`, puis le cœur livraisons listé plus bas.

## Objectif

Aujourd'hui chaque livraison est **mono-tuile** : `DeliverySetup.build()` prend, par tuile, la 1ʳᵉ case
urbaine atteignable (drive) et la 1ʳᵉ case verte atteignable (destinataire) **de la même tuile**. On
veut **randomiser** le placement, avec ces règles :

1. **Drive** → sur une case **URBAINE** (grise/urbanisée).
2. **Destinataire** → sur une case **ZONE VERTE**.
3. **Aucun drive ni destinataire ne doit être inaccessible** (toujours joignable par les routes).
4. **Le drive et le destinataire d'une même livraison ne sont PAS forcément sur la même tuile** —
   l'appariement est **aléatoire** (mono- ou bi-tuile, au hasard).

## Ce qui est DÉJÀ en place (à réutiliser, ne pas réécrire)

- `src/game/delivery.gd` (`Delivery`) **supporte déjà le multi-tuile** : `tiles: Array[PlacedPiece]`
  (1 ou 2 pièces), `drive_tile_owner()` = `tiles[0].owner`, `recipient_tile_owner()` = `tiles[-1].owner`,
  `is_single_tile()`. → **Convention à respecter : `tiles = [tuile_du_drive, tuile_du_destinataire]`**
  (drive en premier).
- `src/game/score_calculator.gd` applique déjà **5 + 10 (tuile drive à ma couleur) + 10 (tuile
  destinataire à ma couleur)** → le scoring cross-tuile marche **sans modification** (5 / 15 / 25).
- `src/logic/road_network.gd` fournit `distances_from(walkable, start, extra)` et
  `is_reachable(walkable, start, target, extra)` (BFS) → **utiliser ça pour garantir l'atteignabilité**.
- `src/game/game_phase.gd` :
  - `begin_movement()` ajoute déjà `drive_cell` et `recipient_cell` de **toutes** les livraisons à
    l'ensemble walkable (donc on peut marcher dessus, même hors route).
  - `reservable_delivery()` réserve sur `delivery.tiles[0]` (= la tuile du drive) → OK si on respecte la
    convention d'ordre des tuiles.
  - `_check_delivery_transitions()` : RESERVE→EN_COURS sur `drive_cell`, EN_COURS→LIVREE sur
    `recipient_cell` (indépendant des tuiles) → OK cross-tuile.
- `src/livraisons/delivery_generator.gd` (`DeliveryGenerator`) fournit les **combos enseigne +
  destinataire** (identités), recyclage compris. À garder : il donne le *qui*, `DeliverySetup` donne le
  *où*.
- Outils de vérif : `tools/soak_test.gd` (50 parties 2→6 joueurs auto-pilotées, doit rester **0
  softlock**) et `tools/capture_play.gd` (captures fenêtrées).

## Travail à faire

### 1. `src/game/delivery_setup.gd` — placement aléatoire cross-tuile (cœur)
- Construire deux **pools globaux** depuis le `Board` : toutes les cases **URBAINES** atteignables
  (candidats drives) et toutes les cases **VERTES** atteignables (candidats destinataires). « Atteignable »
  = adjacente au réseau (routes/événement) — réutiliser la logique existante `_reachable_cell_of_type`
  généralisée, ou un filtre via `RoadNetwork`.
- **Apparier aléatoirement** un drive (urbain) et un destinataire (vert), potentiellement sur des tuiles
  différentes. Mélange seedé (RNG injecté, comme `SetupDistributor`/`DeliveryGenerator`, pour des tests
  déterministes). `Delivery.new(drive_cell, recipient_cell, [tuile_drive, tuile_destinataire])` ;
  si même tuile → `[tuile]` (mono-tuile).
- **Garantir l'atteignabilité de chaque livraison** : avec l'ensemble walkable = routes + toutes les
  cases drive/destinataire choisies, vérifier `RoadNetwork.is_reachable(walkable, drive_cell,
  recipient_cell, extra)`. Si une paire n'est pas joignable, la rejeter / réapparier. Jamais de drive ou
  destinataire injoignable (sinon la partie ne se termine pas — cf. garde anti-softlock actuelle).
- **Nombre de livraisons** : choisir une valeur raisonnable et documentée — p. ex.
  `min(#drives, #destinataires_dispo, #combos_du_générateur)`. Aujourd'hui c'est 1 par tuile ; à
  réajuster (les règles donnent des quantités par joueur ; viser un total cohérent). Ne pas dépasser le
  pool de destinataires (V1 = 9).
- `drive_cell_of(piece, board)` / `recipient_cell_of(...)` actuels supposent « une livraison par tuile ».
  Les **remplacer** par la nouvelle logique (les cases viennent du pool global, plus du per-tuile).

### 2. Rendu de l'art du drive — sur la **vraie** case choisie
- `src/view/hex_grid_view.gd` affiche l'art « storefront » du drive via
  `DeliverySetup.drive_cell_of(piece, board)` (heuristique par tuile). Avec un placement aléatoire,
  cette heuristique **ne correspond plus** aux drives réels.
- Solution : exposer les **cases drive réelles** (depuis les `Delivery` construites) à `HexGridView`
  (p. ex. `HexGridView.set_drive_cells(cells)` appelé par `GameRoot` après
  `DeliverySetup.build()`), et n'afficher le storefront que sur ces cases. (Les **jetons** enseigne /
  destinataire posés par `GameRoot` à `drive_cell`/`recipient_cell` marchent déjà cross-tuile.)
- Attention : `HexGridView` est créé en phase de setup (plateau vide) et se rafraîchit sur
  `Board.changed` ; les livraisons ne sont connues qu'au démarrage de `GameRoot`. Donc rafraîchir l'art
  du drive **après** que `GameRoot` ait les livraisons.

### 3. Vérifs & garde-fous
- `reservable_delivery()` doit réserver quand le pion est sur la **tuile du drive** → garanti par la
  convention `tiles[0] = tuile du drive`. Vérifier (test) qu'on **ne peut pas** réserver depuis la tuile
  du destinataire seule.
- Recyclage (`DeliveryGenerator.recycle` + `Delivery.recycle`) : garder les **mêmes cases**
  drive/destinataire, seul le destinataire (identité) change. (Décider si on garde le couple de cases ou
  si on re-randomise au recyclage — défaut suggéré : garder les cases.)

### 4. Tests (TDD) & docs
- `tests/test_delivery_setup.gd` : adapter (cross-tuile, atteignabilité, drive urbain / destinataire
  vert) ; ajouter un cas **bi-tuile** explicite et un cas **injoignable rejeté**.
- Ajouter/màj tests de scoring cross-tuile (5 / 15 / 25 selon couleurs des deux tuiles) — `ScoreCalculator`
  ne change pas mais couvrir le cas bi-tuile.
- Lancer `--import` puis GUT → **vert**. Lancer le **soak** : 2→6 joueurs, **0 softlock** (preuve que
  rien n'est injoignable). Captures avant/après si pertinent.
- Mettre à jour `CLAUDE.md` (livraisons désormais mono-OU-bi-tuile aléatoires, atteignabilité garantie)
  et `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD` (lever l'ambiguïté « mono-tuile V1 »).

## Contraintes (inchangées)
GDScript **typé**, `class_name`, logique de jeu **pure** (RefCounted, aucun Node) **testée GUT**, rendu
seulement dans les Node, **GL Compatibility**, RNG **injecté** pour le déterminisme des tests, suite GUT
**verte** (faire `godot --headless --path . --import` avant les tests après tout nouveau `class_name`).

## Fichiers cœur à lire/toucher
- `src/game/delivery_setup.gd` (à réécrire) · `src/game/delivery.gd` (déjà multi-tuile) ·
  `src/livraisons/delivery_generator.gd` (combos) · `src/logic/road_network.gd` (BFS atteignabilité) ·
  `src/game/game_phase.gd` (`begin_movement`, `reservable_delivery`, `_check_delivery_transitions`) ·
  `src/view/hex_grid_view.gd` + `src/game/game_root.gd` (art du drive sur la vraie case) ·
  `src/game/score_calculator.gd` (lecture seule) · `tests/test_delivery_setup.gd`,
  `tests/test_game_phase.gd`, `tests/test_score_calculator.gd` · `tools/soak_test.gd` (gate anti-softlock).
