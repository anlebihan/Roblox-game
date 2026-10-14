--[[ ModuleScript : ReplicatedStorage.Interface.Donnees        — TRIPLE HUNT —
     Le pont entre l'interface et le jeu. L'interface LIT D.Etat et écoute D.Change ;
     le jeu (script « BranchementInterface ») remplit D.Etat avec D.Mettre(...) et fournit D.Actions.
     Tant que rien n'est branché, des valeurs de démonstration s'affichent (pratique pour tester l'interface seule).
]]
local D = {}

local signal = Instance.new("BindableEvent")
D.Change = signal.Event                     -- D.Change:Connect(function(cle, valeur) ... end)
local notif = Instance.new("BindableEvent")
D.Notification = notif.Event                -- D.Notification:Connect(function(texte, couleur, pieces) ... end)
local capture = Instance.new("BindableEvent")
D.Capture = capture.Event                   -- fil des captures : (nomAttaquant, equipeA, nomVictime, equipeV, texteSpecial)

D.Demo = true                               -- passe à false dès que le jeu met des vraies valeurs

D.Etat = {
	Pieces = 12450,
	Niveau = 14, XP = 1240, XPMax = 2000,
	CouteauEquipe = "RenardBase",           -- id du couteau équipé (image dans le catalogue)
	Couteaux = { "PouleBase", "RenardBase", "ViperBase", "RenardFurtif", "PouleRoyal" },  -- couteaux possédés
	CaissesGratuites = 2,                   -- pastille sur le bouton Caisses
	CadeauPret = true, CadeauDans = 0,      -- cadeau du jour (secondes avant le prochain)
	Quetes = {
		{ Nom = "Attrape 5 joueurs", Progres = 3, Objectif = 5, Recompense = 150, Reclamee = false },
		{ Nom = "Libère 2 coéquipiers", Progres = 2, Objectif = 2, Recompense = 200, Reclamee = false },
		{ Nom = "Gagne une manche", Progres = 0, Objectif = 1, Recompense = 300, Reclamee = false },
	},
	Classement = {
		{ Nom = "FoxMaster", Valeur = 1520 }, { Nom = "YouX_X85", Valeur = 1340 }, { Nom = "Snakey42", Valeur = 990 },
	},
	-- manche : Active = en jeu, sinon lobby
	Manche = {
		Active = false, Numero = 1, TempsRestant = 180, AvantDebut = 12,
		Equipes = { Poules = { Libres = 4, Total = 5 }, Renards = { Libres = 2, Total = 5 }, ["Vipères"] = { Libres = 5, Total = 5 } },
	},
	EquipeJoueur = nil,                     -- nil = calculée depuis la Team du joueur (Config.EquipeDe)
}

-- Caisses : ce sont TES caisses existantes (le BranchementInterface remplace cette liste par celles du jeu :
-- même nom, même prix, même contenu, même image). Les valeurs ci-dessous ne servent qu'à la démonstration.
--   Image          = image de la caisse (nom d'image importée ou "rbxassetid://…")
--   Prix / PrixRobux, Contenu = liste d'ids de couteaux, Couleur, Badge (optionnel)
--   Rotation / OuvertureSprite (optionnel) : planches d'animation 4x4 (256 px) si tu en as
D.Caisses = {
	{ Id = "Poules", Nom = "CAISSE POULE", Prix = 500, Image = "icone_caisses", Couleur = Color3.fromRGB(255, 90, 60),
		Contenu = { "PouleBase", "PoulePlume", "PouleElectrique", "PouleRoyal", "PouleGeant" } },
	{ Id = "Renards", Nom = "CAISSE RENARD", Prix = 500, Image = "icone_caisses", Couleur = Color3.fromRGB(255, 140, 30),
		Contenu = { "RenardBase", "RenardFurtif", "RenardSpectre", "RenardLegendaire", "RenardOrigami" } },
	{ Id = "Viperes", Nom = "CAISSE VIPÈRE", Prix = 500, Image = "icone_caisses", Couleur = Color3.fromRGB(120, 240, 60),
		Contenu = { "ViperBase", "ViperSerpent", "ViperToxique", "ViperVenin", "ViperRoyal" } },
}
-- true = l'interface joue sa propre animation d'ouverture (roue + révélation) après l'achat ;
-- false = le jeu garde sa propre ouverture de caisse (l'interface appelle seulement D.Actions.AcheterCaisse)
D.OuvertureAnimee = true

-- Catalogue des couteaux : Nom, Rarete, Image (asset de l'icône du couteau ; vide = nom seul)
D.Catalogue = {
	PouleBase = { Nom = "Couteau de base", Rarete = "Commun" }, PoulePlume = { Nom = "Couteau plume", Rarete = "Rare" },
	PouleElectrique = { Nom = "Couteau électrique", Rarete = "Épique" }, PouleRoyal = { Nom = "Couteau royal", Rarete = "Légendaire" },
	PouleGeant = { Nom = "Couteau géant", Rarete = "Mythique" },
	RenardBase = { Nom = "Couteau de base", Rarete = "Commun" }, RenardFurtif = { Nom = "Couteau furtif", Rarete = "Rare" },
	RenardSpectre = { Nom = "Couteau spectre", Rarete = "Épique" }, RenardLegendaire = { Nom = "Couteau légendaire", Rarete = "Légendaire" },
	RenardOrigami = { Nom = "Couteau origami", Rarete = "Mythique" },
	ViperBase = { Nom = "Couteau de base", Rarete = "Commun" }, ViperSerpent = { Nom = "Couteau serpent", Rarete = "Rare" },
	ViperToxique = { Nom = "Couteau toxique", Rarete = "Épique" }, ViperVenin = { Nom = "Couteau venin", Rarete = "Légendaire" },
	ViperRoyal = { Nom = "Couteau royal", Rarete = "Mythique" },
}
D.Chances = { Commun = 55, Rare = 28, ["Épique"] = 12, ["Légendaire"] = 4, Mythique = 1 }

-- Packs de pièces (Robux) : ProduitId = ID du Developer Product
D.PacksPieces = {
	{ Pieces = 1000, Robux = 49, ProduitId = 0 },
	{ Pieces = 3000, Robux = 129, ProduitId = 0, Badge = "+20 %" },
	{ Pieces = 10000, Robux = 349, ProduitId = 0, Badge = "MEILLEUR PRIX" },
}

--[[ Actions : remplacées par le BranchementInterface. Chacune peut bloquer (attendre la réponse du serveur).
	AcheterCaisse(idCaisse) -> ok, idCouteauGagne | false, "message"
	EquiperCouteau(idCouteau) -> ok
	ReclamerQuete(index) -> ok
	RecupererCadeau() -> ok, pieces
	AcheterPieces(pack) -> (ouvre l'achat Robux)
	ChoisirEquipe(equipe) -> ok          (nil = l'équipe est choisie automatiquement par le jeu)
	Sprint(actif)                         (nil = pas de bouton SPRINT)
]]
D.Actions = {}
-- démo : tirage local (ne donne rien de réel)
D.Actions.AcheterCaisse = function(id)
	for _, c in ipairs(D.Caisses) do
		if c.Id == id then
			task.wait(0.3)
			return true, c.Contenu[math.random(1, #c.Contenu)]
		end
	end
	return false, "Caisse inconnue"
end
D.Actions.EquiperCouteau = function(idc) D.Mettre("CouteauEquipe", idc) return true end
D.Actions.ReclamerQuete = function(i)
	local q = D.Etat.Quetes[i]
	if q and q.Progres >= q.Objectif then q.Reclamee = true; D.Mettre("Quetes", D.Etat.Quetes); return true end
	return false
end
D.Actions.RecupererCadeau = function() D.Mettre("CadeauPret", false); return true, 100 end

function D.Mettre(cle, valeur)
	D.Etat[cle] = valeur
	signal:Fire(cle, valeur)
end

function D.Notifier(texte, couleur, pieces)
	notif:Fire(texte, couleur, pieces)
end

-- à appeler pour les captures/libérations que l'interface ne voit pas seule (bots…)
-- ex : D.SignalerCapture("Bot Vipère", "Vipères", "FoxMaster", "Renards")
--      D.SignalerCapture("Lola", "Poules", nil, nil, "a libéré 2 Poules")
function D.SignalerCapture(a, ea, v, ev, special)
	capture:Fire(a, ea, v, ev, special)
end

-- image d'un couteau du catalogue (icône importée « couteau_<Id> » par défaut)
function D.ImageCouteau(id)
	local c = D.Catalogue[id]
	return (c and c.Image) or ("couteau_" .. tostring(id))
end

return D
