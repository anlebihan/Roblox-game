# 🎬 TRIPLE HUNT — Écran de chargement

![Écran de chargement](apercu/chargement_image.png)

Vidéo de l'animation : `apercu/apercu_chargement.mp4`.

## Ce qu'il fait
| Temps | Animation | Son |
|---|---|---|
| 0 s | Le ciel étoilé et le portail apparaissent (zoom lent, anneau qui tourne, rayons de lumière) | — |
| 0,5 s | Le rocher monte depuis le bas | — |
| 1,4 / 1,85 / 2,2 s | Les 3 couteaux géants tombent et **se plantent** : éclats de roche, fissure lumineuse, lueur de la couleur de l'équipe, ombre du couteau qui se forme, poussière, flash, secousse | sifflement + impact + grondement |
| 2,6 s | Le titre **TRIPLE HUNT** arrive en rebondissant, puis un reflet passe dessus toutes les 4 s | tintement |
| 3 s | Barre de chargement (dégradé aux couleurs des équipes, rayures qui défilent) + astuces écrites lettre par lettre | — |
| Prêt | « PRÊT ! » puis le bouton **▶ JOUER** pulse (clic, Entrée ou bouton A de la manette) | tintement |
| Clic | Coup de lame qui tranche l'écran, flash, zoom et fondu vers le jeu | lame |

Toujours présents : braises colorées qui montent, étoiles qui scintillent, parallaxe à la souris. La barre suit le **vrai** chargement (préchargement des images, sons, maillages, animations), avec une durée minimale de 7 s pour l'intro. Le bouton PASSER apparaît après 2,5 s.

## Fichiers
| Dossier | Contenu |
|---|---|
| `images/` | Les 30 images à importer dans Roblox (toutes ≤ 1024 px). |
| `roblox/EcranChargement.lua` | LocalScript `ReplicatedFirst.EcranChargement`. |
| `roblox/InstallerImages.lua` | À coller une fois dans la barre de commandes, après l'import des images. |
| `blender/rendus_interface.py` | Toute la scène 3D (ciel, portail, rocher, couteaux, ombres, titre, éclats de roche). |
| `blender/finition_logo_scene.py` | Liseré néon et lueur du titre (champ de distance, contours lisses). |
| `blender/ombres_couteaux.py` | Ombres des couteaux sur le rocher (couches séparées). |
| `blender/textures_effets.py` | Textures des effets (anneau, rayons, braise, étincelle, lame, fissure, fumée). |
| `blender/exporter_images.py` | Découpe/rognage pour Roblox et écriture des positions dans le script. |

## Changer le nom ou les couteaux
Dans `blender/rendus_interface.py` : `NOM_DU_JEU`, `SOUS_TITRE`, les couteaux dans `avant_plan()`. Ensuite, relancer :
```
blender -b -P rendus_interface.py -- <dossier_glb_couteaux> <rendus> ciel avant logo_scene eclats
python ombres_couteaux.py <rendus>
python finition_logo_scene.py <rendus>/chargement_logo.png <rendus>/chargement_logo_final.png
python textures_effets.py <rendus>/chargement_logo_final.png <fx>
python exporter_images.py <rendus> <fx> images roblox/EcranChargement.lua
```
