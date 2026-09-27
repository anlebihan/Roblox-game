# CLAUDE.md — Cashout Chaos (Roblox)

Mémoire du projet pour les prochaines sessions avec Claude. À lire avant toute modification.

## Le projet
- **Jeu** : 💰 Cashout Chaos — simulateur « ramasse des orbes → dépose dans ta base → améliore / rebirth », 6 équipes, manches « ZONE CHAOS » de 3 min, événements aléatoires.
- **Nouveauté** : BRAINROTS (tendance *Steal a Brainrot* / *Steal an Egg*) achetés avec le cash sur un tapis rouge au centre, revenus passifs dans la base, RAIDS sur les bases ennemies.
- **Propriétaire** : Antonin (YouX_X85), débutant, parle français. Réponses courtes, en français, et agir directement dans Studio plutôt que donner du code.
- **Studio** : place « Chaos de retrait d'argent », placeId `109302500548413`, universeId `10767733753`.
- **Règles de l'utilisateur** : ne rien détruire sans vérifier son rôle ; aucun texte BillboardGui dans la map (infos via le HUD ou les ProximityPrompts) ; DA « simulateur cartoon » (contours noirs épais, dégradés vifs, rayures, grosses icônes 3D) ; tester en Play après chaque grosse modif.

## Architecture (tout est dans la place Studio)
| Script | Rôle |
|---|---|
| `ReplicatedStorage.CashoutChaos.Config` | **Tout le réglage** : raretés, économie, upgrades, rebirth, GamePasses/Products (IDs réels), quêtes, événements, équipes, Brainrots, icônes (`UIIcons`, `UIArt`), sons. |
| `ReplicatedStorage.CashoutChaos.OrbFactory` | Rendu paramétrique des 12 orbes (client). |
| `ReplicatedStorage.CashoutChaos.OrbVisuals` / `ClientBus` | Icônes d'orbes (images de l'affiche) / état client partagé. |
| `ReplicatedStorage.Assets.Brainrots` | 10 modèles de créatures (générés par IA, pivot aligné monde, hauteur réglée). |
| `ServerScriptService.CashoutChaos.Main` | Serveur : joueurs, orbes, dépôt, vol, boutique, Robux (`ProcessReceipt` avec anti-doublon), manches, événements. Outil de test `ServerStorage.CC_Debug` (Studio uniquement). |
| `…DataService` | Sauvegarde DataStore (`CashoutChaos_v6`), `UpdateAsync`, ne sauvegarde jamais si le chargement a échoué. |
| `…MapBuilder` | Construit la map (île centrale + 6 îles + ponts). Pas de panneaux texte. |
| `…BrainrotService` | Tapis circulaire (r=47), achat par ProximityPrompt (E), emplacements dans les bases, revenus/s, raids (puissance vs défense, butin 6 %, bouclier 90 s, recharge 45 s). |
| `StarterPlayerScripts.CashoutChaosHUD` | Toute l'interface : dock 2×4, panneaux (Boutique + onglet Robux, Brainrots, Raid, Index, Sac, Quêtes, Réglages), offres arc-en-ciel, manette/tactile. |
| `StarterPlayerScripts.CashoutChaosFX` | Effets : orbes du monde, cinématique d'obtention, raids, animation des brainrots, musique. |
| `ReplicatedFirst.LoadingScreen` | Écran de chargement (illustration, barre rayée + %, astuces, orbes flottantes). |

## Monétisation (IDs réels déjà dans Config)
- **Game Passes** : CASH x2 399 R$, VIP 199, CHANCE x2 299, AIMANT XL 249, SAC XL 149, DASH PRO 99.
- **Developer Products** : Pack débutant 49 (achat unique), cash 25 / 99 / 249 / 799, Boost x2 49 / 149, Orbe Mythique 99, Dragonito Dorato (brainrot SECRET) 199.
- La tarification régionale (« tarification gérée ») est désactivée pour que les prix affichés correspondent.

## Pages Roblox
- Icône et 2 miniatures en ligne (images dans `CashoutChaos_Icone.png`, `CashoutChaos_Miniature1-3.jpg`). Nom « 💰 Cashout Chaos » et description FR remplis. Appareils : PC, mobile, tablette, console, VR.

## À faire / attention
- ⚠️ Pendant les tests, la vraie sauvegarde d'Antonin a reçu du cash de test (~134 M) et 2 brainrots. Il faut la remettre à zéro : en Play dans Studio, `ServerStorage.CC_Debug:Invoke("clear")` puis `Invoke("setcash", 247)`.
- Publier (Alt+P) après chaque session, sinon les joueurs gardent l'ancienne version.
- Passer le jeu en **Public** (Configurer, Audience) et remplir le questionnaire de maturité (console).
- Idées suivantes : œufs à ouvrir, vol direct de brainrots dans les bases, classement des raids, images pour les Game Passes.
