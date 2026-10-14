# Texte à donner à ton Claude (Roblox Studio)

> Donne-lui aussi le dossier `PouleRenardVipere/interface` (téléchargé depuis GitHub).

---

Installe le nouvel écran de chargement de mon jeu (nom : TRIPLE HUNT) depuis le dossier `interface` que je te donne. Copie le script EXACTEMENT, ne supprime rien sans me demander, réponds en français en phrases courtes, et ne publie pas sans mon accord.

1. **Images** : je les importe moi-même dans le Gestionnaire de ressources avec « Importation groupée » (les 30 fichiers de `interface/images`). Ensuite, je les sélectionne toutes et je fais clic droit > « Insérer ». Dis-moi quand tu vois les Decals apparaître dans le Workspace.
2. Exécute le contenu de `interface/roblox/InstallerImages.lua` dans la barre de commandes. La sortie doit dire « 30 image(s) enregistrée(s) ». Il crée `ReplicatedFirst.ImagesInterface` et range les Decals dans `ServerStorage.ImagesImportees`.
3. Crée le LocalScript `ReplicatedFirst.EcranChargement` avec le contenu EXACT de `interface/roblox/EcranChargement.lua`.
4. S'il existe déjà un autre écran de chargement dans ReplicatedFirst, **désactive-le** (Disabled = true) sans le supprimer, et dis-le-moi.
5. Teste en Play et vérifie :
   - le ciel, le portail et le rocher s'affichent ;
   - les 3 couteaux tombent avec les éclats de roche, les fissures et les ombres ;
   - le titre TRIPLE HUNT arrive, la barre se remplit, puis le bouton JOUER mène au jeu ;
   - aucune erreur dans la sortie.
   Si une image manque (carré vide), vérifie son nom dans `ImagesInterface`.
6. Facultatif : si je te le demande, choisis une musique épique dans la Boîte à outils (Audio) et mets son ID dans `SONS.Musique`.
