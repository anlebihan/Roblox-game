# CLAUDE.md — Poule Renard Vipère (Roblox)

Mémoire du projet pour les prochaines sessions avec Claude. À lire avant toute modification.

## Le projet
- **Jeu** : Poule Renard Vipère — épervier / chat en 3 équipes, inspiré de Huss Valley. Le Renard attrape la Poule, la Poule attrape la Vipère, la Vipère attrape le Renard.
- Coup de couteau = capture -> prison dans le camp de l'équipe qui a attrapé. Un coéquipier libre délivre en touchant le prisonnier. On est protégé dans son propre camp (zone sûre). La dernière équipe libre gagne (manche de 3 min, sinon l'équipe avec le plus de joueurs libres).
- Des bots complètent les équipes (3 par équipe minimum).
- **Propriétaire** : Antonin (YouX_X85), débutant, clavier AZERTY, parle français. Réponses courtes, en français ; agir directement dans Studio plutôt que donner du code.
- **Studio** : place « Poule Renard Vipère », placeId `117262292231485` (Team Create : les changements sont gardés, mais il faut publier pour les joueurs).

## Règles de l'utilisateur
- Ne rien supprimer sans lui demander : ce qui est remplacé est rangé dans `ServerStorage.OldDecor` ou désactivé par un drapeau.
- Ne jamais publier (jeu ou animations) sans son accord. Lui rappeler : Fichier > Publier sur Roblox.
- Pas de texte BillboardGui dans la map (les infos passent par le HUD ou les ProximityPrompts).
- Scripts fournis par lui (dossier `PouleRenardVipere/roblox` du dépôt GitHub `anlebihan/Roblox-game`, branche `claude/charming-brahmagupta-2uzr4t`) : les copier EXACTEMENT, ne brancher le jeu qu'autour.
- Tester en Play après chaque grosse modif et regarder la sortie.

## Architecture (tout est dans la place Studio)
| Script | Rôle |
|---|---|
| `ServerScriptService.GameManager` | Manches, équipes, prison, libérations, récompenses, bots. `giveKnife` donne les **nouveaux couteaux 3D** (`ReplicatedStorage.Couteaux.Outils`, table `NOUVEAU` : ancien id boutique -> id 3D). Écoute `ServerStorage.CouteauxEvents.Touche` -> `capture`. Gère aussi les coups des joueurs sur les **bots** (CouteauxServeur ne vise que les vrais joueurs). Met `EnPrison` (Player) et `Invincible` (Character, zone sûre / immunité). |
| `ServerScriptService.DataService` | Sauvegarde (`PRV_Joueurs_v1`), pièces, XP, couteaux possédés/équipés, caisses, cadeau du jour, quêtes du jour. |
| `ServerScriptService.Bots` | IA des bots (fuir, chasser, délivrer). Les bots attaquent par l'ancien `tryAttack`. |
| `ServerScriptService.LobbyService` | Couteaux géants qui tournent sur les 3 podiums (modèles `Showcase` = PouleRoyal, RenardLegendaire, ViperRoyal), panneau de statut, classement. |
| `ServerScriptService.CouteauxServeur` | (fourni par Antonin) vérifie les coups (combo 1-2-3), esquive = invincibilité, déclenche `Touche`. |
| `ReplicatedStorage.Couteaux` | (fourni) `Config` (seul changement : `Combat.DonnerCouteau = false`), `FX`, `Outils` (15 Tools), `Animations` (8 KeyframeSequence), `Remotes`. |
| `ReplicatedStorage.PRV.KnifeData` | Catalogue boutique/caisses (ids `Poules_Plume`…), raretés, prix, **images = icônes des nouveaux couteaux**. |
| `ReplicatedStorage.PRV.VFX` / `AnimData` | Anciens effets Blender (coups, impacts, esquive) / anciennes animations Blender. Encore utilisés pour les bots et les captures. |
| `StarterPlayerScripts.CouteauxClient` | (fourni) combo, esquive (touche Q = **A en AZERTY**, B manette, bouton mobile), animations, effets. |
| `StarterPlayerScripts.ClientMain` | Mouvement (élan, glissade), shift lock forcé en manche, bouton FRAPPER mobile. Ancienne esquive désactivée (`ANCIENNE_ESQUIVE = false`). |
| `StarterPlayerScripts.CombatFX` | Anciennes animations/effets ; ignore les Tools qui ont l'attribut `CouteauId`. |
| `StarterPlayerScripts.HUD` / `Progression` / `Vent` / `Coffres` | Interface façon Huss Valley, niveau/fin de manche/musique, arbres qui bougent, coffres du lobby. |

## Animations des couteaux
- Marchent en Play dans Studio sans ID (KeyframeSequenceProvider). **Pour le jeu publié, il faut les publier** (Éditeur d'animation > Rig > Charger > Publier) puis mettre les IDs dans `Config.Animations` — seulement avec l'accord d'Antonin. Le Rig R15 « Rig » est dans le Workspace (en hauteur, y = 300).

## Fichiers sur le PC
- `Documents/PouleRenardVipere/` : fichiers Blender (map, animations `PRV_Animations.blend`), scripts Python Blender, `Vignettes/` (textures, icônes, serveur HTTP local de Blender sur le port 8765 pour passer des fichiers à Studio).
- `Vignettes/Couteaux/` : les 15 .glb, les scripts fournis, les icônes `icon_<Id>.png`.

## À faire / attention
- Publier les 8 animations (avec accord), puis les IDs dans `Config.Animations`.
- Tester à 2-3 joueurs (Test > Serveur local).
- La barre « Esquive prête » du HUD ne suit pas la nouvelle esquive ; F (inspecter) n'a plus d'effet.
- Ranger `Workspace.Scene` (modèles importés vides) et le Rig avec l'accord d'Antonin.
- Le PC d'Antonin est lent (Studio parfois à ~10 images/s) : ne pas ouvrir d'autres fenêtres Studio/Blender (ne pas utiliser « ouvrir l'application » pour Studio, ça en relance une nouvelle).
