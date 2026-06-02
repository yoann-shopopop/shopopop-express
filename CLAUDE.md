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
- **Carte personnage** : mode de déplacement (**voiture** ou **vélo**), **2 couleurs** = les quartiers
  de son *trajet régulier* quotidien, et **1 super-pouvoir** utilisable **une seule fois** pour annuler
  un événement.
- **Livraison** = une **tuile enseigne** (point de retrait, zone grise) + une **tuile destinataire**
  (zone verte). Il y a **9 enseignes** et **9 destinataires** → **9 livraisons** construites par partie.
- **Tour de jeu** : Planification (choisir une livraison) → Déplacement (**2 dés**, avancer le pion sur
  les routes) → Événements (case arc-en-ciel = piocher/résoudre une carte) → Prise en charge
  (**coûte +1 point de déplacement**) → Livraison (**gratuite**). Fin de partie : plus aucune livraison.
- **Scoring** : 5 pts de base ; **+** si réalisée sur un trajet régulier (les 2 couleurs du personnage).
- **Cartes événement** : deux familles — **Avantages** (bonus/déplacement supplémentaire, souvent en
  faveur du vélo) et **Malus** (blocages, retours forcés, fin de tour). Le **vélo** est un thème
  récurrent (bonus écologiques). Le **pont** permet de franchir certains obstacles ; fermé par l'événement
  « Pluies Torrentielles ».

### Ambiguïtés connues dans les règles (à clarifier, ne pas coder en dur sans validation)

- **Table de score incohérente** : « trajet régulier 1 couleur = 20 pts » vaut *plus* que « 2 couleurs
  = 10 pts », ce qui est contre-intuitif. À confirmer.
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

## Architecture implémentée — grille hexagonale & placement

Fondations posées sur `feat/hex-grid-placement`. **Découplage strict en 4 couches** : la logique de
jeu ne dépend pas du rendu (on peut faire évoluer le visuel sans toucher aux règles, et tout tester).

```
src/logic/      hex_utils.gd (HexUtils)   maths hexagonales pures, statiques
                board.gd (Board)          état du plateau + règles de placement
src/blocks/     block_definition.gd       BlockDefinition (Resource) = bloc en données
src/view/       hex_grid_view.gd          quadrillage fantôme + tuiles posées (MultiMesh)
                block_ghost.gd            aperçu vert/rouge sous le pointeur
                hex_mesh_factory.gd       tuile = prisme CylinderMesh pointy-top (sans asset)
                game_config.gd            constantes de présentation
src/interaction/placement_controller.gd  pointeur souris/tactile -> case -> pose/rotation
                camera_rig.gd             pan/zoom (molette + clic-droit, pinch + 2 doigts)
src/ui/         placement_ui.gd           barre Hexagone / Pont / Rotation (CanvasLayer extensible)
src/main.gd     scenes/main.tscn          composition root (assemble la scène)
resources/blocks/  hex19.tres, bridge3.tres   blocs canoniques
tools/          generate_block_resources.gd, capture_preview.gd   outils dev
```

**Coordonnées de cases** (réponse à l'exigence « coordonnées découplées ») : axiales **pointy-top**,
une case = `Vector2i(q, r)`, conventions Red Blob Games. `HexUtils` fournit voisins, distance, rotation
60°, et conversions case↔monde (plan XZ). C'est l'ancrage de tous les déplacements « en cases ».

**Blocs ↔ assets** (correspondance directe avec `assets/boards/`) :
- `hex19` = hexagone **côté 3 = 19 cases** = une tuile de plateau (`B1..B3`, `R1..R3`, `Y1..Y3` ; les
  **3 couleurs** correspondent aux quartiers/couleurs des cartes personnage).
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
