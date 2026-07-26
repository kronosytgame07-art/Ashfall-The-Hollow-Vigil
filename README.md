# Ashfall: The Hollow Vigil — Godot 3D

Refonte complète du prototype en jeu de stratégie **3D sous Godot 4**.

## Prototype actuel

- village entièrement rendu en 3D avec éclairage, ombres, brouillard et matériaux ;
- caméra RTS : déplacement, rotation, zoom souris et gestes tactiles ;
- grille de construction 24×24 ;
- empreintes réelles : HDV 3×3, mine/caserne/forge/tour 2×2, mur et obstacles 1×1 ;
- prévisualisation de placement verte ou rouge et contrôle des collisions ;
- douze bâtiments dark fantasy construits avec des volumes 3D natifs :
  HDV, mine, scierie, caserne, camp, autel, forge, tour, laboratoire,
  salle des sorts, chantier et mur ;
- villageois articulés en 3D avec hanches, genoux, épaules et coudes indépendants ;
- locomotion omnidirectionnelle continue, accélération, freinage, séparation des
  unités, adaptation de la foulée à la vitesse et animation de travail ;
- guerrier, archer, brute et héros entièrement en 3D avec locomotion et attaque ;
- rochers, arbres morts, ossements et cristaux corrompus entièrement en 3D ;
- collisions physiques entre unités, bâtiments et obstacles ;
- configuration d’export Windows et Android.

## Ouvrir le projet

1. Installer **Godot 4.3 ou plus récent**.
2. Dans le gestionnaire de projets, choisir **Importer**.
3. Sélectionner `project.godot`.
4. Lancer avec `F6` ou `F5`.

## Contrôles

| Action | Ordinateur | Mobile |
|---|---|---|
| Déplacer la caméra | clic droit/milieu ou WASD | glisser |
| Zoomer | molette | pincer |
| Rotation | Q / E | à venir |
| Placer un bâtiment | clic gauche | toucher |
| Annuler le placement | Échap | bouton à venir |

## Architecture

- `scenes/main.tscn` : scène principale ;
- `scripts/game.gd` : grille, placement, environnement et interface ;
- `scripts/rts_camera.gd` : caméra de stratégie multi-support ;
- `scripts/building_factory.gd` : modèles 3D procéduraux et empreintes ;
- `scripts/villager.gd` : villageois articulé, locomotion dans toutes les directions
  et animation de travail ;
- `scripts/combat_unit.gd` : troupes 3D, déplacements et attaques.

## Direction technique

Le runtime Godot n’utilise aucun sprite pour représenter le village, les bâtiments,
les obstacles ou les unités. Chaque élément visible du jeu est un vrai objet 3D
éclairé, projetant une ombre et observable sous tous les angles. Le système conserve
un secteur logique à huit directions pour les futurs équipements, tout en faisant
tourner les modèles de façon continue afin d’éviter les changements de direction
brutaux des anciennes animations 2D.

L’ancienne version web demeure dans l’historique Git. Le projet `project.godot`
constitue désormais la version principale.
