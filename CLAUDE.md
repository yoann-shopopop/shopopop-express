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

**La source de vérité du gameplay est la page Notion « SHOPOPOP Express 2 - LE Retour »**
(`3732c5c7-9816-8027-bddc-e78f7729d8a5`). `docs/SHOPOPOP-EXPRESS-GAME-RULES.MD` en est une **copie
synchronisée** (dernière synchro : 2026-06-02) ; en cas de divergence, Notion fait foi. Les règles
évoluent encore (voir « Points encore ouverts ») : ne pas figer dans le code un comportement issu
d'une formulation douteuse sans confirmation.

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
- **Carte personnage** : un **mode de transport** (qui fixe le nombre de dés), **2 couleurs** = les
  quartiers de son *trajet régulier*, et **1 super-pouvoir propre** utilisable **une seule fois**
  (les pouvoirs sont variés — pas uniquement « annuler un événement »).
- **4 modes de transport** → nb de dés : **vélo** (1 dé), **à pied** (1 dé), **voiture** (2 dés),
  **camion** (2 dés). Certains événements/pouvoirs dépendent du mode (le vélo notamment).
- **8 personnages** (2 par transport) aux pouvoirs spécifiques : Axel·le (Bouclier Vert), Camille
  (Habitué·e du Quartier), Gégé (Passage Secret), Dolly (Bonne Marcheuse), Vic (Coup d'Accélérateur),
  Sam (Dépassement), Margot (Chargement Pro), Charlie (Carnet d'Adresses). → modéliser le pouvoir comme
  un effet de données par personnage, pas un `if` géant.
- **4 couleurs de quartier** : 🔴 Rouge, 🟡 Jaune, 🟣 Violet, 🔵 Bleu.
- **Drive** (point de retrait, zone grise) et **destinataire** (espace vert) sont des **jetons posés sur
  les tuiles-quartiers**, pas des tuiles séparées. Une **livraison** = relier un drive à un destinataire ;
  elle s'étend sur **1 ou 2 tuiles**. Chaque tuile posée porte 1 drive + 1 destinataire, donc
  **nb de livraisons = nb de tuiles posées**.
- **Effectif & tuiles** : 2 à 6 joueurs. Jusqu'à 3 joueurs → 3 tuiles/joueur ; à partir de 4 →
  2 tuiles/joueur. (2j=6, 3j=9, 4j=8, 5j=10, 6j=12 tuiles = livraisons.)
- **Tour de jeu** : Planification (choisir une livraison) → Déplacement (dés selon le transport, avancer
  le pion sur les routes) → Événements (case arc-en-ciel = piocher/résoudre une carte) → Prise en charge
  (**coûte +1 point de déplacement**) → Livraison (**gratuite**). Fin de partie : plus aucune livraison.
- **Scoring** : 5 pts de base par livraison ; **+10 pts par tuile de la livraison dont la couleur
  appartient au joueur** ; **exception** : livraison sur une **seule** tuile à soi = **20 pts** (au lieu
  de 10). Donc 2 tuiles à soi (25) = 1 tuile à soi (25).
- **Cartes événement** : deux familles — **Avantages** et **Malus** (blocages, retours forcés, fin de
  tour). Le **pont** (1/joueur) permet de franchir certains obstacles ; fermé par « Pluies Torrentielles ».

### Points encore ouverts (ne pas coder en dur sans validation)

Détaillés dans la section « Points ouverts » de `SHOPOPOP-EXPRESS-GAME-RULES.MD` :

- **Objectif coopératif vs compétitif** : intro collective mais score individuel — à trancher.
- **Capacité de volume** : évoquée par le pouvoir de Margot, jamais définie ailleurs.
- **Mécanique du pont** : usage non décrit ; recouvre en partie le pouvoir *Passage Secret* de Gégé.
- **Cumul des doublements** de points (*Livraison Écologique*) : ponctuel ou persistant ?
- **Variance** : événements « téléportation » et **5/5 (+20 pts)** très swingy.
- **Score mono-tuile == deux-tuiles** (25 pts) : favorise les livraisons compactes.

## Conventions Godot

- Scènes `.tscn` et scripts `.gd` versionnés ; le dossier `.godot/` est ignoré (cache régénéré).
- EOL `lf`, UTF-8 (`.editorconfig`, `.gitattributes`).
- Vue du dessus : prévoir une caméra orthographique ou perspective haute fixe ; la grille du plateau
  est l'ancrage des positions — penser un système de **coordonnées de cases** découplé des positions
  monde 3D dès le départ (déplacements comptés « en cases », pas en mètres).

## Architecture implémentée

**Découplage strict logique / rendu** : la logique de jeu est en `RefCounted`/`Resource` purs (sans
`Node`, testés en `--headless`), le rendu et les entrées sont des `Node` séparés. Deux ensembles
cohabitent : le **socle plateau** (grille hex + placement) et les **systèmes de gameplay** (pion,
paquet de cartes, déplacement, dés), chacun **isolé et indépendant**, branchés ensemble à
l'intégration. Chaque système a une **scène de démo autonome** (`scenes/*_demo.tscn`).

```
src/logic/      hex_utils.gd (HexUtils)   maths hexagonales pures, statiques
                board.gd (Board)          état du plateau + règles de placement
src/blocks/     block_definition.gd       BlockDefinition (Resource) = bloc en données
src/pawns/      pawn_definition.gd        PawnDefinition (Resource) : id, nom, image, color, type
                pawn.gd (Pawn)            état runtime : position + steps, invariants, signaux
src/cards/      card_definition.gd        CardDefinition (Resource) : identité placeholder
                deck.gd (Deck)            pioche/défausse, reshuffle, return_to_top, RNG injectable
src/movement/   movement.gd (Movement)    marche auto-évitante sur un set de cases injecté
src/dice/       dice_roller.gd (DiceRoller) lance X D6, mémorise le résultat, RNG injectable
src/view/       hex_grid_view.gd          quadrillage fantôme + tuiles posées (MultiMesh)
                block_ghost.gd            aperçu vert/rouge sous le pointeur
                hex_mesh_factory.gd       tuile = prisme CylinderMesh pointy-top (sans asset)
                pawn_view.gd (PawnView)   figure cône+tête (cotransporteur, colorée) / jeton-image
                card_view.gd (CardView)   carte 3D : face placeholder, dos logo + CARD_TYPE
                die_view.gd (DieView)     dé 3D à points, orienté sur la valeur
                game_config.gd            constantes de présentation
src/interaction/placement_controller.gd  pointeur souris/tactile -> case -> pose/rotation
                camera_rig.gd             pan/zoom (molette + clic-droit, pinch + 2 doigts)
src/ui/         placement_ui.gd           barre Hexagone / Pont / Rotation (CanvasLayer extensible)
src/main.gd     scenes/main.tscn          composition root du prototype de placement
src/*_demo.gd   scenes/*_demo.tscn        démos autonomes : pawn / card / movement / dice
resources/blocks/  hex19.tres, bridge3.tres   blocs canoniques
tools/          generate_block_resources.gd, capture_preview.gd   outils dev
```

### Systèmes de gameplay (logique pure, testée, à intégrer)

Chacun ignore les autres et le `Board` ; le branchement se fera dans un composition root d'intégration.

- **Pion** (`Pawn` + `PawnDefinition`) : `position` (case) + `steps` (cases à parcourir), pose unique,
  pion fixe immobile ; signaux `placed/moved/steps_changed`. Cotransporteur = figure colorée, drive/
  destinataire = jeton-image.
- **Paquet** (`Deck` + `CardDefinition`) : `draw(n)` / `discard` / `reshuffle` / `return_to_top`,
  RNG injectable. Règle démo : tirer 2 → garder 1 (l'autre revient sur la pioche) → activer le pouvoir
  → défausse.
- **Déplacement** (`Movement`) : reçoit un **set de cases praticables** + une case de départ + un
  budget ; marche **auto-évitante**, total obligatoire, arrêt si bloqué. Aucune dépendance Board/Pawn.
- **Dés** (`DiceRoller`) : `roll(X)` de D6, mémorise le résultat, `total()` / `consume()`.

**Intégration visée** : `walkable` du `Movement` construit depuis `Board` (puis **routes uniquement**) ;
`DiceRoller.total()` = budget du `Movement` ; fin de déplacement → `pawn.move_to(current)` ; `Deck`
pour les événements (cases arc-en-ciel).

**Coordonnées de cases** (réponse à l'exigence « coordonnées découplées ») : axiales **pointy-top**,
une case = `Vector2i(q, r)`, conventions Red Blob Games. `HexUtils` fournit voisins, distance, rotation
60°, et conversions case↔monde (plan XZ). C'est l'ancrage de tous les déplacements « en cases ».

**Blocs ↔ assets** (correspondance directe avec `assets/boards/`) :
- `hex19` = hexagone **côté 3 = 19 cases** = une tuile de plateau. Les quartiers comptent **4 couleurs**
  (🔴 Rouge, 🟡 Jaune, 🟣 Violet, 🔵 Bleu — décision validée, le Violet est retenu), correspondant aux
  couleurs des cartes personnage. ⚠️ **Assets à compléter** : `assets/boards/` ne contient pour l'instant
  que 3 couleurs (`B1..B3`, `R1..R3`, `Y1..Y3`) ; les tuiles **Violet** (`V1..V3`) restent à produire.
- `bridge3` = **ligne de 3 cases** (eau–route–eau) = `BRIDGE.png`.

`BlockDefinition` décrit un bloc par ses **offsets de cases** (+ rotation) ; créer un bloc = créer un
`.tres`, sans code. `Board` gère un `Dictionary` case→bloc, expose les cases (utile pour un futur **A***
sur les routes) et impose à `can_place()` : pas de chevauchement + adjacence à un bloc existant (le
1er bloc est libre).

**Rendu** : scène 3D + **caméra orthographique top-down** (effet plateau via épaisseur + ombres),
cohérent avec `GL Compatibility`. **Entrées** pensées **souris ET tactile** via `InputMap` (action
`rotate_block`).

### À aligner sur les règles (écarts connus, prochaines étapes)

Le placement actuel est **générique** ; pour coller aux règles il faudra notamment :
- Donner un **type de terrain à chaque case** (route / eau / espace vert / zone grise / arc-en-ciel /
  enseigne) — à porter sur `BlockDefinition` (par case). Les visuels existent déjà dans `assets/boards/`.
- Renforcer l'adjacence : la règle exige que **deux tuiles ne se joignent que si une *route* touche une
  *route*** (cf. règles). `Board.can_place` ne teste pour l'instant que l'adjacence de cases.
- Déplacements **sur les routes uniquement** + **A*** avec preview de trajectoire (le `Board` expose
  déjà le graphe de cases pour ça).
- Texturer les tuiles avec les PNG du plateau plutôt que la couleur unie de prototypage.

> Notes de dev complémentaires (rôle, vision, commandes) : `docs/dev-notes/`.
