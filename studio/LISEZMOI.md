# Ajouter les brainrots

| Fichier (`assets/`) | Brainrot |
|---|---|
| `TungTungTungSahur.glb` | Tung Tung Tung Sahur |
| `BombardiroCrocodilo.glb` | Bombardiro Crocodilo |
| `TralaleroTralala.glb` | Tralalero Tralala |
| `BobriniCocosini.glb` | Bobrini Cocosini |
| `UdinDinDinDun.glb` | Udin Din Din Dun |
| `DragonCannelloni.glb` | Dragon Cannelloni |
| `CapuccinoAssassino.glb` | Capuccino Assassino |
| `KarkerkarKurkur.glb` | Karkerkar Kurkur |

Chaque modèle a été converti en `.glb`, réduit sous 20 000 triangles (limite Roblox) avec texture 1024×1024 max.

1. **Importer** : Studio > Accueil > *Importer 3D* > choisir un `.glb` (répéter pour chacun).
2. **Lancer** `studio/AjouterBrainrots.lua` dans la Barre de commandes : tous les modèles importés sont rangés dans
   `ReplicatedStorage.Assets.Brainrots`, à la bonne taille, pivot en bas. Rien n'est supprimé ni remplacé.
   Si l'un regarde dans le mauvais sens, mets `NomDuBrainrot = true` dans `TOURNER_180` (avant de le ranger).
3. **Config** : dans `ReplicatedStorage.CashoutChaos.Config`, pour chaque brainrot, **dupliquer la ligne d'un brainrot
   existant** et changer le nom du modèle (nom du fichier sans `.glb`), le nom affiché, la rareté, le prix et les revenus/s.
4. **Tester en Play**, puis **publier** (Alt+P).

Pour convertir un nouveau modèle : `outils/convertir_brainrot.py` (fonction `convert`).
