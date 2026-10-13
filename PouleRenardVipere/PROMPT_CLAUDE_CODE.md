# Texte à coller dans Claude Code (connecté à Roblox Studio et Blender)

> Copie tout ce qui est sous la ligne, et donne-lui le dossier `PouleRenardVipere` (ou le lien GitHub du dépôt `Roblox-game`, branche `claude/charming-brahmagupta-2uzr4t`).

---

Tu travailles sur mon jeu Roblox **Poule Renard Vipère** : 3 équipes, la Poule attrape la Vipère, la Vipère le Renard et le Renard la Poule. Le dossier `PouleRenardVipere/` contient 15 couteaux 3D déjà faits, tirés de mon image `apercu/reference.webp`, avec leurs scripts. **Ne réécris pas les scripts : copie-les EXACTEMENT**, puis fais les vérifications et la finition. Ne supprime rien dans ma place sans me demander. Pas de texte BillboardGui dans la map. Réponds-moi en français, en phrases courtes.

## Étape 1 : Roblox Studio
1. Crée `ReplicatedStorage.Couteaux` (Folder). Dedans, crée les ModuleScripts `Config` (contenu exact de `roblox/Config.lua`) et `FX` (contenu exact de `roblox/FX.lua`).
2. Importe les 15 fichiers `modeles/*.glb` avec l'Importer 3D, options par défaut. Chaque couteau doit donner 2 MeshParts, `<Id>_Body_tex` (texturé) et `<Id>_Outline_outline` (contour noir). Vérifie que la texture est bien appliquée. Sinon, mets `modeles/textures/<Id>.png` comme TextureID de `<Id>_Body_tex`.
3. Exécute le contenu de `roblox/InstallerCouteaux.lua` dans la barre de commandes. La sortie doit afficher « 15 couteau(x) installé(s) ». Les Tools sont dans `ReplicatedStorage.Couteaux.Outils`.
4. Crée le Script `ServerScriptService.CouteauxServeur` (contenu exact de `roblox/CouteauxServeur.lua`) et le LocalScript `StarterPlayer.StarterPlayerScripts.CouteauxClient` (contenu exact de `roblox/CouteauxClient.lua`).
5. **Branche sur le jeu existant** :
   - Regarde comment le jeu gère déjà les équipes, la prison et les armes.
   - `Config.EquipeDe` doit renvoyer `"Poules"`, `"Renards"` ou `"Vipères"`. Adapte-la si les Teams ont d'autres noms.
   - Connecte `ServerStorage.CouteauxEvents.Touche.Event` (attaquant, victime, idCouteau) à la mise en prison existante.
   - Si le jeu donne déjà une arme, mets `Config.Combat.DonnerCouteau = false` et donne les Tools de `Outils`.
   - Le jeu doit mettre l'attribut `EnPrison` (Player) à `true` pendant la prison.
   - S'il existe déjà un système d'attaque ou d'esquive, ne le duplique pas : dis-moi lequel garder.

## Étape 2 : Test en Play (Test > Serveur local, 2 ou 3 joueurs)
- La main tient le milieu du manche. Sinon, règle la rotation dans `Config.Grip`, tranchant vers l'avant.
- Le couteau ressemble à l'image de référence, avec le contour noir visible mais pas trop épais.
- Le combo 1-2-3 marche. La traînée colorée suit la lame. L'impact est propre à chaque couteau : éclairs (électrique), plumes, flammes, origami, poison, onde (géant).
- On ne touche que l'équipe qu'on chasse. L'esquive (Q / B / bouton mobile) rend invincible.
- Il n'y a aucune erreur dans la sortie.
- Si un son intégré ne joue pas, remplace-le dans `Config.Sons` par un son de la Boîte à outils.

## Étape 3 : Finition dans Blender (si je te le demande)
- Importe un `.glb` (Fichier > Importer > glTF). Le couteau est un maillage « gonflé » à partir de la silhouette, avec l'image en texture recto/verso.
- Tu peux : lisser les bords, épaissir une garde, retoucher la texture (`modeles/textures/<Id>.png`), ou ajouter du relief aux emblèmes.
- Garde les noms d'objets, une seule texture par objet et moins de 20 000 triangles. Lame vers +Z, 1 unité = 1 stud.
- Réexporte en glTF 2.0 (.glb), +Y Up.

Quand tout marche, dis-moi ce que tu as changé et publie (Alt+P) seulement si je te le demande.
