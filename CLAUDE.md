# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

**Shopopop Express** est l'adaptation **numérique d'un jeu de société physique** : un jeu de
livraison coopératif où les joueur·euse·s incarnent des cotransporteur·euse·s. Le but de ce dépôt
est de recréer ce jeu de plateau dans **Godot 4.6** avec une **vue 3D du dessus** (top-down).

Les **fondations techniques existent désormais** (branche `feat/hex-grid-placement`) : système de
**grille hexagonale**, **blocs modulaires** et **placement sur le plateau**, avec une architecture en
couches découplées et des tests unitaires. Voir la section « Architecture implémentée » plus bas. La
logique de **gameplay** (déplacements sur les routes, dés, livraisons, score, événements) reste à
construire **au-dessus** de ces fondations, en se référant aux règles.

**La source de vérité du gameplay est `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD`.** Toute logique de jeu
doit s'y référer. Les règles sont encore en cours de rédaction (voir « Ambiguïtés connues » plus bas) :
ne pas figer dans le code un comportement issu d'une formulation douteuse sans confirmation.

> ⚠️ **Maintenir ce CLAUDE.md à jour avec l'évolution des règles.** Le modèle de domaine et les
> ambiguïtés décrits ici sont un instantané des règles actuelles. Dès que `SHOPOPOP-EXPRESS-GAME-RULES.MD`
> change (clarification d'une ambiguïté, nouvelle mécanique, équilibrage du score…), répercuter le
> changement dans ce fichier afin qu'il reste fidèle à la source de vérité.

Langue de travail : **français** (règles, UI, et de préférence les noms de domaine dans le code).

## Stack & décisions techniques (depuis `project.godot`)

- **Godot 4.6**, renderer **`GL Compatibility`** (et non Forward+/Mobile). Cible des configs modestes,
  mobile et web → privilégier des assets et shaders compatibles avec ce pipeline. Éviter les
  fonctionnalités réservées à Forward+ (certains effets de post-traitement, GI temps réel avancée…).
- Physique 3D : **Jolt Physics** (`3d/physics_engine="Jolt Physics"`).
- Windows : driver de rendu `d3d12`.
- Langage : **GDScript** par défaut (aucun module C#/GDExtension configuré pour l'instant).

## Commandes

Aucun binaire Godot n'est sur le `PATH` de cette machine ; ouvrir le projet via l'éditeur Godot 4.6.
Si le CLI `godot` est installé, les commandes utiles depuis la racine :

```bash
godot --editor .                 # ouvrir le projet dans l'éditeur
godot .                          # lancer le jeu (scène principale)
godot --headless --quit          # importer les assets / valider le projet sans UI
godot -s <script.gd>             # exécuter un script (utile pour tests/outils)
```

Tests : **GUT (Godot Unit Test) est en place** (`addons/gut/`, config `.gutconfig.json`, tests dans
`tests/`). La couche logique (maths hexagonales, règles de placement) est développée en **TDD**. Les
commandes complètes sont dans `docs/dev-notes/running.md`. En résumé, après l'ajout d'un nouveau
`class_name`, lancer un import **avant** les tests :

```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

## Modèle de domaine (issu des règles)

Concepts clés à modéliser. Les entités forment naturellement des `Resource` (données) + `Node`
(représentation 3D) :

- **Plateau** = assemblage de **tuiles** (chaque tuile = un *quartier* avec routes, espaces verts,
  zones grises/urbanisées). Contrainte d'assemblage : deux tuiles ne se joignent que si une route de
  l'une touche une route de l'autre. **Déplacement uniquement sur les routes** (sauf cartes événement).
- **Identité du joueur = sa couleur** (`player.color`, une seule des 4 couleurs de quartier). Les
  **personnages** subsistent (transport → nombre de dés, super-pouvoir, événements) mais ne définissent
  **plus** l'identité de score : le pion n'est représenté que par sa couleur.
- **Carte personnage** : mode de déplacement (**voiture** ou **vélo**), 2 couleurs de *trajet régulier*
  (flavor), et **1 super-pouvoir** utilisable **une seule fois**. ⚠️ Le **score** se fonde désormais sur
  la couleur du joueur, pas sur ces 2 couleurs.
- **Livraison** = un **drive** (point de retrait, case urbaine/grise) + un **destinataire** (case verte)
  **sur la même tuile** (1 drive par tuile). Cycle de vie : **Disponible → Réservé → En cours → Terminé**
  (`DeliveryStatus`). Une **enseigne** habille le drive ; un **destinataire** (recyclé) habille le point
  vert.
- **Tour de jeu** : Planification (lancer les dés) → Déplacement (sur les routes). **Pendant** le
  déplacement, lorsqu'il est sur la **tuile** d'un drive *disponible*, le joueur peut **réserver** la
  livraison (statut **Réservé**, **2 livraisons max** « en vol » par joueur). Arriver sur la **case du
  drive** → **En cours** (automatique) ; arriver sur la **case du destinataire** → **Terminé**
  (automatique). **Tout est gratuit** (plus de coût de prise en charge). Événements : case arc-en-ciel =
  piocher/résoudre une carte. À la livraison, la tuile **recycle** un nouveau destinataire disponible
  (roulement) ; pool épuisé ⇒ le drive reste **libre**. **Fin de partie** : plus aucune livraison
  actionnable.
- **Scoring** (par livraison terminée) : **5** pts + **10** si la tuile du **drive** est de la couleur du
  joueur + **10** si la tuile du **destinataire** l'est ⇒ **5 ou 25** en mono-tuile (les deux `+10`
  coïncident). Voir `src/game/score_calculator.gd`.
- **Cartes événement** : deux familles — **Avantages** (bonus/déplacement supplémentaire, souvent en
  faveur du vélo) et **Malus** (blocages, retours forcés, fin de tour). Le **vélo** est un thème
  récurrent (bonus écologiques). Le **pont** permet de franchir certains obstacles ; fermé par l'événement
  « Pluies Torrentielles ».

### Ambiguïtés connues dans les règles (à clarifier, ne pas coder en dur sans validation)

- ~~Table de score incohérente~~ **(résolu 2026-06-03)** : le scoring est désormais **5 + 10 (tuile du
  drive à ma couleur) + 10 (tuile du destinataire à ma couleur)**, sur la couleur du joueur. Mono-tuile
  ⇒ 5 ou 25.
- **Nombre de joueurs** non spécifié ; quantités par joueur (3 tuiles, 3 jetons destinataire, 3 jetons
  enseigne, 1 pion, 1 pont) données sans total de plateau clair.
- Terminologie flottante : « deck de livraison » vs les 9 livraisons construites ; « jetons » vs
  « tuiles » enseigne/destinataire.
- Le doublement des points au vélo apparaît dans plusieurs événements — vérifier s'ils se cumulent.

Si l'utilisateur·rice demande de **réécrire les règles** (formulations imparfaites, répétitions),
le faire dans `docs/` en conservant l'original ou via git, et lever les ambiguïtés ci-dessus.

## Conventions Godot

- Scènes `.tscn` et scripts `.gd` versionnés ; le dossier `.godot/` est ignoré (cache régénéré).
- EOL `lf`, UTF-8 (`.editorconfig`, `.gitattributes`).
- Vue du dessus : prévoir une caméra orthographique ou perspective haute fixe ; la grille du plateau
  est l'ancrage des positions — penser un système de **coordonnées de cases** découplé des positions
  monde 3D dès le départ (déplacements comptés « en cases », pas en mètres).

## Architecture implémentée — grille flat-top texturée & placement UX

**Découplage strict en couches** : la logique de jeu ne dépend pas du rendu (on fait évoluer le
visuel sans toucher aux règles, et toute la logique est testée par GUT).

```
src/logic/      hex_utils.gd (HexUtils)       maths hexagonales FLAT-TOP, statiques (+ line())
                board.gd (Board)              état du plateau + règles de placement (connecteurs)
                placed_piece.gd (PlacedPiece) instance posée : propriétaire, cases typées, connecteurs
src/blocks/     cell_type.gd (CellType)       enum Route/Vert/Urbain/Eau/Événement
                block_definition.gd           BlockDefinition (Resource) : cases + types + connecteurs
src/game/       player_color.gd / player.gd   4 couleurs (Bleu/Rouge/Violet/Jaune) + modèle joueur
                setup_distributor.gd          tire 3 patterns partagés, recolore, assigne le départ
                setup_phase.gd                tours round-robin (+ pose atomique pont+bloc)
                bridge_finder.gd              trouve un pont reliant un bloc « une case trop loin »
src/pawns/      pawn_definition.gd / pawn.gd  PawnDefinition (Resource) + Pawn (état : position + steps)
src/cards/      card_definition.gd / deck.gd  CardDefinition (Resource) + Deck (pioche/défausse, RNG)
src/movement/   movement.gd (Movement)        marche auto-évitante sur un set de cases injecté
src/dice/       dice_roller.gd (DiceRoller)   lance X D6, mémorise le résultat, RNG injectable
src/view/       hex_grid_view.gd              assemble lattice + tuiles + outlines + marqueurs
                tile_sprite.gd / tile_textures.gd  une case = Sprite3D texturé (débord Nord)
                road_tiling.gd                oriente les routes (droite/T) selon la connectivité
                tile_preview.gd               rend un bloc en SubViewport pour l'UI
                block_ghost.gd / block_outline.gd  fantôme texturé (rouge si invalide) / contour joueur
                pawn_view.gd (PawnView)       figure cône+tête colorée / jeton-image
                card_view.gd (CardView)       carte 3D : face placeholder, dos logo + CARD_TYPE
                die_view.gd (DieView)         dé 3D à points, orienté sur la valeur
                hex_mesh_factory.gd / game_config.gd
src/interaction/placement_controller.gd      magnet auto-rotation + auto-pont
                camera_rig.gd                 pan/zoom (molette + clic-droit, pinch + 2 doigts)
src/ui/         placement_ui.gd               écran 2–4 joueurs + barre (joueur, previews de tuiles)
src/main.gd     scenes/main.tscn              composition root
src/*_demo.gd   scenes/*_demo.tscn            démos autonomes : pawn / card / movement / dice
resources/blocks/patterns/*.tres, bridge.tres   bibliothèque (générée)
assets/tiles/   textures par type (green/urban/water/road + special/spawn)
tools/          generate_block_resources.gd, capture_preview.gd   outils dev
```

### Systèmes de gameplay (logique pure, testée, en cours d'intégration)

Apportés par la fusion de `main` ; chacun ignore les autres et le `Board`, branchés à l'intégration
(voir le plan en 3 phases). Chaque système a une **scène de démo autonome** (`scenes/*_demo.tscn`).

- **Pion** (`Pawn` + `PawnDefinition`) : `position` (case) + `steps`, pose unique, pion fixe immobile ;
  signaux `placed/moved/steps_changed`. Cotransporteur = figure colorée, drive/destinataire = jeton-image.
- **Paquet** (`Deck` + `CardDefinition`) : `draw(n)` / `discard` / `reshuffle` / `return_to_top`, RNG
  injectable.
- **Déplacement** (`Movement`) : set de cases praticables + départ + budget ; marche **auto-évitante**,
  total obligatoire, arrêt si bloqué. ⚠️ Inadapté tel quel au déplacement de plateau (demi-tours,
  téléportations, coût +1 prise en charge) → une variante `TurnMovement` est introduite à l'intégration.
- **Dés** (`DiceRoller`) : `roll(X)` de D6, mémorise le résultat, `total()` / `consume()`.

**Coordonnées de cases** : axiales **flat-top** (imposé par les textures), une case = `Vector2i(q, r)`,
conventions Red Blob Games. `HexUtils` : voisins, distance, rotation 60°, `line()`, case↔monde (plan XZ).

**Blocs & types** : `BlockDefinition` = `cells` + `cell_types` (parallèle) + `connectors`. Tuile quartier
= hexagone **côté 3 = 19 cases** ; **pont** = `Eau–Route–Eau`. Patterns générés avec route en **ligne
droite + branche T** (uniquement les 2 textures de route). Bibliothèque → **3 patterns tirés, partagés**
(`SetupDistributor`) ; chaque joueur (2–4) reçoit les 3 dans sa couleur + 1 pont + un **départ** (case
verte aléatoire).

**Placement (route-à-route)** : `Board` indexe des `PlacedPiece`. `can_place()` = pas de chevauchement +
(1ʳᵉ pièce libre, sinon **un connecteur de la nouvelle pièce voisin d'un connecteur existant**).
Connecteurs = routes en centre d'arête (hexagone) / extrémités (pont). `SetupPhase` enchaîne les tours.

**Rendu** : scène 3D, **caméra ortho top-down**, chaque case = **Sprite3D texturé** posé à plat (base
388px sur l'hexagone, décor débordant au Nord, tri Sud-sur-Nord), routes orientées via `RoadTiling`,
**outline** de périmètre couleur joueur, `special`/`spawn`. UI : **previews réelles** des tuiles.

**Interaction** : pointeur souris/tactile ; **magnet** snappe le fantôme à la pose légale la plus proche
(auto-rotation, rotation = cycle des candidats) ; lâcher « une case trop loin » → **auto-pont**
(`BridgeFinder` + `SetupPhase.try_place_with_bridge`, consomme le pont) ; fantôme **rouge** si invalide.

### Couche de gameplay intégrée (au-dessus du socle plateau)

Le gameplay est branché au plateau via un second composition root, `GameRoot` (Node3D), que `Main`
instancie à `setup_finished`. Tout le cœur reste en **logique pure testée** (GUT) ; les Node ne font
que rendu/entrées.

```
src/logic/      road_network.gd (RoadNetwork)  set de cases praticables (ROUTE+EVENT) depuis le Board
                board.gd                       + cells_of_type(kind), piece_at(cell)
src/movement/   turn_movement.gd (TurnMovement) marche réelle : revisite, ±budget, teleport_to
src/game/       character_definition.gd        CharacterDefinition (Resource) : transport→dés, 2 couleurs, power_id
                game_phase.gd (GamePhase)       boucle de tour + sous-phases + livraisons + events + score
                delivery.gd / delivery_setup.gd Delivery (drive→destinataire, statut Disponible/Réservé/En cours/Livré) + génération (1/ tuile)
                score_calculator.gd             5 + 10 (tuile drive à ma couleur) + 10 (tuile destinataire à ma couleur)
                turn_context.gd (TurnContext)   état mutable du tour (effets events/pouvoirs)
                event_resolver.gd / power_resolver.gd  effets data-driven (match, pas de if géant)
                game_root.gd (GameRoot)         composition root du jeu : pions, dés, deck, UI, contrôleur
src/cards/      event_card_definition.gd        EventCardDefinition : effect/amount/condition/is_malus
src/interaction/movement_controller.gd          clic/tap → case → GamePhase.try_step
src/ui/         game_ui.gd (GameUI)             tour, score, lancer dés, livraisons, prendre/livrer, pouvoir, fin
resources/characters/*.tres   8 personnages   ·  resources/events/*.tres   ~22 cartes (outil generate_event_cards.gd)
```

**Boucle de tour** (`GamePhase`, round-robin) : PLANIFICATION (`select_delivery`) → DEPLACEMENT
(`begin_movement(budget)` depuis `DiceRoller`, puis `try_step` sur les **routes uniquement**) →
EVENEMENT (case arc-en-ciel → `apply_event`) → PRISE_EN_CHARGE (`confirm_pickup`, **−1 déplacement**)
→ LIVRAISON (`confirm_delivery`, **gratuit**, score). Fin de partie quand toutes les livraisons sont
faites. Pouvoir une seule fois (`use_power`).

⚠️ `Movement` (auto-évitant, démo) **n'est pas** réutilisé en jeu : `TurnMovement` autorise revisite,
budget ajustable (events ±, prise en charge +1) et téléportation (cartes). « Tuile à moi » = la
**couleur de quartier** (`PlacedPiece.owner`) appartient au **personnage** (`character.owns_color`),
jamais l'identité du joueur (`Player.index`).

**Points laissés en STUB (V1, points ouverts non tranchés)** : téléportation « quartier »/« parallèle »,
Manifestation/Fuite/Pluies (effets persistants), capacité de volume (Margot), pont en jeu, coop vs
compétitif (scores individuels + total affichés, pas de vainqueur en dur), cumul des doublements.

### Restant / à raffiner

- **A\*** avec preview de trajectoire (le `Board` expose déjà l'index des cases / connecteurs).
- **Pose manuelle** des jetons drive/destinataire (V1 : placement auto post-setup, livraisons mono-tuile).
- Effets d'événement **interactifs** (choix de cible/quartier) et **persistants inter-tours**.
- **Multijoueur** distant : non implémenté (hot-seat 1 client) ; l'état est découplé et les joueurs identifiés.
- 5–6 joueurs réutilisent une couleur de quartier (4 couleurs) — distingués par `Player.index`.

> Notes de dev complémentaires (rôle, vision, commandes) : `docs/dev-notes/`.
