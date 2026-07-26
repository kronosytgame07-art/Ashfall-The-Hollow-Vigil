# 🔥 Ashfall: The Hollow Vigil

Un prototype de jeu de construction de village dans une ambiance **dark fantasy / Dark Souls**, avec une boucle de jeu inspirée de **Clash of Clans** : ressources, bâtiments, minuteurs de construction, et assauts contre d'autres joueurs.

## Jouer

Ouvre simplement `index.html` dans un navigateur — aucune installation requise.

Pour l'héberger en ligne gratuitement via **GitHub Pages** :
1. Pousse ce dépôt sur GitHub.
2. Va dans **Settings → Pages**.
3. Source : branche `main`, dossier `/ (root)`.
4. Ton jeu sera accessible à `https://<ton-user>.github.io/<ton-repo>/`.

## Fonctionnalités

- 🏰 **Village en 3D** (Three.js) : bâtiments modélisés en géométrie procédurale low-poly avec **textures générées par code** (pierre appareillée, bois veiné, tuiles de toit, sol texturé), **ombres portées dynamiques**, portes et fenêtres qui brillent d'une lueur chaude, bannières qui ondulent, décor environnant (rochers, arbres morts, pierres tombales) dispersé autour du village. Chaque bâtiment porte un **sprite d'icône badge en style "chunky cartoon"** (contours noirs épais, couleurs saturées, reflets brillants, badge biseauté à liseré de braise — dessiné entièrement par code) qui flotte au-dessus de lui et reste toujours tourné vers la caméra pour une identification instantanée. Caméra qu'on fait tourner en glissant et zoomer à la molette.
- 🏗️ **Village évolutif** : le Château débloque progressivement de nouvelles parcelles au fil de ses niveaux.
- 🏗️ **Bâtiments multiples** : Mines, Scieries, Casernes, Murailles, Tours peuvent être construites en plusieurs exemplaires (jusqu'à un plafond qui augmente avec le niveau du Château).
- ⏱️ Construction et amélioration avec minuteurs, coûts croissants par niveau **et** par nombre d'exemplaires déjà construits.
- 🪙 Production de ressources (Or, Bois, Âmes) à récolter manuellement (clic sur un bâtiment en 3D).
- ⚔️ **Combat en temps réel avec déploiement de troupes** : tu vois la base ennemie posée devant toi en 3D, tes troupes se déploient et marchent vers les bâtiments, les attaquent un par un (barres de vie visibles), pendant que les Murailles et Tours adverses ripostent. Système d'étoiles (1 à 3) selon le pourcentage de destruction, comme dans Clash of Clans, avec butin et trophées calculés en conséquence.
- 🏗️ **Ouvriers multiples** : une seule construction à la fois par défaut ; le bâtiment "Chantier" débloque un ouvrier supplémentaire (jusqu'à 3), permettant de vraies constructions en parallèle.
- 🎯 **Matchmaking par puissance** : l'adversaire trouvé est choisi parmi plusieurs candidats en fonction de qui a une force de base la plus proche de la tienne, plutôt que purement au hasard.
- 🏆 **Trophées & classement**, 🛡️ **Bouclier** de protection après une attaque.
- 🌐 **Sauvegarde en ligne partagée** via le stockage de l'artefact.
- 🔊 **Ambiance sonore générée en direct** (Web Audio API) : vent, feu de camp, sons de construction/récolte/combat.

## Non inclus dans ce prototype

Pour rester honnête sur le périmètre : il n'y a pas de choix de type de troupe (un seul type générique, dérivé de la puissance totale des Casernes), pas de sorts, pas de héros, pas de laboratoire d'amélioration, pas de clans ni de guerres de clans, pas de campagne solo, pas de vrai serveur de validation (les actions restent calculées côté client — un joueur techniquement averti pourrait modifier ses propres données), pas de tutoriel, pas de doublages ni de musique originale composée. Le déploiement de troupes est automatique (pas de placement manuel au clic) et le pathfinding est en ligne droite, sans contournement des obstacles. Trois.js est chargé depuis un CDN (cdnjs) : une connexion internet est nécessaire au premier chargement.

## Structure

- `index.html` — le jeu complet (HTML/CSS/JS), un seul fichier, sans dépendance de build.
- `assets/buildings/` — les huit sprites WebP des bâtiments.
- `assets/backgrounds/main-menu.webp` — l'illustration optimisée du menu principal.

## Limites connues (prototype)

- Chaque type de bâtiment ne peut être construit qu'une seule fois (simplification volontaire).
- Le combat est résolu en un seul jet, sans animation de bataille détaillée.
- La sauvegarde en ligne dépend du système de stockage fourni par l'environnement d'exécution de l'artefact ; en dehors de cet environnement (ex: GitHub Pages classique), `window.storage` n'existe pas et le jeu bascule automatiquement sur une nouvelle partie locale à chaque session.
