# Lancer le projet & les tests

> Godot utilisé : **4.6.3 stable**. Remplace `<godot>` par le chemin de ton exécutable
> (ex. `C:\Users\<toi>\Downloads\Godot_v4.6.3-stable_win64.exe`).

## Jouer la scène
Ouvre le projet dans l'éditeur Godot et lance (F5), ou en ligne de commande :
```
<godot> --path .
```
La scène principale est `res://scenes/main.tscn`.

**Contrôles (souris) :** la souris déplace le bloc fantôme, **clic gauche** pose, **R** ou le
bouton *Rotation* tourne, les boutons *Hexagone* / *Pont* changent de bloc, molette = zoom,
clic droit glissé = pan. (Tactile : tap = pose, deux doigts = zoom/pan — pensé mobile.)

## Tests unitaires (GUT)
La logique pure (`HexUtils`, `BlockDefinition`, `Board`) est couverte par GUT.

⚠️ Après avoir ajouté un **nouveau `class_name`**, lance d'abord un import (séparément) pour
l'enregistrer, puis les tests :
```
<godot> --headless --path . --import
<godot> --headless --path . -s res://addons/gut/gut_cmdln.gd
```
Config GUT : `.gutconfig.json` (scanne `res://tests/`).

## Régénérer les ressources de blocs
Les `.tres` des blocs sont générés depuis les helpers de forme :
```
<godot> --headless --path . -s res://tools/generate_block_resources.gd
```

## Capture d'aperçu (smoke test visuel)
Pose quelques blocs et sauve `user://board_preview.png` (à lancer **en fenêtré**, pas headless) :
```
<godot> --path . -s res://tools/capture_preview.gd
```

## Soak de fiabilité (anti-softlock)
Auto-assemble un plateau et auto-pilote des parties **2→6 joueurs** jusqu'à la fin ; échoue (code 1)
si une partie se bloque. À lancer en headless :
```
<godot> --headless --path . -s res://tools/soak_test.gd
```

## Captures d'écran du jeu (avant/après polish)
Rend le **vrai** jeu (plateau + HUD), joue quelques tours et sauve des PNG (**fenêtré**) :
```
<godot> --path . -s res://tools/capture_play.gd -- <dossier> <seed> <joueurs>
# ex. : ... -- captures 4 4   → captures/01_plateau.png, 02_apres_lancer, 03_deplacement, 04_fin, 05_personnages
```

## Régénérer l'audio
Synthétise les SFX + la boucle d'ambiance dans `assets/audio/` (aucune dépendance externe) :
```
<godot> --headless --path . -s res://tools/generate_audio.gd
```
