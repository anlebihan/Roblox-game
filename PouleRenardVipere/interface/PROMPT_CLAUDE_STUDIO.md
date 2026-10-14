# Textes à donner à ton Claude (Roblox Studio)

## A. Écran de chargement (déjà fait)

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

---

## B. Interface de jeu (HUD, boutons mobiles, boutique, caisses, paramètres)

> Donne-lui le dossier `PouleRenardVipere/interface` ET le dossier `PouleRenardVipere/roblox` (mis à jour depuis GitHub).

Installe la nouvelle interface de jeu de TRIPLE HUNT depuis les dossiers que je te donne. Règles : copie mes scripts EXACTEMENT ; ne supprime rien sans me demander (ce qui est remplacé est désactivé, pas effacé) ; **ne touche pas à mes caisses** (modèles, prix, contenu, script `Coffres`, achat côté serveur) : l'interface doit seulement les AFFICHER et appeler leur achat ; pas de texte BillboardGui dans la map ; réponds en français en phrases courtes ; ne publie pas sans mon accord.

1. **Images** : j'importe moi-même les nouvelles images de `interface/images` (icônes `icone_*`, textures `skin_*`, `fx_brillance`, `fx_coin_visee`, couteaux `couteau_*`) avec « Importation groupée », puis clic droit > « Insérer ». Ensuite exécute `interface/roblox/InstallerImages.lua` dans la barre de commandes (il garde les images de l'écran de chargement et ajoute les nouvelles). Dis-moi combien d'images il a enregistrées.
2. **Scripts des couteaux** : remplace le contenu de `ReplicatedStorage.Couteaux.FX` et de `StarterPlayerScripts.CouteauxClient` par celui de `roblox/FX.lua` et `roblox/CouteauxClient.lua` (copie EXACTE). Ne touche pas à `Config` (garde `Combat.DonnerCouteau = false`).
3. **Modules** : crée le dossier `ReplicatedStorage.Interface` et dedans 5 ModuleScripts avec le contenu EXACT de `interface/roblox/Interface/` : `Style`, `Donnees`, `HUD`, `Panneaux`, `Ouverture`.
4. Crée le LocalScript `StarterPlayer.StarterPlayerScripts.InterfaceJeu` avec le contenu EXACT de `interface/roblox/InterfaceJeu.lua`.
5. **Ancienne interface** : désactive (Disabled = true, sans supprimer) le LocalScript `StarterPlayerScripts.HUD`, et dans `ClientMain` coupe seulement le bouton FRAPPER mobile avec un drapeau (`local ANCIEN_BOUTON_FRAPPER = false`). Garde `Progression`, `Vent` et `Coffres`. Si `Progression` affiche aussi des panneaux à l'écran (fin de manche, niveau), dis-moi lesquels avant de toucher à quoi que ce soit.
6. **Branchement** : crée le LocalScript `StarterPlayerScripts.BranchementInterface` à partir de `interface/roblox/BranchementInterface.lua`. C'est le SEUL script que tu dois adapter : lis `DataService`, `GameManager`, `LobbyService`, `Coffres` et `ReplicatedStorage.PRV.KnifeData`, puis remplis chaque bloc « À ADAPTER » :
   - pièces, niveau, XP ;
   - `D.Catalogue` (les couteaux avec leur icône actuelle) et `D.Caisses` = **mes caisses existantes** (même id, nom, prix, contenu, image ; `X5 = false` si le serveur ne peut pas en ouvrir 5) ;
   - `D.Actions.AcheterCaisse(id, n)` appelle l'achat de caisse DÉJÀ présent dans le jeu et renvoie `true, idDuCouteauGagné` (ou `false, "message"`). Si le jeu a déjà sa propre animation d'ouverture et que je préfère la garder, mets `D.OuvertureAnimee = false` ;
   - couteaux possédés / équipé, caisses gratuites, cadeau du jour, quêtes : si le client ne les reçoit pas encore, ajoute côté serveur un RemoteFunction `Interface_Profil` et un RemoteEvent `Interface_MAJ` qui LISENT le DataService (sans changer sa logique ni sa sauvegarde) ;
   - l'état de la manche (actif, numéro, temps restant, prochaine manche, libres/total par équipe) depuis le GameManager, via des attributs sur `ReplicatedStorage` ;
   - les captures des bots dans le fil : `D.SignalerCapture(...)` ;
   - la musique du jeu : mets son `Sound.SoundGroup` sur `SoundService.Musique` (créé par l'interface) pour que le curseur Musique marche.
   Avant de modifier un script serveur, montre-moi ce que tu ajoutes.
7. Teste en Play (et en « Appareil » téléphone dans l'émulateur) et vérifie :
   - lobby : profil + niveau, pièces (le compteur défile quand on gagne), raccourcis animés, chrono de la prochaine manche ;
   - boutique : onglet CAISSES = mes caisses avec leur contenu et leurs chances, ouverture (roue puis révélation), onglet COUTEAUX (équiper), onglet PIÈCES ;
   - paramètres : volumes, secousses, mode performance, touche d'esquive (sur AZERTY elle s'affiche « A ») ;
   - en manche : rôle, chrono (rouge les 10 dernières secondes), équipes, fil des captures, alerte « X PROCHE ! », boutons FRAPPER / ESQUIVE (recharge) sur mobile ;
   - aucune erreur dans la sortie.
   Si une image manque (carré vide), vérifie son nom dans `ReplicatedFirst.ImagesInterface`.

---

## C. Esquive parfaite (nouvelle animation + règle de combat)

> Fichiers : dossier `PouleRenardVipere/roblox` et `interface/roblox/Interface/HUD.lua` (mis à jour depuis GitHub).

Ajoute l'ESQUIVE PARFAITE à mon jeu : si j'esquive juste avant ou pendant le coup d'un ennemi, je deviens intouchable 1 s et l'ennemi est DÉSARMÉ 1,4 s (il ne peut plus frapper et il est ralenti), avec une vrille aérienne animée et des effets. Copie mes scripts EXACTEMENT, ne supprime rien sans me demander, réponds en français en phrases courtes, ne publie rien (ni jeu ni animation) sans mon accord.

1. Exécute `roblox/InstallerAnimations.lua` dans la barre de commandes (il recrée les 9 animations, dont la nouvelle `EsquiveParfaite`).
2. Remplace le contenu EXACT de : `ReplicatedStorage.Couteaux.Config` (`roblox/Config.lua`, puis remets `Combat.DonnerCouteau = false`), `ReplicatedStorage.Couteaux.FX` (`roblox/FX.lua`), `ServerScriptService.CouteauxServeur` (`roblox/CouteauxServeur.lua`), `StarterPlayerScripts.CouteauxClient` (`roblox/CouteauxClient.lua`) et `ReplicatedStorage.Interface.HUD` (`interface/roblox/Interface/HUD.lua`). Si tu avais déjà mis des IDs d'animations publiées dans `Config.Animations`, remets-les.
3. Les BOTS : dans le code où un bot attrape un joueur (GameManager / Bots, l'ancien `tryAttack`), ajoute juste avant la capture :
   `if ServerStorage.CouteauxEvents.TesterEsquive:Invoke(joueurVise, modeleDuBot) then return end`
   et ne fais pas attaquer un bot dont le modèle a l'attribut `Etourdi`. Montre-moi les lignes avant de les ajouter.
4. Facultatif (si je le veux) : récompense dans le GameManager avec `ServerStorage.CouteauxEvents.EsquiveParfaite.Event:Connect(function(joueur, attaquant) ... end)` (pièces, quête « fais 3 esquives parfaites »…).
5. Teste en Play à 2 joueurs (Test > Serveur local, 2 joueurs) : un joueur frappe, l'autre appuie sur ESQUIVE (A) au moment du coup. Vérifie : la vrille se joue, « ESQUIVE PARFAITE ! » s'affiche, l'écran se fige une fraction de seconde, l'attaquant voit « DÉSARMÉ ! » avec des étoiles au-dessus de la tête et ne peut plus frapper, et aucune erreur dans la sortie. Teste aussi contre un bot.
