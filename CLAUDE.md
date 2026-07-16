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
- **Livraison** = un **drive** (point de retrait, case urbaine/grise) + un **destinataire** (case
  verte), **appariés au hasard** (mono- ou bi-tuile ; 1 drive et 1 destinataire posés par tuile).
  Cycle de vie : **Disponible → Réservé → En cours → Terminé** (`DeliveryStatus`). Une **enseigne
  fictive** habille le drive ; un **destinataire fictif** habille le point vert. **Total de
  livraisons d'une partie = total de tuiles posées.**
- **Tour de jeu** : Planification (lancer les dés) → Déplacement (sur les routes). **Pendant** le
  déplacement, lorsqu'il est sur la **tuile** d'un drive *disponible*, le joueur peut **réserver** la
  livraison (statut **Réservé**, **2 livraisons max** « en vol » par joueur). Arriver sur la **case du
  drive** → **En cours** (automatique) ; arriver sur la **case du destinataire** → **Terminé**
  (automatique). **Tout est gratuit** (plus de coût de prise en charge). Événements : case arc-en-ciel =
  piocher/résoudre une carte, la case est **consommée** puis **réarmée à la manche suivante**. Le
  pool d'identités étant plafonné au nombre de tuiles, le **recyclage** (roulement) ne joue plus dans
  la partie standard : à la livraison le drive reste **libre**. **Fin de partie** : plus aucune
  livraison actionnable (les tours d'un joueur sans action possible sont passés automatiquement).
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
- ~~Nombre de joueurs / quantités~~ **(résolu, implémenté 2026-07-16)** : table des règles appliquée
  (**3 tuiles/joueur jusqu'à 3 joueurs, 2 dès 4** — `SetupDistributor.tiles_per_player`) et **total
  de livraisons = total de tuiles posées** (pool d'identités plafonné, `DeliveryGenerator`
  `max_deliveries`). ⚠️ **V1 numérique = 2-4 joueurs** (le solo arrive au Lot 1 du plan Steam) : les
  configs 5-6 (deux joueurs partageant une
  couleur ⇒ identité illisible + double +10 sur les mêmes tuiles) sont coupées de l'UI (arbitrage
  Étape 3 du plan Steam, 2026-07-16) — réintroduction possible avec 6 vraies couleurs.
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
- **Coopératif → compétitif assumé (tranché 2026-07-16, plan Steam Étape 3)** : les incitations
  réelles sont compétitives (réserver la livraison d'un adversaire est le meilleur coup) ; l'identité
  devient « course de livraisons » au ton convivial (« prendre la course », comme le métier). L'écran
  de fin actuel (classement + total collectif) reste ; le re-framing des textes arrive au Lot 1, et
  l'esprit « pas de perdant » vivra dans le futur mode solo « La Tournée ».

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
                setup_distributor.gd          tire tiles_per_player(n) patterns partagés (3, ou 2 dès 4 joueurs), recolore, assigne le départ
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
= hexagone **côté 3 = 19 cases** (**8 patterns** dans `resources/blocks/patterns/` — p1-p3 tracent les
3 tuiles physiques B1/B2/B3, **p4-p8 sont 5 patterns digital-only ajoutés le 2026-07-16** pour la
rejouabilité de La Tournée, mêmes règles de génération, cf. `tools/generate_block_resources.gd`),
routes en segments **droits alignés sur la grille** = reliant les **coins** du grand hexagone,
`coin i = DIRECTIONS[i]·R` ; relier des centres d'arête ferait zigzaguer la route). **2 en Y** = une
droite traversante `{0-3}` + une bifurcation vers un coin adjacent (miroir gauche/droite, 3 connecteurs)
et **1 en croix** = deux droites
croisées `{0-3}+{1-4}` (4 connecteurs). Les **connecteurs sont les coins atteints** (jonction
route-à-route, tuiles assemblées en quinconce). **Case spéciale au centre**, + eau/urbain/vert
procéduraux avec **≥2 vert et ≥1 urbain**. **Pont** =
`Eau–Route–Eau` dont **seule la case centrale (route)** connecte. `SetupDistributor` tire
`tiles_per_player(n)` patterns (partagés — 3, ou 2 dès 4 joueurs), recolore par joueur, + 1 pont +
un **départ** (case verte en bord de route).

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
                tutorial_scenario.gd (TutorialScenario)  plateau/livraison/deck scriptés du tutoriel (pur, testable)
                tutorial_director.gd (TutorialDirector)  séquence réactive des bulles du tutoriel (écoute GamePhase)
src/cards/      event_card_definition.gd        EventCardDefinition : effect/amount/condition/is_malus
src/interaction/movement_controller.gd          pointeur → case : émet cell_hovered/hover_cleared/cell_clicked (dumb, ne touche pas GamePhase)
src/view/       clip_card_view.gd (ClipCardView) carte 3D enseigne/statut/destinataire (bind combo OU Delivery)
                delivery_list_view.gd (DeliveryListView) colonne gauche défilable : 1 ClipCardView par Delivery
src/ui/         play_hud.gd (PlayHud)           HUD de jeu (CanvasLayer) : barre titre (tour/score + zoom ± + « ? »), action contextuelle + pouvoir + Coup de pouce, DECK/DÉFAUSSE
                player_panel.gd (PlayerPanel)   bandeau sous la barre titre : 1 carte/joueur (initiale+couleur, score, jauge X/2, pouvoir)
                delivery_panel.gd (DeliveryPanel) colonne gauche ; survol d'une carte → liaison avec le plateau (GameRoot)
                tutorial_overlay.gd (TutorialOverlay)  bulle du tutoriel (bas d'écran) + bouton Terminer
resources/characters/*.tres   8 personnages   ·  resources/events/*.tres   ~22 cartes (outil generate_event_cards.gd)
```

**Boucle de tour** (`GamePhase`, round-robin) : PLANIFICATION (`begin_movement(budget)` depuis
`DiceRoller`) → DEPLACEMENT (`try_step` sur les **routes uniquement** ; pendant le déplacement,
`reserve_delivery()` sur la tuile d'un drive disponible — **2 max** par joueur) → EVENEMENT (case
arc-en-ciel → `apply_event`). Les transitions de livraison sont **automatiques** et **gratuites** :
sur la case du drive → EN_COURS ; sur la case du destinataire → livrée (score + recyclage du
destinataire via `DeliveryGenerator`). Fin de partie quand plus aucune livraison n'est actionnable.
Pouvoir une seule fois (`use_power`).

**Déplacement clic = marche auto (2026-07-16)** : `TurnMovement.path_to(target)` (BFS sur le
praticable courant) renvoie la séquence de cases jusqu'à `target` ; `MovementController` n'émet plus
que des signaux (`cell_hovered`/`hover_cleared`/`cell_clicked`), et `GameRoot` fait tout le travail :
survol → surbrillance du chemin (bleu si `path.size() <= remaining()`, rouge sinon) + coût en cases ;
clic → `_walk_path` enchaîne les `try_step` un par un (délai ~0,2 s pour laisser le hop de `PawnView`
se jouer), s'arrête si un pas échoue ou si une case événement interrompt le déplacement. Généralise
l'ancien clic case-par-case (un voisin adjacent = chemin à 1 case). Boutons d'action désactivés
pendant la marche (`PlayHud.set_actions_enabled`).

**Réservation proposée automatiquement (2026-07-16)** : dès l'arrivée sur la tuile d'un drive
réservable, `GameRoot._maybe_prompt_reservation` ouvre un chooser (« Réserver ? » / Annuler) — la
marche auto s'y **met en pause** (`await reservation_prompt_resolved`) avant de reprendre. Demandé
**au plus une fois par tour et par livraison** (`_reservation_prompted`, remis à zéro à chaque tour) ;
décliner n'empêche pas de réserver ensuite via le bouton manuel.

⚠️ `Movement` (auto-évitant, démo) **n'est pas** réutilisé en jeu : `TurnMovement` autorise revisite,
budget ajustable (events ±) et téléportation (cartes). « Tuile à moi » = la **couleur de quartier**
(`PlacedPiece.owner`) égale la **couleur du joueur** (`Player.color`) — l'identité de score, pas les
2 couleurs du personnage.

**Placement aléatoire des livraisons** : `DeliverySetup.build(board, rng, max_count, excluded)` pose
**1 drive (case URBAINE) + 1 destinataire (case VERTE) par tuile**, puis **apparie drives et
destinataires 1-à-1 dans un ordre mélangé** (RNG injecté) → le destinataire d'une livraison n'est **pas
forcément sur la tuile de son drive** (mono- OU bi-tuile). 1 livraison par tuile.
`Delivery.tiles = [tuile_drive, tuile_destinataire]` (drive d'abord) ; le scoring `ScoreCalculator`
5 + 10 (tuile drive) + 10 (tuile destinataire) gère le cross-tuile (5/15/25). Les identités (enseigne +
destinataire) sont attribuées par livraison via `DeliveryGenerator` (`GameRoot`) — **pool plafonné au
nombre de tuiles** (`max_deliveries`) pour respecter « total tuiles = livraisons » ; le recyclage
(roulement) ne joue que si le plafond est levé (futurs modes score). Les cases de départ des joueurs
sont exclues du pool destinataires. L'art « storefront » du drive est posé sur les **vraies** cases via
`HexGridView.set_drive_cells(...)` (appelé par `Main`/le harnais après le build).

**Fin de partie resserrée (2026-07-16)** : bannière **« Dernière tournée ! »** quand il reste moins de
livraisons que de joueurs (`GameRoot._announce_last_run`) et **tours morts passés automatiquement**
(`GamePhase._skip_idle_players` + signal `turn_skipped` : un joueur sans livraison en vol ni rien de
réservable n'a plus aucune action possible — jamais déclenché sur un plateau sans livraisons).
**Réservation refusable** : quand « Réserver » est proposé, un bouton secondaire « Fin de tour »
coexiste (`PlayHud._end_turn_btn`) — garder un slot libre est un choix tactique légitime.

**Jetons « Coup de pouce » (2026-07-16, mitigation du hasard)** : `Player.boost_tokens` (2, un pool
— pas un pouvoir one-shot). Juste après le lancer et **avant tout premier pas**
(`GamePhase.spend_boost_token`, vérifie `movement.path().size() <= 1`), dépenser un jeton pour
relancer tous les dés ou fixer un dé sur sa face max (`DiceRoller.force`) ; ajuste le budget de
déplacement du delta réel. UI : bouton 🍀 (`PlayHud.set_boost_tokens`), chooser unique listant
« Relancer tout » + un choix par dé (`GameRoot._on_boost_requested`).

**Panneau joueurs persistant + liaison au survol (2026-07-16)** : `PlayerPanel` (sous la barre
titre) remplace les anciennes pastilles nues — une carte par joueur : initiale+couleur, score, jauge
« X/2 en vol », icône pouvoir (grisée si consommée). Survoler une carte de `DeliveryPanel` surligne
en blanc le(s) case(s) drive/destinataire sur le plateau (+ un lien si cross-tuile) via
`GameRoot._on_delivery_hovered` ; le sens inverse (survol d'un jeton 3D) est **volontairement non
fait** — demanderait un système de raycast/picking 3D qui n'existe pas et risquerait de percuter les
clics de `MovementController`.

**Accessibilité daltonisme (2026-07-16)** : l'identité ne repose jamais sur la seule couleur.
`PawnView` donne une silhouette distincte par couleur vue du dessus (cercle/carré/losange/anneau,
`PawnDefinition.shape_kind`) ; `PlayerColor.initial_of` (B/R/V/J) sur les pastilles ; `DeliveryStatus.icon`
(●/◐/▶/✓) en plus de la couleur sur les statuts de livraison.

**Ton compétitif assumé (2026-07-16)** : réserver la livraison d'un adversaire affiche « Course
prise ! » (`GameRoot._on_reserve`) ; écran de fin : « Vainqueur » + « Tournée du jour : N pts livrés
au total » (ex-« Total collectif », recadré en statistique de saveur, pas en trophée collectif).

**Décomposition du score + carte de référence (2026-07-16)** : à chaque livraison, étiquette 3D
flottante « 5 +10 (ton quartier) +10 (ton client) = 25 » (`GameRoot._show_score_breakdown`,
`ScoreCalculator.breakdown_delivery`), signalant aussi les écarts (×2 Livraison Écologique…). Bouton
« ? » permanent (+ Échap) : overlay icône-first (tour, livraisons, score, cases & pouvoirs) via
`PlayHud.show_reference`.

**Contenu 100 % fictif (purge juridique 2026-07-16)** : les 12 destinataires (anciennement des
personnalités réelles avec portraits — interdit à la diffusion) et les 9 enseignes (parodies de
marques) sont remplacés par des personnages/commerces fictifs écrits avec soin
(`resources/destinataires|enseignes/*.tres`, régénérables par `tools/generate_destinataires.gd` /
`generate_enseignes.gd` ; champ `manie` de saveur sur les destinataires). `texture = null` en
attendant l'illustrateur (les vues retombent sur couleur + nom). Les anciens contenus sont isolés
dans **`quarantine/`** (hors chemins de chargement) — suppression définitive + question du dépôt
public (l'historique git les contient) à arbitrer par l'équipe. **Ne jamais réintroduire de personne
réelle ni de parodie de marque dans les données.**

**Atteignabilité (anti-softlock)** : seules des cases **adjacentes au réseau** entrent dans les pools, et
chaque paire drive→destinataire est validée par `RoadNetwork.is_reachable` (BFS) — sinon une livraison
resterait à jamais en vol et la partie ne finirait pas. Soak headless `tools/soak_test.gd` (parties
2→4 joueurs auto-pilotées × 10 seeds, **0 softlock**, ré-exécuté après le Lot 0 : confirme au passage
6/9/8 livraisons pour 2/3/4 joueurs — « total tuiles = livraisons » tient à l'effectif).

**Solo vs IA (2026-07-16, `tools/auto_pilot.gd` promu en adversaire in-game)** : un siège se marque
`Player.is_ai` (toggle 🤖 par siège dans `CharacterSelect`, avant de choisir un personnage ; le
remplissage groupé « Tout aléatoire » laisse les sièges restants en Humain). `GameRoot._play_ai_turn`
rejoue en asynchrone la logique pure d'`AutoPilot` (`choose_target`/`step_toward`, réutilisées
telles quelles) mais **cadencée** (`_AI_STEP_DELAY` 0,12 s/pas, plus rapide que la marche auto humaine)
au lieu du tour synchrone d'origine (toujours utilisé tel quel par le soak/`capture_play.gd`).
Déclenché par `GamePhase.turn_changed` **et** une fois pour le tout premier siège (ce signal ne part
que depuis `end_turn`). Règles V1 assumées : **l'IA n'utilise jamais son pouvoir** ; les événements
sont résolus par `_ai_resolve_event` — mêmes règles de pioche/défausse que l'humain (pioche 2, garde
1, Carnet d'Adresses) mais **auto-sélection court-circuitée** (préfère un Avantage) sans le modal 3D
interactif (`_on_event_triggered` no-op si `is_ai`). Réservation **silencieuse** (pas de chooser de
confirmation). ⚠️ Piège d'ordonnancement corrigé : `_ai_playing` doit repasser à `false` **avant**
`_phase.end_turn()`, pas après — `end_turn()` émet `turn_changed` en synchrone (un REJOUER sur le
même siège, ou le siège suivant si lui aussi IA, ré-entre immédiatement dans `_on_turn_changed`) ; à
l'envers, ce ré-entrant serait avalé par le flag encore vrai et cette IA ne jouerait jamais son tour.
`_play_ai_turn` ne redémarre pas une fois `GamePhase.is_finished()` (sinon le tour par tour continue
de tourner indéfiniment, invisible derrière l'écran de fin). Le survol/clic humain
(`MovementController`) et le chooser de réservation sont désactivés pendant qu'une IA joue.

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
d'ambiance procéduraux `assets/audio/`, bouton mute). Écrans : titre (Jouer + **Tutoriel** + Son),
choix du nombre de joueurs, **sélection des personnages** (`CharacterSelect`, aperçu transport/dés/
pouvoir, toggle 🤖 IA par siège), HUD de jeu, **écran de fin classé + total collectif + Rejouer**.

**Tutoriel-première-partie (2026-07-16)** : bouton « Tutoriel » sur l'écran-titre →
`Main._start_tutorial()` court-circuite entièrement la phase de placement pour le plateau scripté de
`TutorialScenario` (1 tuile GREEN→ROUTE→EVENT→ROUTE→URBAN(drive)→GREEN(destinataire) en ligne
droite, **1 livraison mono-tuile forcée** qui rapporte le 25 complet) posé via les surcharges
déterministes de `GameRoot.setup` (task ci-dessus) : `forced_deliveries` (une seule, déjà identifiée)
+ `forced_event_order` (Grand Soleil l'Avantage, Recharge de Batterie le Malus — un vrai choix au
« pioche 2 garde 1 »). `TutorialDirector` (Node) est **réactif, pas verrouillant** : il écoute les
mêmes signaux que `GameRoot` (`subphase_changed`, `delivery_reserved`, `delivery_in_progress`,
`event_triggered`, `delivery_completed`) et affiche la bulle correspondante via `TutorialOverlay`
(CanvasLayer, bas d'écran), sans bloquer aucun bouton ni case — le joueur joue pour de vrai, le
tutoriel commente. S'adapte donc au jet de dés réel (le mini-plateau, 5 cases de bout en bout, avance
sur n'importe quel jet 2d6, en un tour ou deux). Dernière bulle → bouton « Terminer » →
`get_tree().reload_current_scene()`. Vérifié à la fois par tests GUT (`test_tutorial_scenario.gd`,
`test_tutorial_director.gd`) et par un harnais headless bout-en-bout sur la **vraie** scène
(`tools/smoke_tutorial.gd` : boot → clic Tutoriel → lancer → réserver → événement → livraison → 25
points → bouton Terminer).

**Événements — les 22 cartes ont un effet** (`apply_event`). Les téléportations
(retour drive/départ, escorte, faille, raccourci) sont propagées à la **position autoritaire**
(`_positions`) + à la vue + aux transitions de livraison via `_sync_pawn_after_event` (sinon le pion ne
bougeait pas → « aucun impact »). Les ex-stubs sont câblés en V1 (simplifiés, board-dependent dans
`GamePhase._apply_spatial_event`) : Faille = téléport au drive le plus loin ; Raccourci = téléport au
prochain drive dispo ; Manifestation = budget −½ ; Fuite = détour −3 ; Pluies = détour −2 (pont
toujours setup-only). **Les textes affichés des cartes sont dérivés de l'effet codé**
(`src/ui/event_card_face.gd` : bandeau Avantage/Malus, titre, effet en évidence, description
générée — jamais la règle physique quand elle diffère). **Cases arc-en-ciel consommables
(2026-07-16)** : un déclenchement par case et par manche (`GamePhase._spent_event_cells`, signaux
`event_cell_spent`/`event_cells_rearmed`, texture `event_spent.png` via
`HexGridView.set_spent_event_cells`) — tue l'exploit de farm (aller-retour sur la case + deck
infini) et la friction du re-déclenchement forcé.

**Injection optionnelle pour une session scriptée (2026-07-16)** : `GameRoot.setup(board, players,
camera, rng, forced_deliveries, forced_dice, forced_event_order, uncapped_deliveries)` — les 5
derniers paramètres sont optionnels, absents = comportement aléatoire inchangé (le pool de
destinataires plafonné au nombre de tuiles, la règle multijoueur normale). `forced_deliveries`
(Array[Delivery] déjà identifiées) court-circuite entièrement `DeliverySetup`/`DeliveryGenerator`
(pas de générateur de recyclage pour une session courte scriptée, `is_finished()` fonctionne quand
même) — le moyen le plus robuste de garantir un arrangement précis (ex. « une livraison mono-tuile à
25 »). `forced_dice` remplace le `DiceRoller` interne (y appeler `.force()` pour figer des valeurs).
`forced_event_order` remplace le contenu mélangé du deck d'événements par un ordre de pioche exact.
`uncapped_deliveries` (bool) désactive le plafond « total tuiles = livraisons » — le pool de
recyclage reste plein (voir La Tournée ci-dessous). Activé pour le tutoriel (voir plus bas), La
Tournée et les tests déterministes.

### Mode solo « La Tournée » (2026-07-16)

Score-attack solo autour de la **même** boucle `GamePhase`/`GameRoot` : un plateau **auto-assemblé**
(`AutoBoard.build(1, rng)` — le même code que le placement humain, instantané : la « tournée
express » du plan), **16 tours** = une **journée 8h→20h** (`TourneeSession.clock_text()`, 45 min/tour
cosmétiques), un **bonus de chaînage** nommé (+5 dès la 2ᵉ livraison complétée **dans le même tour** —
le mini-TSP réserver→charger→livrer devient un score visible) et un **« score du collègue »** :
`TourneeSession.compute_ghost_score(...)` fait jouer un `AutoPilot` glouton sur le **même** plateau et
les **mêmes livraisons de départ** (clonées), *avant* que la vraie session commence, pour donner un
repère concret à battre. Paliers **Bronze 150 / Argent 225 / Or 300**, calibrés une fois offline
(`tools/calibrate_tournee.gd`, 200 parties, percentiles ; à relancer et reporter ici après tout
changement de score/plateau) — à recalibrer si le calcul ou les tuiles changent.

⚠️ **Le pool de destinataires doit rester non plafonné** (`GameRoot.setup(..., uncapped_deliveries =
true)`) : la règle multijoueur normale (« total tuiles = livraisons », pool capé au nombre de tuiles)
viderait le pool en 5-7 tours sur un plateau solo (3 tuiles) et terminerait la session bien avant les
16 tours prévus — bug réel rencontré et corrigé pendant l'implémentation (voir
`tools/smoke_tournee.gd`).

`TourneeSession` (Node, écoute `GamePhase.delivery_completed`/`turn_changed`) porte l'état pur (tours,
chaînage, `is_finished()` du plateau OU 16 tours écoulés → `session_finished`) ; `GameRoot` s'y
branche via `set_tournee_session(session)` : bannière de chaînage, horloge à la place de « Manche N »
dans `PlayHud` (`set_tournee_clock`, remplace **silencieusement** `set_round` tant qu'actif),
écran de fin dédié (`PlayHud.show_tournee_end` — score, palier, comparaison au fantôme ; remplace
`show_end`, pas de classement puisqu'un seul joueur). `DeliveryGenerator.peek_upcoming(n)` (LIFO,
sans consommer) alimente une mini-file « À venir » dans `DeliveryPanel` — utile dès qu'un pool
recycle, donc partagée avec le multijoueur normal. Entrée : bouton « La Tournée (solo) » sur
`TitleScreen` → `Main._start_tournee()` (aucune phase de placement).

Vérifié par `tests/test_tournee_session.gd` (chaînage, fin de session, fantôme déterministe) et par
un harnais headless bout-en-bout sur la **vraie** scène (`tools/smoke_tournee.gd` : boot → clic « La
Tournée » → horloge à 8h00 → IA joue les 16 tours → `session_finished` avec un score positif).

### i18n EN + FR (2026-07-16)

Le **français reste la langue par défaut** ; l'anglais est une table de traductions chargée en plus,
via le système `tr()` natif de Godot — pas de refonte de l'UI, juste chaque littéral utilisateur
enveloppé dans `tr("...")`. Les **noms propres restent en français** dans les deux langues (huit
personnages, neuf enseignes, douze destinataires, les noms des huit super-pouvoirs comme « Bonne
Marcheuse » ou « Carnet d'Adresses ») — seuls les **titres des 22 cartes événement** sont traduits
(ce sont des concepts, pas des noms propres) ; le champ `manie` des destinataires n'est **branché à
aucune vue** actuellement, donc non traduit (rien à vérifier tant que rien ne l'affiche).

- **Clé = texte français lui-même** (pas d'identifiants séparés `UI_PLAY` etc.) : `tr("Jouer")` sert à
  la fois de source de vérité FR et de clé de recherche EN. `res://localization/strings.csv` (colonnes
  `keys,en`, ~200 lignes) est importé par Godot en `res://localization/strings.en.translation` et
  déclaré dans `project.godot` (`[internationalization] locale/translations`).
- ⚠️ **`locale/fallback` doit être explicitement `"fr"`** (`project.godot`). Sans ce réglage, Godot
  retombe sur son défaut **`"en"`** dès qu'une locale n'a pas sa propre table — puisque seul l'anglais
  est enregistré, **toute la langue française basculerait silencieusement en anglais**, y compris en
  jeu normal (bug réel rencontré et corrigé pendant l'implémentation ; couvert par
  `tests/test_i18n.gd`).
- **`src/localization.gd`** (autoload `Localization`, `project.godot` `[autoload]`) : force
  `TranslationServer.set_locale("fr")` au boot, **avant toute scène** (y compris les outils headless
  et les tests GUT) — sans ça, la locale de démarrage suit l'OS hôte, donc une machine en anglais
  ferait démarrer le jeu en anglais. Reste la seule bascule de langue jusqu'à ce que le menu réglages
  (tâche #26) branche un choix persistant par-dessus.
- **Contextes statiques** (méthodes `static func`, pas d'instance `Object` pour appeler `tr()`) :
  `PlayerColor.name_of`, `DeliveryStatus.label`, `TourneeSession.tier_for` utilisent
  `TranslationServer.translate(...)` à la place — équivalent statique-safe de `tr()`.
- **Pluriel irrégulier** (« die »/« dice », pas un simple « s ») : `CharacterSelect._card()` construit
  `dice_label` par une branche explicite (`dice_count <= 1`) plutôt qu'un gabarit à suffixe — le
  nombre de dés d'un personnage n'est jamais que 1 ou 2, donc deux chaînes littérales suffisent.
- **Vérifié** par `tests/test_i18n.gd` (défaut FR, piège du fallback, bascule EN↔FR, les 3 lookups
  statiques) et deux harnais headless bout-en-bout sur la **vraie** scène : `tools/smoke_i18n_en.gd`
  (force `en` **après** le boot — `Main._ready()` crée désormais `GameSettings`, qui recharge sa
  propre langue persistée en tout premier ; un override posé avant le boot serait écrasé, voir la
  section réglages ci-dessous — rejoue le tutoriel, imprime tout le texte rencontré pour relecture
  humaine) et une vérification ponctuelle de `CharacterSelect` + `EventCardFace` en anglais.
  **Relecture par un·e anglophone natif·ve recommandée avant toute publication** (dépendance déjà
  notée dans le plan Steam) : les traductions ci-dessus sont un premier jet cohérent, pas une
  validation linguistique professionnelle.

### Menu réglages minimal + persistance (2026-07-16)

`GameSettings` (`src/game/game_settings.gd`) porte les préférences persistées : volumes
**musique/effets séparés**, plein écran, langue, et un indicateur **rythme rapide** (persisté ici,
sans effet de jeu tant que la tâche #27 ne le consomme pas). **Pas un autoload** : comme
`AudioManager`, `Main._ready()` en crée l'unique instance réelle (`GameSettings.new()`, juste avant
`AudioManager` puisque ses bus audio en dépendent) — les outils headless/tests GUT n'en créent jamais,
donc restent déterministes quel que soit le `user://settings.cfg` réel d'un poste de dev. `GameSettings.current()`
expose cette instance pour le câblage UI ; `SettingsMenu` prend elle une référence **explicite** (pas
de lookup ambiant) pour rester testable isolément.

- **Bus audio séparés** : `audio/bus_layout.tres` (Master + Musique + Effets, enregistré dans
  `project.godot` `[audio] buses/default_bus_layout`) remplace l'ancien mute unique sur Master.
  `AudioManager` route désormais ses voix SFX vers `GameSettings.SFX_BUS` et la musique vers
  `GameSettings.MUSIC_BUS` ; les anciens `AudioManager.toggle_mute()`/`is_muted()` ont disparu, remplacés
  par les curseurs de volume de `SettingsMenu`.
- **`SettingsMenu`** (`src/ui/settings_menu.gd`, CanvasLayer modal) : curseurs Musique/Effets, bascule
  plein écran, boutons de langue FR/English (noms natifs, jamais traduits — convention standard d'un
  sélecteur de langue), bascule rythme rapide, « Fermer »/Échap. Chaque contrôle applique **et**
  sauvegarde immédiatement via `GameSettings` — pas d'étape « Enregistrer » à oublier. Ouverte depuis
  le bouton « ⚙ Réglages » de `TitleScreen` (remplace l'ancien bouton « Son ») et le petit « ⚙ » de la
  barre de titre `PlayHud` (remplace le mute in-game) — les deux appellent `GameSettings.current()`.
- **Persistance** : `user://settings.cfg` (`ConfigFile`, sections `audio`/`display`/`locale`/`pacing`).
  `GameSettings._path` est un point d'injection pour les tests (`set_config_path(...)`) — jamais utilisé
  par le vrai jeu, qui pointe toujours sur `DEFAULT_PATH`.
- ⚠️ **Ordre de boot** : `Localization` (autoload) force `"fr"` en tout premier, PUIS
  `Main._ready()` crée `GameSettings`, qui recharge la langue persistée et peut la **remplacer**
  (`user://settings.cfg` absent ⇒ reste `"fr"`). Un test/outil qui force une langue **avant**
  d'instancier `scenes/main.tscn` se fait donc écraser — forcer **après** le boot à la place (piège
  réel rencontré en écrivant `tools/smoke_i18n_en.gd`, corrigé depuis).
- **Vérifié** par `tests/test_game_settings.gd` (round-trip de persistance, clamp de volume, application
  immédiate de la locale, signal `settings_changed`) et `tests/test_settings_menu.gd` (widgets reflètent
  l'état, curseurs/boutons routent bien vers `GameSettings`).

### Restant / à raffiner

- **Pose manuelle** des jetons drive/destinataire (V1 : placement **auto aléatoire** post-setup, drives
  urbains / destinataires verts, mono- ou bi-tuile, atteignabilité garantie).
- Effets d'événement **interactifs** (choix de cible/quartier) et **persistants inter-tours**.
- **Multijoueur** distant : non implémenté (hot-seat 1 client) ; l'état est découplé et les joueurs identifiés.
- 5–6 joueurs : **coupés de la V1** (boutons retirés de `placement_ui`) — 4 couleurs seulement ;
  rouvrir exigerait 6 vraies couleurs de quartier + équilibrage du scoring territorial.

### Outils de dev (headless / capture)

- `tools/soak_test.gd` — soak de fiabilité (auto-place + auto-pilote jusqu'à la fin, 2→4 joueurs).
- `tools/capture_play.gd` — captures d'écran du jeu réel (fenêtré ; plateau, lancer, fin, personnages).
- `tools/generate_audio.gd` — régénère les WAV de `assets/audio/`.
- `tools/auto_board.gd` / `tools/auto_pilot.gd` — briques réutilisables (placement légal, IA gloutonne BFS).
- `tools/smoke_tutorial.gd` — bout-en-bout headless du tutoriel sur la **vraie** `scenes/main.tscn`
  (boot → clic Tutoriel → lancer → réserver → événement → livraison → 25 pts → Terminer).
- `tools/smoke_tournee.gd` — bout-en-bout headless de La Tournée sur la **vraie** `scenes/main.tscn`
  (boot → clic « La Tournée » → horloge 8h00 → IA joue 16 tours → `session_finished` positif).
- `tools/calibrate_tournee.gd` — calibre les paliers Bronze/Argent/Or de La Tournée (N parties solo
  auto-pilotées, percentiles des scores). `-- <N>` en argument (200 par défaut).
- `tools/smoke_i18n_en.gd` — bout-en-bout headless en anglais sur la **vraie** `scenes/main.tscn`
  (force `en` avant le boot, rejoue le tutoriel, imprime tout le texte affiché pour relecture humaine).

> Notes de dev complémentaires (rôle, vision, commandes) : `docs/dev-notes/`.
