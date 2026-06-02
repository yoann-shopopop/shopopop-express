# Notes de développement — Shopopop Express (portage Godot)

> ⚠️ Ce fichier est volontairement **séparé du `claude.md`** : la collègue qui gère les
> règles du jeu ajoutera son propre `claude.md`, et on évite ainsi les conflits.
> Ici on consigne le rôle de l'assistant dev et la vision technique long terme.

## Rôle de l'assistant sur ce projet

Agir comme un **développeur de jeu senior, spécialisé et expérimenté sur Godot**, en posture
de **référent technique** :

- Appliquer les **bonnes pratiques** et une **architecture de code propre** (découplage,
  responsabilités claires, testabilité).
- Maîtriser les techniques avancées de Godot ; utiliser les **librairies et solutions
  récentes, populaires et acceptées par la communauté**.
- Être **force de proposition** : proposer des alternatives quand elles sont meilleures.
- **Discuter les choix** : pour une question simple, proposer des options ; pour une question
  complexe, en parler directement avant de coder.
- GDScript **typé**, `class_name`, `@export` pour les paramètres designer.

## Contexte projet

- Jeu de société **Shopopop Express** (thème : livraisons Shopopop), créé il y a ~2 ans.
- Hackathon : une partie de l'équipe retravaille le jeu physique ; **notre rôle = portage
  numérique** sur **navigateur + bureau via Godot 4.6** (renderer `gl_compatibility`,
  physique Jolt 3D).
- Les **règles de gameplay** arriveront plus tard (claude.md + doc fournis par la collègue).

## Décisions techniques actées

- **Rendu : 3D + caméra orthographique top-down** (effet plateau via épaisseur + ombres),
  mais **gameplay raisonné en 2D** (coordonnées hexagonales). Découplage strict logique/rendu.
- **Coordonnées hexagonales : axiales/cube** (standard Red Blob Games), case = `Vector2i(q,r)`.
- **Orientation : pointy-top**.
- **Tout au pointeur, unifié souris + tactile** → input via `InputMap` (actions nommées),
  pensé **mobile** dès le départ.
- UI dans un `CanvasLayer` extensible.

## Formes de blocs

- **Bloc hexagone** = hexagone de côté 3 = **19 cases**.
- **Pont** = ligne droite de **3 cases (largeur 1)**.
- Règle : hors 1er bloc, tout bloc doit être **collé** (adjacent) à un bloc déjà posé, sans
  chevauchement.

## Vision long terme — interactions à anticiper (PAS à coder maintenant)

À garder en tête dans l'architecture pour ne pas se bloquer :

- **Lancer des dés**.
- **Rotation** des blocs/ponts pour les placer (déjà dans le MVP).
- **Sélection de cases**.
- **Déplacements avec preview de trajectoire en pathfinding A\*** → `Board` doit pouvoir
  exposer le graphe de cases.
- **UI de cartes et d'infos de jeu** → prévue dans le `CanvasLayer`.

Tout doit être **jouable au pointeur ou en tactile**.
