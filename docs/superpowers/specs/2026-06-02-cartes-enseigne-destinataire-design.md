# Design — Cartes enseigne / destinataire & génération de livraisons

> Date : 2026-06-02 · Branche : `feat/cartes-enseigne-destinataire` (depuis `main`)

## Contexte

Les livraisons de Shopopop Express se forment, dans le jeu physique, en **clipsant une carte
*enseigne*** (point de retrait — une enseigne fictive : HYPER TOPINAMBOUR, VISSE & VRILLE, AU P'TIT MARCHÉ…) avec une
**carte *destinataire*** (le ou la client·e — personnages fictifs : Mamie Turbo, Capitaine Apéro, Tata Ginette…). Le principe est inspiré des **combos race/pouvoir de Small World** :
l'appariement enseigne × destinataire est **aléatoire** et génère une livraison.

Un **encart « statut »** se clipse *entre* les deux cartes pour matérialiser l'état de la livraison :

- **aucun encart = livraison DISPONIBLE** (personne ne l'a prise) ;
- **RÉSERVÉ** puis **EN COURS** quand un·e joueur·euse s'en occupe ;
- une fois **LIVRÉE**, on **retire le destinataire + l'encart statut**, l'enseigne reste en place et on
  **clipse un nouveau destinataire au hasard** parmi ceux encore disponibles.

Ce dépôt est reparti de `main`, **sans la couche de gameplay** (en cours de revue dans une autre PR).
Cette feature est donc livrée comme un **module autonome** — logique pure testée + **scène de démo
interactive 3D** — au même titre que les modules `pawn` / `card` / `movement` / `dice` déjà présents.
Elle deviendra plus tard la **source d'alimentation des livraisons** du plateau.

## Objectif & périmètre

Construire, en couches découplées (logique pure `RefCounted`/`Resource` testée GUT + rendu `Node3D`) :

1. les **données** des enseignes et destinataires ;
2. la **logique de génération** : appariement aléatoire, cycle de statut, recyclage des destinataires ;
3. le **rendu 3D** d'une livraison « clipsée » (enseigne + encart statut + destinataire) ;
4. une **scène de démo autonome** interactive (tapis feutré, caméra orbite/zoom, clic pour faire
   avancer le statut), sur le modèle de `card_demo`.

**Hors périmètre (YAGNI)** : intégration au `Board`/`GamePhase` (autre PR), portraits réels des
destinataires (placeholder pour l'instant), score, « manies » des destinataires.

## Modèle de domaine

### Données (`Resource`, `.tres`)

- **`EnseigneDefinition`** (`src/enseignes/enseigne_definition.gd`)
  - `id: StringName`, `display_name: String`, `texture: Texture2D` (les 9 de `assets/trades/`),
    `color: Color` (teinte de l'onglet).
  - Ressources : `resources/enseignes/*.tres` (9), générées par un outil `tools/generate_enseignes.gd`
    à partir des images existantes.
- **`DestinataireDefinition`** (`src/destinataires/destinataire_definition.gd`)
  - `id: StringName`, `display_name: String` (parodie), `texture: Texture2D = null` (placeholder pour
    l'instant), `color: Color` (bandeau).
  - Ressources : `resources/destinataires/*.tres` (~12), noms semés en dur dans l'outil générateur
    `tools/generate_destinataires.gd` (incl. les 4 de la photo + ~8 autres).

### Logique pure (`RefCounted`, testée GUT)

- **`DeliveryStatus`** (`src/livraisons/delivery_status.gd`) — enum `Kind { DISPONIBLE, RESERVE,
  EN_COURS, LIVREE }` + `label(kind) -> String` (libellés FR pour l'UI).
- **`DeliveryCombo`** (`src/livraisons/delivery_combo.gd`)
  - `enseigne: EnseigneDefinition`, `destinataire: DestinataireDefinition`, `status: int`.
  - `advance() -> bool` : DISPONIBLE→RESERVE→EN_COURS→LIVREE (faux si déjà LIVREE).
  - `is_available() -> bool`, `is_done() -> bool`.
- **`DeliveryGenerator`** (`src/livraisons/delivery_generator.gd`)
  - `_init(enseignes: Array[EnseigneDefinition], destinataires: Array[DestinataireDefinition], slots: int, rng)`
    — RNG injectable (déterminisme en test). Mélange la pioche de destinataires (Fisher-Yates), choisit
    `slots` enseignes, clipse à chacune un destinataire tiré **sans remise**.
  - `combos() -> Array[DeliveryCombo]` : les combos courants (un par emplacement actif).
  - `advance(index: int) -> bool` : avance le statut du combo **jusqu'à EN_COURS au plus** (DISPONIBLE
    →RESERVE→EN_COURS) ; le passage à LIVRÉE se fait via `complete`.
  - `complete(index: int) -> bool` : exige EN_COURS, marque LIVRÉE, **retire le destinataire**, en **tire un nouveau**
    au hasard s'il en reste (sinon l'emplacement reste « enseigne sans destinataire » → combo retiré).
  - `remaining_recipients() -> int`.
  - Signaux : `combo_changed(index)`, `recycled(index)`, `exhausted`.

**Invariants** : tirage des destinataires **sans remise** ; un destinataire n'apparaît jamais sur deux
combos simultanés ; `complete` n'agit que sur un combo `LIVREE`-able (EN_COURS).

## Rendu & démo

- **`ClipCardView`** (`src/view/clip_card_view.gd`, `Node3D`) — rend une livraison clipsée :
  - **enseigne** à gauche (onglet « flèche » à droite, logo de marque, teinte `color`) ;
  - **encart statut** au centre (masqué si DISPONIBLE ; libellé RÉSERVÉ / EN COURS / LIVRÉE) ;
  - **destinataire** à droite (encoche à gauche, nom + bandeau `color`, image ou placeholder).
  - Réutilise le matériel/`Label3D`/animations de `CardView` (deal, slide, discard) ; expose
    `bind(combo)`, `refresh()`, et des animations de clip/retrait pour le recyclage.
- **`scenes/enseigne_demo.tscn` + `src/enseigne_demo.gd`** (`Node3D`) — démo autonome :
  - tapis feutré, **caméra orbite (drag) + zoom (molette)**, lumière/environnement repris de
    `card_demo.gd` ;
  - charge les `.tres`, crée un `DeliveryGenerator` (slots = **4**, RNG randomisé), affiche une rangée
    de `ClipCardView` ;
  - **clic sur un combo → `advance`** (DISPONIBLE→RÉSERVÉ→EN COURS→ puis le clic suivant `complete` →
    LIVRÉE → recyclage animé : le destinataire part, un nouveau se clipse) ;
  - HUD : rappel des contrôles + **compteur de destinataires restants** ; à l'épuisement, message.

## Conventions & cohérence

- Découplage strict logique/rendu (CLAUDE.md) ; logique testée `--headless`, aucun `Node`.
- Noms de domaine **en français** (`Enseigne`, `Destinataire`, `Livraison`) ; enums/`CellType`-style
  restent en anglais comme l'existant.
- **Anti-collision avec la PR gameplay** : on n'utilise PAS les noms `Delivery`/`DeliverySetup`
  (réservés à la couche plateau) ; ici `DeliveryCombo` / `DeliveryGenerator` / `livraisons/`.

## Plan de tests (GUT, logique pure d'abord)

- `test_delivery_combo` : transitions de statut, `is_available`/`is_done`.
- `test_delivery_generator` : nb de combos = slots ; destinataires distincts entre combos ;
  `advance` cycle ; `complete` recycle (nouveau destinataire ≠ ancien, tiré du pool) ; épuisement du
  pool (plus de combo / signal `exhausted`) ; déterminisme via RNG seedé.
- `test_enseigne_definition` / `test_destinataire_definition` : champs.
- Smoke `test_clip_card_view` : `bind` construit les 3 parties sans erreur (dans l'arbre GUT).

## Vérification

```bash
flatpak run org.godotengine.Godot --headless --path . --import
flatpak run org.godotengine.Godot --headless --path . -s res://addons/gut/gut_cmdln.gd
flatpak run org.godotengine.Godot --path .   # essai manuel : scène enseigne_demo
```

Essai manuel : lancer `scenes/enseigne_demo.tscn`, vérifier l'appariement aléatoire, le cycle de
statut au clic, et le recyclage (nouveau destinataire après livraison) jusqu'à épuisement du pool.

## Points ouverts (non figés)

- Couleur de l'enseigne/destinataire vs **couleur de quartier** (scoring) : pour l'instant simple
  accent visuel ; à relier au modèle de quartier lors de l'intégration plateau.
- Portraits réels des destinataires (placeholder pour l'instant).
- Nombre d'emplacements et taille du pool : valeurs de démo (4 slots, ~12 destinataires) ; les vraies
  valeurs viendront du nombre de tuiles posées à l'intégration.
