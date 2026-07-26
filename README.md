# 🔥 Ashfall: The Hollow Vigil

Un prototype de jeu de construction de village dans une ambiance **dark fantasy**, avec une boucle de jeu de stratégie mobile : ressources, bâtiments, minuteurs de construction et assauts contre d'autres joueurs.

## Jouer

Ouvre simplement `index.html` dans un navigateur — aucune installation requise.

Pour l'héberger en ligne gratuitement via **GitHub Pages** :
1. Pousse ce dépôt sur GitHub.
2. Va dans **Settings → Pages**.
3. Source : branche `main`, dossier `/ (root)`.
4. Ton jeu sera accessible à `https://<ton-user>.github.io/<ton-repo>/`.

## Fonctionnalités

- 🏰 **Village en 3D hybride** (Three.js) : huit bâtiments illustrés originaux en vue isométrique, silhouettes cartoon premium, palette dark fantasy et effets de braise séparés. Les bâtiments restent statiques tandis que le terrain, les particules, les lumières et les retours de récolte/construction apportent le mouvement.
- 🏗️ **Village évolutif** : le Château débloque progressivement de nouvelles parcelles au fil de ses niveaux.
- 🏗️ **Bâtiments multiples** : Mines, Scieries, Casernes, Murailles, Tours peuvent être construites en plusieurs exemplaires (jusqu'à un plafond qui augmente avec le niveau du Château).
- ⏱️ Construction et amélioration avec minuteurs, coûts croissants par niveau **et** par nombre d'exemplaires déjà construits.
- 🪙 Production de ressources (Or, Bois, Âmes) à récolter manuellement (clic sur un bâtiment en 3D).
- ⚔️ **Mode Assaut** : attaque une base tirée au hasard parmi les autres joueurs connectés, ou un bot si personne n'est disponible.
- 🏆 **Trophées & classement**, 🛡️ **Bouclier** de protection après une attaque.
- 🌐 **Sauvegarde en ligne partagée** via le stockage de l'artefact.
- 🔊 **Ambiance sonore générée en direct** (Web Audio API) : vent, feu de camp, sons de construction/récolte/combat.

## Non inclus dans ce prototype

Pour rester honnête sur le périmètre : ceci est un prototype 3D low-poly stylisé, pas un jeu 3D "final" niveau studio. Concrètement, il n'y a pas de choix de troupes individuelles ni de sorts, pas de carte de combat 3D avec déploiement d'unités (le combat reste résolu par un calcul attaque/défense en un jet, sans scène de bataille visible), pas de clans/guerres de clans, pas de vrais modèles/textures dessinés par un artiste (tout est généré par code : géométries primitives + couleurs). Trois.js est chargé depuis un CDN (cdnjs) : une connexion internet est nécessaire au premier chargement.

## Structure

- `index.html` — le jeu complet (HTML/CSS/JS), sans dépendance de build.
- `assets/buildings/` — les huit sprites de bâtiments détourés.
- `assets/backgrounds/main-menu.png` — l'illustration du menu principal.

## Limites connues (prototype)

- Chaque type de bâtiment ne peut être construit qu'une seule fois (simplification volontaire).
- Le combat est résolu en un seul jet, sans animation de bataille détaillée.
- La sauvegarde en ligne dépend du système de stockage fourni par l'environnement d'exécution de l'artefact ; en dehors de cet environnement (ex: GitHub Pages classique), `window.storage` n'existe pas et le jeu bascule automatiquement sur une nouvelle partie locale à chaque session.
