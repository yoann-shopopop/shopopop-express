# Design — Refonte UI/UX de la phase de jeu

**Date :** 2026-06-03
**Branche :** `feat/tile-textures-and-placement-ux`
**Statut :** validé en brainstorming, prêt pour le plan d'implémentation

## Contexte & objectif

La phase de jeu actuelle (`GameUI` + `GameRoot`) présente : un bandeau d'ordre des tours, des libellés
tour/score, une barre d'action multi-boutons en bas, des dés en 3D épinglés en bas-gauche, et les
cartes événement en 3D centrées. Plusieurs éléments **déjà construits ne sont pas utilisés** : la carte
combinée enseigne/statut/destinataire (`ClipCardView`) et les **jetons 3D** drive/destinataire
(`PawnView` mode jeton). Les **livraisons disponibles ne sont pas représentées visuellement**.

Cette refonte réorganise le HUD de partie autour d'un **plateau encadré**, réutilise les composants 3D
existants, et clarifie les actions via un **bouton principal contextuel**. Périmètre : **phase de jeu
uniquement** (la phase de placement `placement_ui` reste inchangée).

## Décisions (issues du brainstorming)

| Sujet | Décision |
|---|---|
| Périmètre | **Phase de jeu** seulement (HUD `GameUI`/`GameRoot`) |
| Rendu | **Hybride** : composants 3D épinglés dans des régions d'écran + cadre/fonds/boutons en `CanvasLayer` 2D |
| Colonne gauche | **Toutes les livraisons** du plateau, une `ClipCardView` chacune, liste **défilable** |
| Drive / destinataire | **Jetons 3D `PawnView` (mode jeton-image)** sur les tuiles (remplace les cartes flottantes) |
| Dés & budget | `DieView` (résultat) + **cubes 3D** = budget de pas restant (retirés un à un) |
| Cartes événement | Rangée basse : **DECK** + **2 emplacements permanents** + **DÉFAUSSE** ; flux « pioche 2 / garde 1 / active » conservé |
| Actions | **1 bouton principal contextuel** (Lancer → Réserver → Fin de tour) + **bouton Pouvoir (⚡)** à côté |
| Zoom | Boutons **＋ / －** déplacés dans la **barre de titre** du cadre (retrait du `ZoomControls` bord droit) ; pinch/scroll trackpad conservés |
| Tour / score / ordre | Regroupés dans la **barre de titre** du cadre (compact) |

## Disposition cible

```
┌─────────────┐   ┌─────────── tour · score · ordre ──────────[＋][－]┐
│ [livraison] │   │                                                   │
│  ◯⟹ 👤 Dispo │   │        PLATEAU 3D (tuiles, routes,                │
├─────────────┤   │        jetons drive ◯ + destinataire 👤)          │
│ [livraison] │   │                                                   │
│  ◯⟹EN COURS │   │   🎲 ▣▣▣   dé (lancer) + cubes (pas restants)     │
│   ⋮ (scroll)│   └───────────────────────────────────────────────────┘
└─────────────┘      ┌────┐      ┌────┐┌────┐      ┌────┐
                     │DECK│      │ c1 ││ c2 │      │DÉF.│
┌──────────────┐     └────┘      └────┘└────┘      └────┘
│  LANCER  [⚡] │
└──────────────┘
```

## Architecture

Découplage conservé : la **logique** (`GamePhase`, `Delivery`, scoring) est inchangée et reste la source
de vérité ; la **vue** réagit par signaux. Le rendu est **hybride** — les composants 3D réutilisés
(`ClipCardView`, `DieView`, `CardView`, jetons `PawnView`) sont des objets 3D positionnés chaque frame
dans des régions d'écran (même technique que les dés/cartes actuels via `_process`), et un `CanvasLayer`
2D dessine le cadre, les fonds d'emplacements, les libellés et les boutons.

### Composants & fichiers

**Nouveau `src/ui/play_hud.gd` (`CanvasLayer`)** — le chrome 2D. Responsabilités :
- Dessine le **cadre fenêtre** autour de la région plateau (barre de titre + bord), expose le `Rect2`
  intérieur (région plateau) et les `Rect2` des régions HUD (colonne gauche, zone dés, emplacements
  cartes) pour que `GameRoot` y positionne les objets 3D.
- Barre de titre : libellé **tour (couleur du joueur) + score**, mini **bandeau d'ordre** des joueurs,
  et boutons **＋ / －** (zoom) à droite.
- Bas-gauche : **bouton principal contextuel** + **bouton Pouvoir (⚡)**.
- Fonds 2D des emplacements DECK / 2 cartes / DÉFAUSSE (libellés « DECK », « DÉFAUSSE »).
- Émet les intentions : `roll_requested`, `reserve_requested`, `end_turn_requested`, `power_requested`,
  `zoom_in_requested`, `zoom_out_requested`.
- API : `set_turn(player)`, `set_score(int)`, `set_action(kind)` (définit le libellé/état du bouton
  contextuel), `set_power_available(bool)`, et des accesseurs de régions (`board_rect()`,
  `left_rect()`, `dice_rect()`, `card_slots_rects()`).
- Remplace l'actuel `GameUI` (libellés tour/score, bandeau d'ordre, barre d'action, panneau de fin).
  Le **panneau de fin de partie** (`show_end`) est repris tel quel dans `play_hud`.

**Nouveau `src/view/delivery_list_view.gd` (`Node3D`)** — la colonne gauche.
- Crée/maintient **une `ClipCardView` par `Delivery`** ; `refresh()` met à jour les statuts.
- Positionne les cartes empilées verticalement dans la région gauche fournie par `play_hud`
  (conversion région écran → monde devant la caméra, même principe que `GameRoot` pour les dés).
- **Défilement** : un offset vertical (molette/drag sur la région gauche) décale la pile ; les cartes
  hors région sont masquées (`visible = false`). Pas de SubViewport (cohérent avec le choix hybride).

**`src/view/clip_card_view.gd`** — petite adaptation : ajouter
`bind_delivery(delivery: Delivery)` qui lit `enseigne`, `destinataire`, `status` du `Delivery` (mêmes
champs que `DeliveryCombo`). Réutilise `_add_card`/`refresh` existants. `bind(combo)` reste pour la démo.

**`src/game/delivery.gd`** — ajouter `is_available() -> bool` (= `status == DISPONIBLE`) pour la vue
(distinct de `is_reservable()` qui exige aussi un destinataire).

**`src/game/game_root.gd`** — adaptations :
- Instancie `play_hud` (au lieu de `GameUI`) et un `DeliveryListView` ; câble les signaux
  `GamePhase` ↔ `play_hud` (tour/score/action/pouvoir) et `play_hud` → actions.
- Remplace `_enseigne_marker`/`_destinataire_marker` (cartes flottantes) par **deux `PawnView` en mode
  jeton** par livraison : jeton drive (texture `enseigne.texture`) sur `drive_cell`, jeton destinataire
  (texture `destinataire.texture`) sur `recipient_cell`. Recyclage du jeton destinataire à la livraison.
- `_process` : positionne la liste gauche, les dés, les cubes et les cartes événement dans les régions
  de `play_hud` (généralise le pinning actuel des dés).
- **Cubes de budget** : un petit `Node3D` portant N cubes (`BoxMesh`) = budget restant ; mis à jour sur
  `movement().step_budget_changed`.
- **Rangée cartes événement** : DECK (pile `CardView` face cachée) + 2 emplacements + DÉFAUSSE, positionnés
  dans les régions de `play_hud`. La logique « pioche 2 / garde 1 / active » de `EventCardChoice` est
  reprise mais rendue dans les 2 emplacements bas (au lieu du centre). `EventCardChoice` est adapté ou
  remplacé par un présentateur logé dans la rangée basse.
- **Bouton contextuel** : `GameRoot` calcule l'action courante et appelle `play_hud.set_action(kind)` :
  `LANCER` (PLANIFICATION) · `RESERVER` (DEPLACEMENT + `reservable_delivery() != null`) ·
  `FIN_TOUR` (sinon, budget épuisé / rien à réserver). Règle anti-blocage : si une tuile est
  réservable, le bouton montre `RESERVER` mais `Fin de tour` reste atteignable (le bouton bascule sur
  `FIN_TOUR` dès qu'on a réservé ou si on ne réserve pas et que le budget est nul → un second appui).

**Zoom** : `ZoomControls` (bord droit) est retiré ; les boutons ＋/－ vivent dans `play_hud`
(barre de titre) et émettent `zoom_in_requested`/`zoom_out_requested`, câblés à `_camera.zoom_in/out`.
`CameraRig` (pinch/scroll/pan trackpad) est inchangé.

### Flux de données

`GamePhase` (signaux existants : `turn_changed`, `subphase_changed`, `pawn_moved`, `delivery_reserved`,
`delivery_in_progress`, `delivery_completed`, `event_triggered`, `game_finished`) → `GameRoot` met à
jour les objets 3D (liste, jetons, dés, cubes, cartes) et appelle l'API de `play_hud` (tour/score/
action/pouvoir). `play_hud` émet les intentions → `GameRoot` → `GamePhase`. Aucune logique de règle
dans la vue.

## Réutilisation explicite (exigence utilisateur)

- `ClipCardView` → colonne gauche (1 par livraison), via `bind_delivery`.
- `PawnView` (mode jeton-image) → jetons drive & destinataire sur les tuiles.
- `DieView` → dé(s) du lancer.
- `CardView` → DECK, 2 emplacements, DÉFAUSSE.

## Tests

- **Logique** inchangée → la suite GUT existante (208) doit rester verte.
- **Unitaires légers ajoutés** : `Delivery.is_available()` ; `ClipCardView.bind_delivery(delivery)`
  (construit bien 2 cartes + insert de statut selon le statut) — testable en `--headless` car
  `ClipCardView` est un `Node3D` instanciable sans scène.
- **Vue/HUD** : validée par import + boot headless (`scenes/main.tscn`) sans erreur + smoke test
  `test_game_root.gd` (un `PawnView` par joueur ; à étendre si besoin pour les jetons de livraison).

## Découpage du plan (pressenti)

1. Cadre fenêtre + relocalisation du zoom (＋/－ en barre de titre, retrait `ZoomControls`).
2. Jetons drive/destinataire (`PawnView`) sur les tuiles (remplacent les cartes flottantes).
3. Colonne gauche : `DeliveryListView` + `ClipCardView.bind_delivery` + `Delivery.is_available()`.
4. Dés + cubes de budget.
5. Rangée cartes événement (DECK / 2 emplacements / DÉFAUSSE), portage de `EventCardChoice`.
6. Bouton contextuel + bouton Pouvoir.
7. Tour/score/ordre dans la barre de titre + retrait de l'ancien `GameUI`.

## Hors périmètre (YAGNI)

- Phase de placement (`placement_ui`) : inchangée.
- Piles DECK/DÉFAUSSE interactives (consultation) : non — ce sont des indicateurs visuels.
- Liste gauche en SubViewport pixel-parfait : écartée au profit du 3D épinglé (perf GL Compatibility /
  mobile / web).
- Menu d'accueil / sélection du nombre de joueurs : inchangé.

## Risques & points d'attention

- **Positionnement écran→monde** des objets 3D dans des régions précises : généraliser proprement le
  calcul déjà fait pour les dés (`_REF_SIZE`, demi-extents ortho, aspect) ; extraire un utilitaire pour
  éviter la duplication entre liste/dés/cubes/cartes.
- **Perf** : jusqu'à 12 `ClipCardView` (chacune plusieurs `MeshInstance3D` + `Label3D`) ; n'instancier
  qu'au changement et masquer les cartes hors zone ; surveiller le coût sur cible modeste.
- **Bridge `ClipCardView` ↔ `Delivery`** : garder la démo (`bind(combo)`) intacte ; `bind_delivery`
  s'appuie sur les champs partagés (enseigne/destinataire/status).
- **Bouton contextuel anti-blocage** : bien gérer le cas « tuile réservable mais le joueur veut finir le
  tour » (le `FIN_TOUR` doit rester atteignable).
- **Retrait de `GameUI`** : repérer tous ses usages (`GameRoot`) et migrer le panneau de fin.
