# Design — Refonte du flux de livraison (cycle Disponible → Réservé → En cours → Terminé)

**Date :** 2026-06-03
**Branche :** `feat/tile-textures-and-placement-ux`
**Statut :** validé en brainstorming, prêt pour le plan d'implémentation

## Contexte & objectif

Les règles évoluent vers une **simplification** du flux de livraison. Aujourd'hui le jeu spatial
(`src/game/delivery.gd` + `GamePhase`) suit les livraisons avec des booléens (`picked_up` /
`delivered`) et une réservation en phase Planification ou par proximité du drive. En parallèle, un
système de démo (`src/livraisons/` : `DeliveryCombo`, `DeliveryStatus`, `DeliveryGenerator`) porte
déjà le cycle à 4 statuts mais sans lien spatial.

Cette refonte donne au **jeu spatial** un cycle de vie explicite à 4 statuts, piloté par la position
du pion sur le plateau, et remplace le scoring « 2 couleurs du personnage » par un scoring fondé sur
la **couleur unique du joueur**.

## Décisions (issues du brainstorming)

| Sujet | Décision |
|---|---|
| Personnages | **Conservés** (transport → nb de dés, super-pouvoirs, événements) |
| Identité de score | **`player.color`** (couleur unique), plus les 2 couleurs du perso |
| Livraisons « en vol » | **2 max** par joueur (Réservé + En cours cumulés) |
| Réservation | **Manuelle** (bouton), **pendant le déplacement**, quand le pion est sur la tuile d'un drive disponible |
| En cours / Terminé | **Automatiques** sur la case exacte (drive → En cours ; destinataire → Terminé) |
| Coût en déplacement | **Gratuit** partout (suppression du −1 pas de la prise en charge) |
| Portée d'une livraison | **Mono-tuile** (drive + destinataire sur la même tuile) |
| Formule de score | `5` + `10` si tuile du drive = couleur joueur + `10` si tuile du destinataire = couleur joueur → **5 ou 25** |
| Recyclage | **Oui** : à la livraison, le drive reçoit un nouveau destinataire disponible (roulement) ; si le pool est épuisé, le drive reste libre (inactif) |
| Approche d'archi | **A** : porter le cycle sur le `Delivery` spatial, réutiliser l'enum `DeliveryStatus`, ne pas toucher à la démo `enseigne_demo` |
| Source de vérité | Mettre à jour **code + `CLAUDE.md` + `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD` + page Notion** |

## Architecture

Découplage strict conservé : la logique (`Delivery`, `GamePhase`, `ScoreCalculator`) reste en
`RefCounted`/statique testable en `--headless` ; la vue (`GameRoot`, `GameUI`) réagit par signaux.
Le système de démo `src/livraisons/` (`DeliveryCombo`/`DeliveryStatus`/`DeliveryGenerator`) **n'est
pas modifié dans sa structure** ; on réutilise uniquement l'enum `DeliveryStatus` (vocabulaire
partagé) et `DeliveryGenerator` (déjà utilisé par `GameRoot` pour le roulement).

### 1. `Delivery` (`src/game/delivery.gd`)

Remplacer les booléens par un statut explicite :

- **Retirer** : `picked_up`, `delivered`, `carrier_index`.
- **Ajouter** :
  - `status: int = DeliveryStatus.Kind.DISPONIBLE`
  - `reserved_by: int = -1` (index du joueur qui réserve puis transporte)
- **Méthodes** :
  - `recycle(p_destinataire)` : `destinataire = p_destinataire` ; `status = DISPONIBLE` ;
    `reserved_by = -1`. (`p_destinataire == null` ⇒ drive « libre », inactif.)
  - `is_reservable() -> bool` : `status == DISPONIBLE and destinataire != null`.
  - `drive_tile_owner() -> int` / `recipient_tile_owner() -> int` : renvoient `tiles[0].owner`
    (mono-tuile aujourd'hui ; deux accesseurs distincts pour généraliser au multi-tuiles plus tard).
  - Conserver `is_single_tile()`, `tile_owners()` si encore utiles ; sinon retirer.

### 2. `GamePhase` (`src/game/game_phase.gd`)

État : remplacer `_carrying: Dictionary` (1 livraison/joueur) par une dérivation depuis
`reserved_by` sur chaque `Delivery`.

**Réservation (manuelle, pendant DEPLACEMENT) :**

- `reservable_delivery() -> Delivery` : la livraison telle que
  `delivery.is_reservable()`, `_board.piece_at(position_of(current)) == delivery.tiles[0]`, et
  `_in_flight_count(current) < 2`. Sinon `null`.
- `reserve_delivery() -> bool` : valable si `_subphase == DEPLACEMENT` et `reservable_delivery()`
  non nul. Pose `status = RESERVE`, `reserved_by = current`, émet `delivery_reserved`, puis appelle
  `_check_delivery_transitions()` (cas où le pion est déjà sur la case du drive).
- `_in_flight_count(player_index) -> int` : nombre de livraisons `RESERVE` ou `EN_COURS` dont
  `reserved_by == player_index`.

**Transitions automatiques :**

- `_check_delivery_transitions()` appelé à la fin de `try_step()` (après mise à jour de la position)
  **et** à la fin de `reserve_delivery()`. Pour chaque livraison `d` avec `d.reserved_by == current` :
  - si `d.status == RESERVE` et `position == d.drive_cell` → `d.status = EN_COURS`,
    émettre `delivery_in_progress(d)`.
  - si `d.status == EN_COURS` et `position == d.recipient_cell` → **livraison** (voir ci-dessous).
- **Livraison** : `points = _score_for(current_player(), d)` ; si `_context != null and
  _context.double_score` → `points *= 2`. Ajouter au score. Recyclage via le générateur (alignement
  d'index existant) : `next = _generator.recycle(idx)` puis `d.recycle(next)`. Émettre
  `delivery_completed(d, points)`. Si `is_finished()` → `game_finished(scores())`.

**Suppressions :** `select_delivery`, `confirm_pickup`, `confirm_delivery`, `_available_delivery_at`,
le signal `delivery_picked`, et tout coût de déplacement lié à la prise.

**Gratuité :** aucune transition ne consomme de pas (`subtract_steps` retiré du flux livraison).

**Fin de partie :** `is_finished()` = il existe au moins une livraison ET toutes les livraisons sont
`DISPONIBLE` avec `destinataire == null` (pool épuisé et plus rien en vol).

**Signaux :** `delivery_reserved(delivery)`, `delivery_in_progress(delivery)`,
`delivery_completed(delivery, points)`, `game_finished(scores)` (inchangé), plus les signaux de tour
existants.

**TurnContext :** `current_delivery` ne peut plus être unique. Le remplacer par
`deliveries_in_flight(current)` là où c'est nécessaire (événements/pouvoirs). `double_score`
continue de s'appliquer à toute livraison conclue pendant le tour courant.

### 3. `ScoreCalculator` (`src/game/score_calculator.gd`)

- Constantes : `BASE = 5`, `PER_TILE_OWNED = 10`. **Retirer** `SINGLE_OWNED_TILE`.
- Signature : `score_delivery(delivery: Delivery, color: int) -> int` (couleur joueur, plus de
  `CharacterDefinition`).
- Formule :
  ```
  score = BASE
  if delivery.drive_tile_owner() == color: score += PER_TILE_OWNED
  if delivery.recipient_tile_owner() == color: score += PER_TILE_OWNED
  return score
  ```
- Mono-tuile : les deux accesseurs renvoient le même owner → 5 (aucune) ou 25 (tuile à soi).
- `GamePhase._score_for(player, delivery)` passe `player.color`.

### 4. Vue & UI (`src/view/`, `src/ui/`, `src/game/game_root.gd`)

- **`GameUI`** : remplacer les boutons « Prendre » / « Livrer » par un unique bouton **« Réserver »**
  (signal `reserve_requested`), visible/actif seulement quand `reservable_delivery() != null`. Adapter
  les messages de statut aux 4 états (Disponible / Réservé / En cours / Terminé).
- **`GameRoot`** :
  - Brancher `_ui.reserve_requested -> _on_reserve` ; retirer les branchements pickup/deliver.
  - Se connecter à `delivery_reserved` / `delivery_in_progress` / `delivery_completed` pour
    rafraîchir statut + marqueurs. Le recyclage du marqueur destinataire (`_rebuild_recipient_marker`)
    reste déclenché à `delivery_completed`.
  - Après chaque mouvement, rafraîchir l'état du bouton Réserver (via `reservable_delivery()`).
  - **Indice visuel de statut** (recommandé, léger) : teinter le marqueur de la livraison selon le
    statut (Disponible neutre / Réservé = couleur du joueur réservant / En cours = accent). Si trop
    coûteux, se limiter au texte de statut.
- **Pion** : on conserve la figure `COTRANSPORTER` teintée par `player.color` (déjà conforme à
  « représenté par la couleur »). Aucun changement requis sur `PawnView`.

### 5. Tests (TDD)

Nouveaux / mis à jour, lancés après `--import` :

- **`test_score_calculator`** : 5 (aucune tuile à soi) ; 25 (tuile à soi) ; cas génériques 15
  (un seul des deux owners correspond) pour verrouiller les deux `+10` indépendants.
- **`test_delivery`** : `recycle()` remet `DISPONIBLE`/`reserved_by = -1` ; `is_reservable()`
  (false si `destinataire == null`) ; accesseurs d'owner.
- **`test_game_phase`** :
  - `reserve_delivery` réussit seulement si sur la tuile + réservable + `< 2` en vol ;
  - refus de réserver une livraison déjà réservée par un autre joueur ;
  - plafond strict à 2 livraisons en vol ;
  - pion sur `drive_cell` d'une réservée à soi → `EN_COURS` ;
  - pion sur `recipient_cell` d'une `EN_COURS` à soi → `LIVREE` : score correct, recyclage d'un
    nouveau destinataire (retour `DISPONIBLE`) ;
  - gratuité (aucun pas consommé par les transitions) ;
  - pool épuisé → `recycle` rend `null` → livraison inactive → `is_finished()` → `game_finished`.
- Adapter les tests existants qui référencent `select_delivery`/`confirm_pickup`/`confirm_delivery`/
  `picked_up`/`delivered`/`carrier_index`.

### 6. Documentation & source de vérité

- **`CLAUDE.md`** : section « Modèle de domaine » — cycle de livraison à 4 statuts, déclencheurs
  (réservation manuelle sur la tuile, En cours/Terminé automatiques), 2 livraisons max, gratuité,
  scoring `5 / +10 drive / +10 destinataire` sur la couleur joueur, identité = couleur.
- **`docs/SHOPOPOP-EXPRESS-GAME-RULES.MD`** : répercuter les mêmes changements.
- **Notion** : mettre à jour la page « SHOPOPOP Express 2 - LE Retour » (source de vérité) avec le
  nouveau flux et le nouveau scoring.

## Hors périmètre (YAGNI)

- Livraisons multi-tuiles (drive et destinataire sur des tuiles différentes) — accesseurs prévus mais
  non activés.
- Refonte/suppression du système de démo `src/livraisons/` (`DeliveryCombo`) — laissé tel quel.
- Abandon volontaire d'une réservation (pas demandé) ; une réservation se conclut par la livraison ou
  reste en vol jusqu'à la fin de partie.
- Trancher coopératif vs compétitif : on conserve le score individuel existant.

## Risques & points d'attention

- **`current_delivery()` supprimé** : repérer tous ses appels (`GameRoot._refresh_ui`,
  `TurnContext`, événements/pouvoirs) et migrer vers `deliveries_in_flight`.
- **Alignement d'index** `Delivery` ↔ `DeliveryGenerator.combos()` : conservé tel quel pour le
  recyclage ; vérifier que les tests couvrent le cas pool épuisé.
- **`character.owns_color` / `character.colors`** : ne sont plus utilisés par le scoring ; vérifier
  qu'aucun événement/pouvoir ne s'appuie dessus (sinon adapter ou conserver le champ en l'état).
