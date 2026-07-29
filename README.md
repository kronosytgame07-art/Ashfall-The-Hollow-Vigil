# Ashfall — Le Creux des Cendres

Prototype Godot 4 d’un futur MMORPG cubique dark fantasy. Le projet ne suit plus
une boucle de construction de village : la scène principale est désormais un
action-RPG à la troisième personne centré sur l’exploration, le combat exigeant
et la progression dans un monde ouvert.

## Prototype jouable

- personnage cubique équipé d’une armure, d’une épée et d’un bouclier ;
- choix entre Humain, Orque, Gobelin et Nain avant l’entrée dans le monde ;
- caméra libre à la troisième personne ;
- déplacement, course, endurance, attaque directionnelle et esquive avec
  invulnérabilité temporaire ;
- santé, mort et retour au dernier brasier ;
- ennemis de niveaux différents avec détection, poursuite, attaque et récompense
  en âmes ;
- zone centrale adaptée au niveau 1 ;
- frontières vers une région volcanique et une région enneigée contenant des
  adversaires nettement plus dangereux ;
- ruines, chapelle brisée, arbres morts, falaises et matériaux cubiques texturés ;
- interface dark fantasy et menu de sélection du personnage.

## Contrôles

| Action | Commande |
|---|---|
| Déplacement | ZQSD / WASD |
| Caméra | Souris |
| Attaque | Clic gauche / F |
| Esquive | Espace |
| Course | Maj |
| Repos au brasier | E |
| Libérer la souris | Échap |

## Architecture active

- `scenes/main.tscn` : nouvelle scène principale action-RPG ;
- `scripts/souls_world.gd` : monde cubique, biomes, ruines, brasier et interface ;
- `scripts/souls_player.gd` : personnage, caméra, combat, endurance et races ;
- `scripts/souls_enemy.gd` : IA, niveaux, dégâts et récompenses.

Les anciens systèmes de stratégie restent temporairement dans le dépôt pour
faciliter la migration des assets, mais ils ne sont plus chargés par la scène
principale.

## Direction à développer

La suite prévoit de grandes régions séparées, la progression par équipement et
compétences, les métiers et PNJ, un cycle jour/nuit, le vol et le crochetage, les
quêtes, les donjons, les boss, puis une couche réseau autoritaire pour la
coopération et le PvP. Ces systèmes seront ajoutés sur la nouvelle base
action-RPG, et non greffés sur l’ancien village.

## Lancer le projet

1. Installer Godot 4.3 ou une version ultérieure.
2. Importer `project.godot`.
3. Lancer la scène principale avec `F6` ou le projet avec `F5`.
