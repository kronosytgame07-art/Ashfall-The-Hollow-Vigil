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

- 🗺️ **Dimensions officielles Clash of Clans** : carte de 44×44 cases jouables (1936 cases), sol en véritable quadrillage aligné case par case, bordure de **montagnes, rochers et arbres morts** tout autour, caméra à l'angle diamant classique. Les milliers de cases vides sont rendues via une seule géométrie instanciée (`InstancedMesh`) pour rester fluide malgré la taille de la carte.
- 📐 **Emprise au sol variable** : le Château occupe un bloc de 3×3 cases, la Salle des Sorts/le Laboratoire/la Caserne/la Tour occupent 2×2, les autres bâtiments (Mine, Scierie, Autel, Forge, Chantier, Muraille) tiennent sur 1×1 — chaque bâtiment a une taille visuelle et un poids stratégique cohérents avec son importance, comme dans Clash of Clans. Le jeu vérifie automatiquement qu'il y a assez de place libre avant de proposer une construction.
- 🏰 **Village en 3D** (Three.js) : bâtiments modélisés en géométrie procédurale low-poly avec **textures générées par code** (pierre appareillée, bois veiné, tuiles de toit, sol texturé), **ombres portées dynamiques**, portes et fenêtres qui brillent d'une lueur chaude, bannières qui ondulent. Chaque bâtiment porte un **sprite d'icône badge en style "chunky cartoon"** (contours noirs épais, couleurs saturées, reflets brillants, badge biseauté à liseré de braise — dessiné entièrement par code) qui flotte au-dessus de lui et reste toujours tourné vers la caméra pour une identification instantanée. Caméra qu'on fait tourner en glissant et zoomer à la molette.
- 🏗️ **Village évolutif** : le Château débloque progressivement de nouvelles parcelles au fil de ses niveaux.
- 🏗️ **Bâtiments multiples** : Mines, Scieries, Casernes, Murailles, Tours peuvent être construites en plusieurs exemplaires (jusqu'à un plafond qui augmente avec le niveau du Château).
- ⏱️ Construction et amélioration avec minuteurs, coûts croissants par niveau **et** par nombre d'exemplaires déjà construits.
- 🪙 Production de ressources (Or, Bois, Âmes) à récolter manuellement (clic sur un bâtiment en 3D).
- ⚔️ **Combat en temps réel avec déploiement de troupes** : tu vois la base ennemie posée devant toi en 3D, tes troupes marchent vers les bâtiments, les attaquent un par un (barres de vie visibles), pendant que les Murailles et Tours adverses ripostent. Système d'étoiles (1 à 3) selon le pourcentage de destruction, comme dans Clash of Clans, avec butin et trophées calculés en conséquence.
- 🚫 **Zone anti-déploiement réaliste** : chaque bâtiment génère un halo interdit au déploiement (fusionné avec ceux des bâtiments voisins), avec la vraie règle du "trou" — un écart de 2 cases ou plus entre deux structures laisse un passage vert où l'ennemi peut légitimement débarquer. La bordure de 3 cases tout autour de la carte reste, elle, toujours libre au déploiement.
- 🔎 **Phase de repérage (30s)** avant le combat : les zones interdites s'affichent en rouge, les zones libres en vert clair. Ton héros se déploie automatiquement ; à toi de choisir où poser tes troupes (Guerrier/Archer/Brute, un clic = une troupe) en visant les trous dans la défense. Dès ta première troupe posée, la teinte rouge disparaît et le combat démarre (comme dans le vrai jeu). Le funneling (concentrer les troupes vers le centre en perçant les côtés) est donc une vraie stratégie possible, pas juste subie.
- 🗡️ **Trois types de troupes** (Guerrier, Archer, Brute) avec leurs propres stats (vie, dégâts, vitesse, portée), et **trois compositions au choix** avant l'assaut (Équilibrée, Assaut rapide, Mur de boucliers).
- 👑 **Un héros** — le Roi des Cendres, débloqué au Château niveau 2 — combat automatiquement à chaque assaut et soigne périodiquement les troupes proches.
- 🔥✨ **Sorts de combat** : Rage (dégâts des troupes +60% pendant 6s) et Soin (soigne 50% des PV), lançables pendant la bataille grâce aux charges fournies par la **Salle des Sorts**.
- 🧪 **Laboratoire** : bâtiment qui augmente la puissance globale des troupes (dégâts) à chaque niveau.
- 🏅 **Hauts faits** : 10 objectifs de progression (premiers bâtiments, niveaux de Château, victoires, trophées, récoltes...) avec récompenses automatiques en ressources, dans un onglet dédié.
- 🏗️ **Ouvriers multiples** : une seule construction à la fois par défaut ; le bâtiment "Chantier" débloque un ouvrier supplémentaire (jusqu'à 3), permettant de vraies constructions en parallèle.
- 🎯 **Matchmaking par puissance** : l'adversaire trouvé est choisi parmi plusieurs candidats en fonction de qui a une force de base la plus proche de la tienne, plutôt que purement au hasard.
- 📖 **Tutoriel de bienvenue** affiché à la première visite, avec les bases du jeu.
- 🏆 **Trophées & classement**, 🛡️ **Bouclier** de protection après une attaque.
- 🌐 **Sauvegarde en ligne partagée** via le stockage de l'artefact.
- 🔊 **Ambiance sonore générée en direct** (Web Audio API) : vent, feu de camp, sons de construction/récolte/combat.

## Non inclus dans ce prototype

Pour rester honnête sur le périmètre : pas de clans ni de guerres de clans, pas de campagne solo, pas de vrai serveur de validation (les actions restent calculées côté client — un joueur techniquement averti pourrait modifier ses propres données), pas de doublages ni de musique composée par un vrai musicien (la boucle mélodique est générée par code). Le pathfinding des troupes reste en ligne droite (pas de contournement des obstacles). Pas de pièges ni de décorations achetables dans les bases ennemies (donc pas d'exception "pièges sans volume" ou "décor traversable" à gérer). Toutes les troupes ciblent le bâtiment le plus proche, quel qu'il soit — pas de comportement "cible uniquement les défenses" façon Ballon/Chevaucheur de cochon. Trois.js est chargé depuis un CDN (cdnjs) : une connexion internet est nécessaire au premier chargement.

## Structure

- `index.html` — le jeu complet (HTML/CSS/JS), un seul fichier, sans dépendance de build.

## Limites connues (prototype)

- La sauvegarde en ligne dépend du système de stockage fourni par l'environnement d'exécution de l'artefact ; en dehors de cet environnement (ex: GitHub Pages classique), `window.storage` n'existe pas et le jeu bascule automatiquement sur une nouvelle partie locale à chaque session.
