# Texte à coller dans Claude Code (connecté à Roblox Studio et Blender)

> Copie tout ce qui est sous la ligne, et donne-lui le dossier `PouleRenardVipere` (ou le lien GitHub du dépôt, branche `claude/charming-brahmagupta-2uzr4t`).

---

Tu travailles sur mon jeu Roblox **Poule Renard Vipère** : 3 équipes, la Poule attrape la Vipère, la Vipère le Renard et le Renard la Poule. Le dossier `PouleRenardVipere/` contient 15 couteaux déjà faits avec leurs scripts. **Ne réécris pas les scripts : copie-les EXACTEMENT**, puis fais les vérifications et la finition. Ne supprime rien dans ma place sans me demander. Pas de texte BillboardGui dans la map. Réponds-moi en français, en phrases courtes.

## Étape 1 : Blender (finition des modèles, optionnel mais conseillé)
1. Ouvre Blender. Dans l'onglet Scripting, ouvre `PouleRenardVipere/blender/couteaux.py`. Mets `DOSSIER_EXPORT` sur un dossier de mon choix et lance-le. Il crée les 15 couteaux (une collection par couteau) et exporte un `.glb` par couteau.
2. Compare chaque couteau avec l'image de référence `apercu/reference.webp` si je te l'ai donnée, sinon avec la planche `apercu/planche_couteaux.png`. Peaufine les détails à l'œil en gardant les règles suivantes :
   - **Garde les noms d'objets** au format `<IdCouteau>_<Partie>_<cleCouleur>` (ex : `PouleBase_Blade_white`). Le script Roblox lit la clé couleur à la fin du nom. Les clés autorisées sont celles de `PALETTE` dans le script. Pour une nouvelle couleur, ajoute-la dans `PALETTE` ET dans `roblox/Config.lua > Config.Palette`.
   - **Un objet = une seule couleur.** Garde l'objet `*_Outline_outline` (contour noir cartoon, normales inversées). Si tu modifies la forme, recrée-le avec la fonction `build_outline`.
   - Lame vers **+Z**, tranchant vers **-X**, origine = milieu du manche, 1 unité = 1 stud.
   - **Moins de 20 000 triangles par objet** (limite Roblox).
   - Améliorations utiles : arrondir le dos des lames, ajouter du relief aux emblèmes (couronne, tête de renard, serpent, poule), et faire des plumes plus fines pour le Couteau plume.
3. Réexporte en `.glb` : sélectionne la collection, Fichier > Exporter > glTF 2.0 (.glb), « Selected Objects », +Y Up coché.

## Étape 2 : Roblox Studio
1. Crée `ReplicatedStorage.Couteaux` (Folder). Dedans, crée les ModuleScripts `Config` (contenu exact de `roblox/Config.lua`) et `FX` (contenu exact de `roblox/FX.lua`).
2. Importe les 15 `.glb` (ceux de `modeles/` ou ceux que tu viens de réexporter) avec l'Importer 3D, options par défaut. Les MeshParts doivent garder leurs noms `<Id>_<Partie>_<couleur>`.
3. Exécute le contenu de `roblox/InstallerCouteaux.lua` dans la barre de commandes. Vérifie dans la sortie : « 15 couteau(x) installé(s) ». Les Tools sont dans `ReplicatedStorage.Couteaux.Outils`.
4. Crée le Script `ServerScriptService.CouteauxServeur` (contenu exact de `roblox/CouteauxServeur.lua`) et le LocalScript `StarterPlayer.StarterPlayerScripts.CouteauxClient` (contenu exact de `roblox/CouteauxClient.lua`).
5. **Branche sur le jeu existant** :
   - Regarde comment le jeu gère déjà les équipes, la prison et les armes.
   - `Config.EquipeDe` doit renvoyer `"Poules"`, `"Renards"` ou `"Vipères"`. Adapte-la si les Teams ont d'autres noms.
   - Connecte `ServerStorage.CouteauxEvents.Touche.Event` (attaquant, victime, idCouteau) à la mise en prison existante.
   - Si le jeu donne déjà une arme, mets `Config.Combat.DonnerCouteau = false` et donne les Tools de `Outils`.
   - Le jeu doit mettre l'attribut `EnPrison` (Player) à `true` pendant la prison.
   - S'il existe déjà un système d'attaque ou d'esquive, ne le duplique pas : dis-moi lequel garder.

## Étape 3 : Test en Play (Test > Serveur local, 2 ou 3 joueurs)
- Le couteau tombe bien dans la main. Sinon, règle `Config.Grip` : tranchant vers l'avant / le bas, la main au milieu du manche.
- Les couleurs et le Neon sont corrects, et le contour noir est visible mais pas trop épais.
- Le combo 1-2-3 marche. La traînée colorée suit la lame. L'impact est propre à chaque couteau : éclairs (électrique), plumes, flammes, origami, poison, onde (géant).
- On ne touche que l'équipe qu'on chasse. L'esquive (Q / B / bouton mobile) rend invincible.
- Il n'y a aucune erreur dans la sortie.
- Si un son intégré ne joue pas, remplace-le dans `Config.Sons` par un son de la Boîte à outils (Creator Store).

Quand tout marche, dis-moi ce que tu as changé et publie (Alt+P) seulement si je te le demande.
