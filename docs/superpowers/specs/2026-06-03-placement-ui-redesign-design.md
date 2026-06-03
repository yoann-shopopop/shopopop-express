# Refonte visuelle de l'UI — Phase de placement

**Date :** 2026-06-03
**Branche :** `feat/tile-textures-and-placement-ux`
**Statut :** Spec validée — en attente de plan d'implémentation

## Objectif

Retravailler **uniquement l'habillage visuel** de l'UI de la phase de placement (`PlacementUI`)
pour coller à une maquette fournie, sans **aucun** impact sur le gameplay ni sur les comportements
d'interaction joueur. La grille hexagonale, les tuiles, le ghost, le magnet et toute la logique
(`SetupPhase`, `Board`, `PlacementController`) restent **strictement inchangés** dans leur
fonctionnement.

Contrainte de plateforme : Godot 4.6, renderer **GL Compatibility** (cible mobile/web). Toute l'UI
est en 2D (`CanvasLayer`) ; `StyleBoxFlat`, `NinePatchRect` et `GradientTexture2D` y sont compatibles.

## Style retenu : « C — Intermédiaire »

Esprit « jeu de plateau » de la maquette sans skeuomorphisme complet :
- dégradé vertical (via `GradientTexture2D`),
- léger reflet en haut (bordure interne claire),
- bordure colorée,
- ombre douce,
- coins arrondis.

Centralisé dans un helper de thème réutilisable, donc facile à régler.

## Approche technique

On conserve le pattern existant (**UI construite en code**, aucune `.tscn` d'UI).

- **Nouveau** `src/ui/ui_theme.gd` (`class_name UITheme`, statique) : fabrique les styles du style C —
  `StyleBoxFlat` (coins arrondis, bordures, ombres) et `GradientTexture2D` pour les dégradés
  verticaux. Expose des constructeurs paramétrés par couleur (ex. `button_style(base_color)`),
  pour produire les variantes orange / rouge / bleu de la barre d'outils et le bouton Valider.
- **Réorganisation** de `src/ui/placement_ui.gd` pour reproduire le layout de la maquette, en
  appliquant les styles de `UITheme`. Les **signaux émis et la surface publique restent identiques**
  (`set_current_player`, `update_controls`, `set_finished`, `begin_game`, et les signaux
  `piece_drag_started` / `bridge_drag_started` / `finish_requested` / `rotate_requested` /
  `rotate_left_requested` / `rotate_right_requested` / `remove_requested`). Le câblage dans
  `main.gd` reste donc inchangé, hormis l'ajout du calcul du numéro de tour (voir plus bas).

## Layout (maquette → Godot)

De haut en bas :

1. **En-tête (haut-centre)** — bandeau-pilule dégradé foncé arrondi :
   `PHASE DE PLACEMENT | Équipe Bleue · Tour X/Y`. Sous-ligne fine : `J1 : Équipe Bleue`
   (petite icône joueur, **sans horloge / minuteur**).
2. **Barre d'outils flottante** — **inchangée fonctionnellement** : flotte au-dessus de la pièce
   posée via `update_controls(shown, screen_pos)`. Restylée style C et **recolorée** :
   ⟲ orange · ✕ rouge · ⟳ bleu, boutons un peu plus grands, relief léger.
3. **Plateau** — strictement inchangé.
4. **Label `19 Hex`** — petit label centré au-dessus du tray (statique : taille d'une tuile).
5. **Tray (bas-centre)** — rangée de previews de tuiles, chacune avec un libellé `Block 1`,
   `Block 2`… (et `Pont` si le pont reste). La tuile sélectionnée porte une bordure colorée mise
   en avant (sélection actuelle conservée). **Pas de flèches de défilement.**
6. **Bouton rotation du tray (`rotate_requested`)** — conservé pour préserver le tactile, mais
   **affiché uniquement pendant un glissement** (discret, près du tray).
7. **`VALIDER LE PLACEMENT` (bas-droite)** — l'actuel `finish_requested`, gros bouton bleu,
   **activé seulement une fois un bloc posé** (comportement actuel).
8. **Bas-gauche** — vide (avatar de profil **omis**).

## Éléments de la maquette explicitement écartés

- **Minuteur `01:28`** : omis (aucune limite de temps dans le jeu ; un minuteur fonctionnel serait
  un changement de gameplay).
- **Avatar de profil** (bas-gauche) : omis.
- **Flèches ‹ › du tray** : omises.

## Dérivation du numéro de tour (`Tour X/Y`) — sans toucher à la logique

- `Y` = nombre de tuiles initial du joueur, **capturé côté vue** au démarrage de la partie dans
  `main.gd` (après `SetupDistributor.build_players`, avant toute pose), p. ex. dans un
  `Dictionary` indexé par joueur ou un tableau parallèle.
- `X` = `Y - pieces.size() + (block_placé_ce_tour ? 0 : 1)`, calculé à l'affichage.
  - Vérif : tour 1, 3 pièces, rien de posé → `3 - 3 + 1 = 1` ✓ ; après pose (2 pièces restantes,
    bloc posé) → `3 - 2 + 0 = 1` ✓.
- `PlacementUI.set_current_player` reçoit en plus `turn_index: int` et `turn_total: int`
  (paramètres d'affichage). `SetupPhase` et `Player` ne sont **pas** modifiés.

## Fond (environnement 3D)

Remplacer l'actuel fond sombre (`1b2330`) par un **dégradé clair et aéré** (bleu-gris vertical)
façon maquette, posé derrière le plateau (soit via la couleur/sky de `WorldEnvironment`, soit via un
`TextureRect` plein écran sur un `CanvasLayer` de fond avec un `GradientTexture2D`). Pas d'image de
ville fabriquée ; un visuel de ville flouté fourni ultérieurement pourra être substitué sans refonte.

## Écran de départ (« Nombre de joueurs »)

Layout identique, mais on lui applique **le même thème** `UITheme` pour la cohérence visuelle.

## Tests

La logique (`SetupPhase`, `Board`, etc.) n'est pas touchée → les tests GUT existants doivent
continuer à passer sans modification. La refonte étant purement visuelle (Node/rendu), elle n'est
pas couverte par des tests unitaires ; validation visuelle dans l'éditeur Godot. Lancer la suite GUT
pour confirmer l'absence de régression :

```
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

## Hors périmètre

- Toute modification de la logique de jeu ou des comportements d'interaction.
- Une vraie image de fond « ville » (faute d'asset).
- La refonte de l'UI de jeu (`game_ui.gd`) post-setup.
