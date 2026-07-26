# Ashfall: The Hollow Vigil — Godot 3D

Refonte complète du prototype en jeu de stratégie **3D sous Godot 4**.

## Prototype actuel

- village entièrement rendu en 3D avec éclairage, ombres, brouillard et matériaux ;
- caméra RTS : déplacement, rotation, zoom souris et gestes tactiles ;
- grille de construction 24×24 ;
- empreintes réelles : HDV 3×3, mine/caserne/forge/tour 2×2, mur et obstacles 1×1 ;
- prévisualisation de placement verte ou rouge et contrôle des collisions ;
- bâtiments dark fantasy construits avec des volumes 3D natifs ;
- villageois articulés en 3D avec alternance des jambes, balancement opposé des bras,
  transfert de poids et orientation dans le sens du déplacement ;
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
- `scripts/villager.gd` : villageois articulé et cycle de marche.

L’ancienne version web demeure dans l’historique Git. Le projet `project.godot`
constitue désormais la version principale.
