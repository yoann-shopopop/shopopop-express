# Shopopop Express — Règles du jeu

> **Source de vérité : page Notion « SHOPOPOP Express 2 - LE Retour »**
> (`3732c5c7-9816-8027-bddc-e78f7729d8a5`). Ce fichier en est une copie synchronisée le 2026-06-02.
> En cas de doute, Notion fait foi. Voir aussi la note « Points ouverts » en fin de document.

## Mécanismes du jeu

### Objectif du jeu

Les joueur·euse·s incarnent des cotransporteur·euse·s qui réalisent des livraisons Shopopop. Elles
doivent réussir à accomplir toutes les livraisons de la journée avec le plus de points possible.
Réaliser une livraison sur une tuile de **ta couleur** rapporte davantage de points (voir Scoring).
Chaque joueur·euse n'est représenté·e que par la **couleur de son pion**.

### Plateau de jeu

La zone de jeu se compose de plusieurs plateaux à assembler en début de partie. Chaque plateau
représente un quartier autonome avec ses routes, ses espaces verts et ses zones urbanisées ou
végétalisées.

Les déplacements sont possibles uniquement en utilisant les routes, sauf en cas d'utilisation de
cartes événement spéciales. Deux tuiles ne peuvent être assemblées que si au moins une de leurs routes
touche une route de l'autre.

### Cartes personnage

Chaque joueur·euse reçoit une carte personnage avec des caractéristiques spécifiques :

- un **mode de déplacement** (vélo, à pied, voiture ou camion), qui détermine le nombre de dés ;
- **deux couleurs** de trajet régulier (flavor) ; ⚠️ le **score** se fonde sur **ta couleur de joueur**
  (celle de tes tuiles), pas sur ces deux couleurs ;
- un **super-pouvoir** propre, utilisable une seule fois dans la partie (voir « Les 8 personnages »).

### Drives & Destinataires

Chaque tuile-quartier posée porte **1 drive** (point de retrait, à placer sur une zone grise) et
**1 destinataire** (à placer sur un espace vert) — ce sont des jetons, pas des tuiles séparées. Une
**livraison** relie un drive (case urbaine) à un destinataire (case verte). *Mise à jour 2026-06-15 :
le placement est aléatoire et le drive et le destinataire ne sont pas forcément sur la même tuile.*
Chaque livraison suit un cycle de
statut : **Disponible → Réservé → En cours → Terminé**.

### Mise en place

**Nombre de joueur·euse·s : 2 à 6.** Nombre de tuiles par joueur·euse : jusqu'à 3 joueurs → **3 tuiles**
chacun ; à partir de 4 joueurs → **2 tuiles** chacun. Le total de tuiles posées = le nombre de
livraisons de la partie.

| Joueurs | Tuiles / joueur | Total tuiles = livraisons |
|---|---|---|
| 2 | 3 | 6 |
| 3 | 3 | 9 |
| 4 | 2 | 8 |
| 5 | 2 | 10 |
| 6 | 2 | 12 |

1. Chaque joueur·euse reçoit :
   - une carte personnage ;
   - ses tuiles, à la couleur de son point de départ (symbolisé par une maison rose sur la carte ;
     nombre selon l'effectif) ;
   - autant de jetons drive et de jetons destinataire que de tuiles ;
   - 1 pion permettant d'avancer sur le plateau ;
   - 1 pont.
2. Mélanger et disposer les cartes événement en une pile face cachée.
3. Le ou la premier·ère joueur·euse est la personne qui porte le plus de vêtements noirs.
4. Chaque joueur·euse place tour à tour une tuile sur la surface de jeu.
5. Chaque joueur·euse place un jeton drive et un jeton destinataire par tuile de sa couleur. Les
   destinataires sont à placer dans les espaces verts, les drives sur les zones grises.
6. Former les livraisons en associant chaque drive à un destinataire (autant de livraisons que de
   tuiles posées).
7. Placer les pions de chaque joueur·euse à leur point de départ.

### Déroulement du jeu

Le jeu se déroule en tours jusqu'à ce qu'il n'y ait plus de livraison à effectuer.

1. **Planification** — lancer les dés (selon le mode de transport) pour déterminer le nombre de cases.
   Le ou la premier·ère à jouer est la personne qui porte le plus de vêtements noirs.
2. **Déplacements** — déplacer son pion en suivant les routes. **Pendant** le déplacement :
   - sur la **tuile** d'un drive *disponible*, on peut **réserver** la livraison (statut **Réservé**).
     Un·e joueur·euse mène **au plus 2 livraisons** de front (réservées ou en cours, cumulées) ;
   - arriver sur la **case du drive** d'une livraison qu'on a réservée → elle passe **En cours**
     (automatique) ;
   - arriver sur la **case du destinataire** → elle passe **Terminé** (automatique).
   Réserver, prendre et livrer sont **gratuits** (aucun point de déplacement).
3. **Événements** — si le déplacement passe sur une case arc-en-ciel, le mettre en pause, piocher une
   carte événement, la résoudre, puis reprendre. Penser à utiliser son super-pouvoir au besoin.
4. **Recyclage** — à la livraison, la tuile reçoit un **nouveau destinataire** disponible (roulement) ;
   si le pool de destinataires est épuisé, le drive reste **libre** (plus de livraison à cet endroit).

### Fin de la partie

La partie se termine lorsqu'il n'y a plus de livraison à effectuer.

### Scoring

Une livraison relie un drive (case urbaine) et un destinataire (case verte). **Mise à jour 2026-06-15
(implémentation)** : le placement est désormais **aléatoire** et le drive et le destinataire ne sont
**pas forcément sur la même tuile** (mono- OU bi-tuile). Chaque livraison terminée rapporte **5 points
de base**, plus **+10 points si la tuile du drive est de ta couleur** et **+10 points si la tuile du
destinataire est de ta couleur**.

| Cas | Score |
|---|---|
| Livraison de base | 5 points |
| Tuile du **drive** à ta couleur | +10 points |
| Tuile du **destinataire** à ta couleur | +10 points |

En pratique : **5** (aucune tuile à toi) · **15** (une seule) · **25** (les deux, p. ex. mono-tuile à
ta couleur).

**Bonus et pénalités** : les événements peuvent ajouter des points bonus ou infliger des pénalités.

## Cartes événement

### Avantages

- **Prime Gouvernementale** — les joueur·euse·s à vélo lancent un dé supplémentaire pendant un tour.
- **Faille Spatio-Temporelle** — déplace-toi directement vers n'importe quel autre quartier.
- **Tous les Feux sont au Vert** — rejoue immédiatement ; tu peux réserver une nouvelle livraison.
- **Escorte Policière** — rends-toi directement à ta destination (point de retrait ou destinataire).
- **Évaluation Positive** — avance de 5 cases supplémentaires ce tour-ci ; tu peux réserver une
  nouvelle livraison.
- **Grand Soleil** — avance de 3 cases supplémentaires.
- **Parrainage** — double le résultat de ton lancer de dés pour ce tour ; tu peux réserver une
  nouvelle livraison.
- **Raccourci Secret** — déplace-toi sur n'importe quelle route parallèle à ta position actuelle.
- **5/5** — ajoute 20 points à ton score final.
- **Livraison Écologique** — les joueur·euse·s livrant à vélo doublent les points de chacune de leurs
  livraisons.
- **Voie Verte Prioritaire** — avance de 5 cases supplémentaires si tu utilises un vélo.

### Malus

- **Feu Rouge** — ton tour s'arrête, sauf si tu es à vélo (tu peux continuer).
- **Recharge de Batterie** — recule de 3 cases.
- **Sac Oublié** — retourne immédiatement au point de retrait.
- **Manifestation en Cours** — tu ne lances qu'un seul dé pour tes déplacements jusqu'à ce qu'un·e
  autre joueur·euse passe par ce point.
- **Fuite de Canalisation** — la route est bloquée pour tou·te·s les joueur·euse·s pendant un tour.
- **Pluies Torrentielles** — tous les ponts sont fermés pendant un tour.
- **Pic de Pollution** — la zone à faibles émissions est activée : on ne peut entrer dans ce quartier
  qu'en utilisant un vélo ; ton tour est instantanément terminé.
- **Sac Isotherme Oublié** — retourne immédiatement à ton point de départ.
- **Panne de Véhicule** — ton tour s'arrête immédiatement.
- **Animal sur la Route** — avance de 2 cases de moins que le résultat de ton lancer de dés.
- **Prévention de l'Hyperactivité** — le ou la joueur·euse ciblé·e recule de 3 cases.

## Les 8 personnages (2 par transport)

**Couleurs officielles des quartiers (4)** : 🔴 Rouge · 🟡 Jaune · 🟣 Violet · 🔵 Bleu (le Violet est
validé). Chaque personnage possède 2 de ces couleurs comme trajet régulier.

### 🚲 Vélo

**AXEL·LE** — vélo (1 dé) · 🔴 Rouge · 🟡 Jaune.
Connaît les pistes cyclables comme sa poche et profite de ses trajets pour chercher ses enfants à
l'école, en vélo cargo.
*Pouvoir — Bouclier Vert* : crée un bouclier d'énergie renouvelable qui annule un événement négatif
(carte malus) qui te cible. *Défausse la carte.*

**CAMILLE** — vélo (1 dé) · 🟣 Violet · 🔴 Rouge.
Pédale autant pour livrer que pour croiser du monde ; connaît ses voisins par leur prénom.
*Pouvoir — Habitué·e du Quartier* : sur **une livraison**, encaisse le bonus « trajet régulier » même
si la couleur de la case ne correspond pas à la tienne. *Défausse la carte.*

### 🚶 À pied

**GÉGÉ** — à pied (1 dé) · 🟣 Violet · 🔵 Bleu.
Jeune retraité et ancien facteur, connaît chaque ruelle et raccourci ; livre à pied par tous les temps.
*Pouvoir — Passage Secret* : une seule fois, franchis une case d'eau à pied (un gué, une passerelle).
*Défausse la carte.*

**DOLLY** — à pied (1 dé) · 🔵 Bleu · 🔴 Rouge.
Arpente le quartier pour rejoindre ses copines au bingo et optimise ses trajets en livrant en chemin.
*Pouvoir — Bonne Marcheuse* : ajoute +2 cases à ton déplacement ce tour. *Défausse la carte.*

### 🚗 Voiture

**VIC** — voiture (2 dés) · 🔴 Rouge · 🟣 Violet.
Jongle entre le boulot, les enfants et mille trajets ; toujours efficace.
*Pouvoir — Coup d'Accélérateur* : après ton lancer, relance un des 2 dés. *Défausse la carte.*

**SAM** — voiture (2 dés) · 🟣 Violet · 🟡 Jaune.
Étudiant·e, se rend à ses entraînements de handball et arrondit ses fins de mois en livrant.
*Pouvoir — Dépassement* : échange immédiatement ta case avec celle d'un·e autre joueur·euse de ton
choix. *Défausse la carte.*

### 🚚 Camion

**MARGOT** — camion (2 dés) · 🟡 Jaune · 🔴 Rouge.
A roulé sa bosse dans le déménagement ; les grosses commandes ne lui font pas peur.
*Pouvoir — Chargement Pro* : à un drive, embarque une commande supplémentaire au-delà de ta capacité
de volume pour ce chargement. *Défausse la carte.*

**CHARLIE** — camion (2 dés) · 🟡 Jaune · 🔵 Bleu.
Sillonne la région entre sa ferme et les marchés ; profite de son camion plein pour livrer.
*Pouvoir — Carnet d'Adresses* : une fois dans la partie, quand tu dois piocher une carte événement,
pioche-en 2 et garde celle qui t'arrange (défausse l'autre). *Défausse la carte.*

---

## Points ouverts (observations côté repo, hors règles Notion)

À arbitrer lors des playtests. **Mise à jour finition 2026-06-14** : plusieurs points ont reçu un
**défaut raisonnable codé** (modifiable au playtest) — voir « Arbitrages de finition » dans `CLAUDE.md`.

- **Objectif coopératif vs compétitif** : l'intro évoque un but collectif (« accomplir toutes les
  livraisons »), mais le score est individuel. → **Défaut V1** : coopératif ; l'écran de fin montre le
  **classement individuel + le total collectif** (meilleur·e mis en avant, pas de « perdant »).
- **Capacité de volume** : mentionnée par le pouvoir de Margot mais jamais définie ailleurs. → **Défaut
  V1** : 2 livraisons « en vol » max ; *Chargement Pro* (Margot) donne **+1** (donc 3), conservé.
- **Cohérence super-pouvoir** : la section « Cartes personnage » dit « annuler un événement » alors que
  les 8 pouvoirs sont variés. → Les **8 pouvoirs sont implémentés** tels que décrits (seul *Bouclier
  Vert* annule un malus).
- **Mécanique du pont** : chaque joueur·euse a 1 pont, fermé par *Pluies Torrentielles*, mais son usage
  n'est pas décrit. Recouvre en partie le pouvoir *Passage Secret* de Gégé. → **Encore ouvert** : le
  pont reste *setup-only* ; *Passage Secret* rend l'eau franchissable un tour.
- **Cumul des doublements de points** (*Livraison Écologique*) : effet ponctuel ou persistant ? → **Défaut
  V1** : ponctuel, **non cumulatif** (un seul ×2 par livraison).
- **Placement aléatoire cross-tuile** *(implémenté 2026-06-15)* : **1 drive (case urbaine) + 1
  destinataire (case verte) par tuile** (donc 1 livraison par tuile), puis drives et destinataires
  **appariés au hasard** — le destinataire n'est pas forcément sur la tuile de son drive (mono- ou
  bi-tuile), atteignabilité garantie. Le score 5/15/25 récompense séparément la tuile du drive et celle
  du destinataire (une livraison mono-tuile à ta couleur vaut le max, 25).
- **Variance** : événements « téléportation » (*Faille Spatio-Temporelle*, *Escorte Policière*,
  *Raccourci Secret*) et **5/5 (+20 pts)** très swingy.
- **Mini-effets de destinataire** : le catalogue des destinataires (sous-page Notion « 📦 Les
  Destinataires ») prête à chaque nom une « manie » décorative qui pourrait, plus tard, devenir un
  petit bonus/contrainte à la livraison. Décoratif pour l'instant. La V1 retient **9 destinataires**.

> Contenu d'univers (noms parodiques des destinataires, par familles) : sous-page Notion
> **« 📦 Les Destinataires »**, enfant de la page de règles. Non recopié ici (catalogue d'idées).
