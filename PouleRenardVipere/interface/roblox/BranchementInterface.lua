--[[ LocalScript : StarterPlayer.StarterPlayerScripts.BranchementInterface      — TRIPLE HUNT —
     MODÈLE à compléter par Claude dans Studio : relie l'interface (ReplicatedStorage.Interface.Donnees)
     au jeu EXISTANT (DataService, GameManager, KnifeData, caisses déjà créées par Antonin).

     Règles :
       - Ne rien changer aux caisses existantes : on LIT leur nom / prix / contenu / image, on APPELLE leur achat.
       - Chaque bloc « À ADAPTER » doit être rempli en lisant les vrais scripts du jeu
         (noms des RemoteEvents / RemoteFunctions, attributs, leaderstats…). Si une info n'existe pas encore
         côté serveur, ajouter le RemoteFunction côté serveur SANS modifier la logique existante.
       - Tant qu'un bloc n'est pas branché, l'interface garde ses valeurs de démonstration pour ce bloc.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local joueur = Players.LocalPlayer
local D = require(ReplicatedStorage:WaitForChild("Interface"):WaitForChild("Donnees"))
D.Demo = false

------------------------------------------------------------------------ PIÈCES / NIVEAU / XP
-- À ADAPTER : où le jeu stocke les pièces et l'XP (leaderstats ? attributs du Player ? valeurs envoyées par un Remote ?)
local function suivreValeur(cleInterface, lire, signal)
	local function maj() local v = lire(); if v ~= nil then D.Mettre(cleInterface, v) end end
	maj()
	if signal then signal:Connect(maj) end
end
task.spawn(function()
	local ls = joueur:WaitForChild("leaderstats", 10)
	local pieces = ls and (ls:FindFirstChild("Pièces") or ls:FindFirstChild("Pieces") or ls:FindFirstChild("Coins"))
	if pieces then
		suivreValeur("Pieces", function() return pieces.Value end, pieces.Changed)
	else
		suivreValeur("Pieces", function() return joueur:GetAttribute("Pieces") end, joueur:GetAttributeChangedSignal("Pieces"))
	end
	for _, cle in ipairs({ "Niveau", "XP", "XPMax" }) do
		suivreValeur(cle, function() return joueur:GetAttribute(cle) end, joueur:GetAttributeChangedSignal(cle))
	end
end)

------------------------------------------------------------------------ CATALOGUE + CAISSES EXISTANTES
-- À ADAPTER : lire ReplicatedStorage.PRV.KnifeData (ids « Poules_Plume »…) et les caisses déjà créées.
-- Pour chaque couteau : D.Catalogue[id] = { Nom = ..., Rarete = "Commun"|"Rare"|"Épique"|"Légendaire"|"Mythique",
--                                           Image = "rbxassetid://..." (l'icône déjà utilisée par la boutique), Equipe = "Poules"|"Renards"|"Vipères" }
-- Pour chaque caisse EXISTANTE (même ordre, mêmes prix) :
--   { Id = <id utilisé par le serveur>, Nom = ..., Prix = ..., (ou PrixRobux = ...), Contenu = { ids... },
--     Image = <image de la caisse déjà faite : "rbxassetid://...">, Couleur = Color3, Chances = { Commun = 55, ... } (si différentes),
--     X5 = false si le serveur ne sait pas ouvrir 5 caisses }
local okKD, KnifeData = pcall(function() return require(ReplicatedStorage:WaitForChild("PRV", 10):WaitForChild("KnifeData", 10)) end)
if okKD and type(KnifeData) == "table" then
	-- exemple de conversion (à corriger selon la vraie structure de KnifeData) :
	-- local catalogue = {}
	-- for id, k in pairs(KnifeData.Knives) do
	--     catalogue[id] = { Nom = k.Name, Rarete = k.Rarity, Image = k.Image, Equipe = k.Team }
	-- end
	-- D.Catalogue = catalogue ; D.Mettre("Catalogue", catalogue)
	-- local caisses = {}
	-- for _, c in ipairs(KnifeData.Crates) do
	--     table.insert(caisses, { Id = c.Id, Nom = c.Name, Prix = c.Price, Contenu = c.Knives, Image = c.Image, Couleur = c.Color })
	-- end
	-- D.Caisses = caisses ; D.Mettre("Caisses", caisses)
end
-- D.Chances = { Commun = 55, Rare = 28, ["Épique"] = 12, ["Légendaire"] = 4, Mythique = 1 }  -- les vraies chances du jeu
-- D.OuvertureAnimee = true   -- false = garder l'animation d'ouverture déjà faite dans le jeu

------------------------------------------------------------------------ COUTEAUX POSSÉDÉS / ÉQUIPÉ, CAISSES GRATUITES, CADEAU, QUÊTES
-- À ADAPTER : le DataService envoie-t-il ces infos au client ? Sinon ajouter côté serveur un RemoteFunction
-- « Interface_Profil » qui renvoie { Couteaux = {...}, CouteauEquipe = id, CaissesGratuites = n, CadeauPret = bool,
-- CadeauDans = secondes, Quetes = { {Nom, Progres, Objectif, Recompense, Reclamee}, ... }, QuetesDans = secondes,
-- Parametres = {...} } et un RemoteEvent « Interface_MAJ » (cle, valeur) quand ça change.
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("PRV", 10)
	local profil = remotes and remotes:FindFirstChild("Interface_Profil")
	if profil then
		local ok, p = pcall(function() return profil:InvokeServer() end)
		if ok and type(p) == "table" then
			for cle, v in pairs(p) do D.Mettre(cle, v) end
		end
	end
	local maj = remotes and remotes:FindFirstChild("Interface_MAJ")
	if maj then maj.OnClientEvent:Connect(function(cle, v) D.Mettre(cle, v) end) end
end)

------------------------------------------------------------------------ MANCHE (GameManager)
-- À ADAPTER : état de la manche. Exemple si le GameManager met des attributs sur ReplicatedStorage :
--   MancheActive (bool), MancheNumero, MancheFin (workspace:GetServerTimeNow() de fin), ProchaineManche (heure serveur)
-- et le nombre de libres / total par équipe (attributs « Libres_Poules », « Total_Poules »…).
local function lireManche()
	local R = ReplicatedStorage
	local now = workspace:GetServerTimeNow()
	local fin, prochaine = R:GetAttribute("MancheFin"), R:GetAttribute("ProchaineManche")
	local equipes = {}
	for _, eq in ipairs({ "Poules", "Renards", "Vipères" }) do
		equipes[eq] = { Libres = R:GetAttribute("Libres_" .. eq) or 0, Total = R:GetAttribute("Total_" .. eq) or 0 }
	end
	D.Mettre("Manche", {
		Active = R:GetAttribute("MancheActive") == true,
		Numero = R:GetAttribute("MancheNumero") or 1,
		TempsRestant = fin and math.max(0, fin - now) or 0,
		AvantDebut = prochaine and math.max(0, prochaine - now) or nil,
		Equipes = equipes,
	})
end
ReplicatedStorage.AttributeChanged:Connect(lireManche)
lireManche()

------------------------------------------------------------------------ ACTIONS (appellent le jeu existant)
-- À ADAPTER : noms des remotes du jeu.
local function remote(nom)
	local d = ReplicatedStorage:FindFirstChild("PRV")
	return d and d:FindFirstChild(nom, true)
end

-- achat d'une caisse EXISTANTE : doit renvoyer ok, idCouteauGagné (ou ok, {ids} pour n caisses) ; false, "message" si refusé
D.Actions.AcheterCaisse = function(idCaisse, n)
	local r = remote("OuvrirCaisse")              -- À ADAPTER (RemoteFunction de l'achat de caisse déjà dans le jeu)
	if not r then return false, "Caisse indisponible" end
	return r:InvokeServer(idCaisse, n)
end
D.Actions.EquiperCouteau = function(id)
	local r = remote("EquiperCouteau")           -- À ADAPTER
	if not r then return false end
	if r:IsA("RemoteFunction") then return r:InvokeServer(id) end
	r:FireServer(id); return true
end
D.Actions.ReclamerQuete = function(index)
	local r = remote("ReclamerQuete")            -- À ADAPTER
	return r and r:InvokeServer(index) or false
end
D.Actions.RecupererCadeau = function()
	local r = remote("RecupererCadeau")          -- À ADAPTER
	if not r then return false end
	return r:InvokeServer()                      -- ok, piecesGagnees
end
D.Actions.AcheterPieces = function(pack)
	if pack.ProduitId and pack.ProduitId > 0 then MarketplaceService:PromptProductPurchase(joueur, pack.ProduitId) end
end
D.Actions.SauverParametres = function(params)
	local r = remote("SauverParametres")         -- optionnel : sauvegarde des réglages dans le DataService
	if r then r:FireServer(params) end
end
-- D.Actions.ChoisirEquipe = function(eq) ... end   -- seulement si le joueur choisit son équipe dans le lobby
-- D.Actions.Sprint = function(actif) ... end       -- seulement si le jeu a un sprint (sinon pas de bouton SPRINT)

-- D.PacksPieces = { { Pieces = 1000, Robux = 49, ProduitId = <vrai ID> }, ... }   -- À ADAPTER (vrais Developer Products)

------------------------------------------------------------------------ FIL DES CAPTURES DES BOTS
-- Les captures entre vrais joueurs s'affichent toutes seules. Pour les bots, appeler (ex. depuis un RemoteEvent du GameManager) :
-- D.SignalerCapture(nomAttaquant, equipeAttaquant, nomVictime, equipeVictime)
-- D.SignalerCapture(nom, equipe, nil, nil, "a libéré 2 Poules")
-- et pour un gain : D.Notifier("Capture !", nil, 25)
