# Ajouter « Tung Tung Tung Sahur »

1. **Importer le modèle** : Studio > Accueil > *Importer 3D* > `assets/TungTungTungSahur.glb`.
   (Modèle converti depuis le `.usdz`, réduit à ~21 000 triangles pour respecter la limite Roblox, texture 1024×1024.)
2. **Lancer le script** : copier `studio/AjouterTungTungSahur.lua` dans la Barre de commandes, puis Entrée.
   Le modèle est rangé dans `ReplicatedStorage.Assets.Brainrots`, avec la bonne taille et le bon pivot.
3. **L'ajouter dans `Config`** : ouvrir `ReplicatedStorage.CashoutChaos.Config`, trouver la liste des Brainrots,
   **dupliquer la ligne d'un brainrot existant** et changer :
   - le nom du modèle → `"TungTungTungSahur"`
   - le nom affiché → `"Tung Tung Tung Sahur"`
   - la rareté, le prix et les revenus/s à ton goût
4. **Tester en Play** : il doit apparaître sur le tapis rouge, s'acheter avec E et rapporter du cash dans la base.
5. **Publier** (Alt+P).
