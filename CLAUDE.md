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
- ~~Cumul des doublements de points~~ **(tranché 2026-06-14)** : un seul ×2 par livraison
  (`double_score` non cumulatif) en V1.

#### Arbitrages de finition (tranchés 2026-06-14, défauts documentés — modifiables au playtest)

- **Pouvoirs interactifs/différés** : tous les 8 pouvoirs sont jouables (cf. plus bas). Margot
  (`chargement_pro`) = **+1 livraison simultanée** persistante ; Gégé (`passage_secret`) = **l'eau
  devient franchissable ce tour** ; Camille (`habitue_quartier`) = **prochaine livraison comptée au
  max (25)**. **Pioche d'événement (règle de base, tous)** : **pioche 2, garde 1, l'autre revient
  AU-DESSUS du deck**. Charlie (`carnet_adresses`) ne change que le sort de la carte écartée : elle est
  **défaussée** (retirée) au lieu de revenir au-dessus. Les bénéfices différés (Charlie, Axel·le,
  Camille, Margot) vivent sur le `Player` → jamais gâchés en silence.
- **Événements `rejouer` / `dé bonus`** : *Tous les Feux au Vert* = le **même joueur rejoue** un tour ;
  *Prime Gouvernementale* = on lance le(s) **dé(s) bonus immédiatement** et on les ajoute au budget.
- **Coopératif** : scores individuels **classés** (meilleur·e mis en avant) + **total collectif** à
  l'écran de fin ; pas de « perdant ».

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
                setup_phase.gd                tours round-robin : 1 bloc/tour (sans auto-avance) ajustable (retrait/rotation) + pont gratuit, fin via finish_turn
src/pawns/      pawn_definition.gd / pawn.gd  PawnDefinition (Resource) + Pawn (état : position + steps)
src/cards/      card_definition.gd / deck.gd  CardDefinition (Resource) + Deck (pioche/défausse, RNG)
src/movement/   movement.gd (Movement)        marche auto-évitante sur un set de cases injecté
src/dice/       dice_roller.gd (DiceRoller)   lance X D6, mémorise le résultat, RNG injectable
src/view/       hex_grid_view.gd              assemble lattice + tuiles + outlines + marqueurs
                tile_sprite.gd / tile_textures.gd  une case = Sprite3D texturé (art hex-plein ≈248px)
                road_tiling.gd                oriente les routes (droite/T) selon la connectivité
                tile_preview.gd               rend un bloc en SubViewport pour l'UI
                block_ghost.gd / block_outline.gd  fantôme texturé (rouge si invalide) / contour joueur
                pawn_view.gd (PawnView)       figure cône+tête colorée / jeton-image
                card_view.gd (CardView)       carte 3D : face placeholder, dos logo + CARD_TYPE
                die_view.gd (DieView)         dé 3D à points, orienté sur la valeur
                hex_mesh_factory.gd / game_config.gd
src/interaction/placement_controller.gd      magnet auto-rotation (blocs + pont manuel)
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
= hexagone **côté 3 = 19 cases** (les **3 patterns** des assets B1/B2/B3, routes en segments **droits
alignés sur la grille** = reliant les **coins** du grand hexagone, `coin i = DIRECTIONS[i]·R` ; relier
des centres d'arête ferait zigzaguer la route). **2 en Y** = une droite traversante `{0-3}` + une
bifurcation vers un coin adjacent (miroir gauche/droite, 3 connecteurs) et **1 en croix** = deux droites
croisées `{0-3}+{1-4}` (4 connecteurs). Les **connecteurs sont les coins atteints** (jonction
route-à-route, tuiles assemblées en quinconce). **Case spéciale au centre**, + eau/urbain/vert
procéduraux avec **≥2 vert et ≥1 urbain**. **Pont** =
`Eau–Route–Eau` dont **seule la case centrale (route)** connecte. `SetupDistributor` tire les 3 patterns
(partagés), recolore par joueur, + 1 pont + un **départ** (case verte en bord de route).

**Placement (route-à-route)** : `Board` indexe des `PlacedPiece`. `can_place()` = pas de chevauchement +
(1ʳᵉ pièce libre, sinon **un connecteur de la nouvelle pièce voisin d'un connecteur ROUTE existant**).
Connecteurs = cases route atteintes en bord de tuile (**coins** du grand hexagone ; **case centrale du
pont uniquement**) ; `Board.remove_piece()` permet de reprendre une pièce posée. **Modèle de tour
`SetupPhase`** : poser un bloc **n'avance pas** le tour ; le bloc posé est ajustable (`remove_block` /
`rotate_block` qui snappe à la rotation valide, ou repositionné en le glissant) ; le **pont** reste
gratuit (`try_place_bridge`, mêmes ajustements). `finish_turn()` clôt le tour, **refusé tant qu'aucun
bloc n'est posé** ; le joueur est `done` quand `pieces` est vide (un pont non posé est **abandonné** —
jamais de tour avec seulement un pont).

**Rendu** : scène 3D, **caméra ortho top-down**, chaque case = **Sprite3D texturé** posé à plat (art
flat-top hex-plein, **≈248px de large, l'hexagone remplit l'image sans débord**, géométrie unique
pour tous les types ; tri Sud-sur-Nord), routes orientées via `RoadTiling`,
**outline** de périmètre couleur joueur, `special`/`spawn`. UI : **previews réelles** des tuiles.

**Interaction** : pointeur souris/tactile ; **magnet** snappe le fantôme à la pose légale la plus proche
(auto-rotation, rotation = cycle des candidats) ; on glisse blocs et pont ; fantôme **rouge** si invalide.
Après pose, **barre flottante** ancrée au-dessus de la pièce active (⟲ rotation gauche · ✕ retirer · ⟳
rotation droite) ; glisser la pièce posée la reprend (repose ou restaure si drop invalide). Tray verrouillé
tant qu'un bloc est posé (1/tour) ; **"Terminer"** activé seulement une fois un bloc posé.

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
                delivery.gd / delivery_setup.gd Delivery (drive→destinataire, statut Disponible/Réservé/En cours/Livré) + placement aléatoire cross-tuile (drive urbain / dest vert, atteignable)
                score_calculator.gd             5 + 10 (tuile drive à ma couleur) + 10 (tuile destinataire à ma couleur)
                turn_context.gd (TurnContext)   état mutable du tour (effets events/pouvoirs)
                event_resolver.gd / power_resolver.gd  effets data-driven (match, pas de if géant)
                game_root.gd (GameRoot)         composition root du jeu : pions, jetons drive/dest, dés+cubes, deck, HUD, contrôleur
src/cards/      event_card_definition.gd        EventCardDefinition : effect/amount/condition/is_malus
src/interaction/movement_controller.gd          clic/tap → case → GamePhase.try_step
src/view/       clip_card_view.gd (ClipCardView) carte 3D enseigne/statut/destinataire (bind combo OU Delivery)
                delivery_list_view.gd (DeliveryListView) colonne gauche défilable : 1 ClipCardView par Delivery
src/ui/         play_hud.gd (PlayHud)           HUD de jeu (CanvasLayer) : cadre plateau, barre titre (tour/score/ordre + zoom ±), bouton d'action contextuel + pouvoir, emplacements DECK/cartes/DÉFAUSSE
resources/characters/*.tres   8 personnages   ·  resources/events/*.tres   ~22 cartes (outil generate_event_cards.gd)
```

**Boucle de tour** (`GamePhase`, round-robin) : PLANIFICATION (`begin_movement(budget)` depuis
`DiceRoller`) → DEPLACEMENT (`try_step` sur les **routes uniquement** ; pendant le déplacement,
`reserve_delivery()` sur la tuile d'un drive disponible — **2 max** par joueur) → EVENEMENT (case
arc-en-ciel → `apply_event`). Les transitions de livraison sont **automatiques** et **gratuites** :
sur la case du drive → EN_COURS ; sur la case du destinataire → livrée (score + recyclage du
destinataire via `DeliveryGenerator`). Fin de partie quand plus aucune livraison n'est actionnable.
Pouvoir une seule fois (`use_power`).

⚠️ `Movement` (auto-évitant, démo) **n'est pas** réutilisé en jeu : `TurnMovement` autorise revisite,
budget ajustable (events ±) et téléportation (cartes). « Tuile à moi » = la **couleur de quartier**
(`PlacedPiece.owner`) égale la **couleur du joueur** (`Player.color`) — l'identité de score, pas les
2 couleurs du personnage.

**Placement aléatoire des livraisons** : `DeliverySetup.build(board, rng, max_count, excluded)` tire les
**drives dans le pool global des cases URBAINES** et les **destinataires dans celui des cases VERTES**,
puis les **apparie au hasard** (RNG injecté) — drive et destinataire **pas forcément sur la même tuile**
(mono- OU bi-tuile). `Delivery.tiles = [tuile_drive, tuile_destinataire]` (drive d'abord) ; le scoring
`ScoreCalculator` 5 + 10 (tuile drive) + 10 (tuile destinataire) gère le cross-tuile (5/15/25). Les cases
de départ des joueurs sont exclues du pool destinataires. L'art « storefront » du drive est posé sur les
**vraies** cases via `HexGridView.set_drive_cells(...)` (appelé par `Main`/le harnais après le build).

**Atteignabilité (anti-softlock)** : seules des cases **adjacentes au réseau** entrent dans les pools, et
chaque paire drive→destinataire est validée par `RoadNetwork.is_reachable` (BFS) — sinon une livraison
resterait à jamais en vol et la partie ne finirait pas. Soak headless `tools/soak_test.gd` (50 parties
2→6 joueurs auto-pilotées, **0 softlock**, livraisons cross-tuile incluses).

**Les 8 super-pouvoirs sont jouables** (`PowerResolver`, `GamePhase`, `GameRoot`/`PlayHud`) :
Bonne Marcheuse (+2), Carnet d'Adresses (défausse la carte écartée au lieu de la remettre au-dessus),
Bouclier Vert (annule le prochain malus),
Habitué·e (livraison comptée au max), Passage Secret (eau franchissable ce tour), Chargement Pro (+1
livraison simultanée), Dépassement (échange de case — sélecteur), Coup d'Accélérateur (relance d'un dé
— sélecteur). Bénéfices différés portés par `Player` (jamais gâchés) ; interactifs via méthodes pures
`swap_positions`/`apply_reroll` + chooser modal.

**Présentation / game feel / audio** : police OFL (Nunito corps, Fredoka titres, `assets/fonts/`),
`SceneEnvironment` (lumière chaude, tonemap FILMIC, vignette — GL-compat), pions animés (saut
case→case), bannières de tour/événement, confettis de livraison, et `AudioManager` (SFX + musique
d'ambiance procéduraux `assets/audio/`, bouton mute). Écrans : titre (Jouer + Son), choix du nombre de
joueurs, **sélection des personnages** (`CharacterSelect`, aperçu transport/dés/pouvoir), HUD de jeu,
**écran de fin classé + total collectif + Rejouer**.

**Événements — les 22 cartes ont un effet** (`apply_event`). Les téléportations
(retour drive/départ, escorte, faille, raccourci) sont propagées à la **position autoritaire**
(`_positions`) + à la vue + aux transitions de livraison via `_sync_pawn_after_event` (sinon le pion ne
bougeait pas → « aucun impact »). Les ex-stubs sont câblés en V1 (simplifiés, board-dependent dans
`GamePhase._apply_spatial_event`) : Faille = téléport au drive le plus loin ; Raccourci = téléport au
prochain drive dispo ; Manifestation = budget −½ ; Fuite = détour −3 ; Pluies = détour −2 (pont
toujours setup-only). **UX** : la carte est un **modal 2D net** (`src/ui/event_modal.gd` : bandeau
Avantage/Malus, titre, effet en évidence, description en clair), résolu en **un seul clic** (avant :
carte 3D placeholder + 2ᵉ clic d'activation — d'où l'impression d'« effet sans impact »). L'ancienne
`EventCardChoice` (3D) subsiste pour les démos/tests.

### Restant / à raffiner

- **A\*** avec preview de trajectoire (le BFS `RoadNetwork.distances_from` est en place ; reste l'UI).
- **Pose manuelle** des jetons drive/destinataire (V1 : placement **auto aléatoire** post-setup, drives
  urbains / destinataires verts, mono- ou bi-tuile, atteignabilité garantie).
- Effets d'événement **interactifs** (choix de cible/quartier) et **persistants inter-tours**.
- **Multijoueur** distant : non implémenté (hot-seat 1 client) ; l'état est découplé et les joueurs identifiés.
- 5–6 joueurs réutilisent une couleur de quartier (4 couleurs) — distingués par `Player.index`.

### Outils de dev (headless / capture)

- `tools/soak_test.gd` — soak de fiabilité (auto-place + auto-pilote jusqu'à la fin, 2→6 joueurs).
- `tools/capture_play.gd` — captures d'écran du jeu réel (fenêtré ; plateau, lancer, fin, personnages).
- `tools/generate_audio.gd` — régénère les WAV de `assets/audio/`.
- `tools/auto_board.gd` / `tools/auto_pilot.gd` — briques réutilisables (placement légal, IA gloutonne BFS).

> Notes de dev complémentaires (rôle, vision, commandes) : `docs/dev-notes/`.
