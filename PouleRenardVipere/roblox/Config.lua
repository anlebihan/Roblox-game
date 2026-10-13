--[[ ModuleScript : ReplicatedStorage.Couteaux.Config
     Tout le réglage des couteaux : couleurs, combat, effets (VFX), sons (SFX), animations.
     Les clés de Palette correspondent à la fin des noms des pièces importées
     (ex : « PouleBase_Blade_white » -> Palette.white).
]]
local Config = {}

----------------------------------------------------------------- ÉQUIPES
-- Qui chasse qui : la Poule attrape la Vipère, la Vipère le Renard, le Renard la Poule.
Config.Chasse = { Poules = "Vipères", ["Vipères"] = "Renards", Renards = "Poules" }

Config.Equipes = {
	Poules = { Couleur = Color3.fromRGB(214, 40, 40), Couleur2 = Color3.fromRGB(246, 178, 26), Base = "PouleBase" },
	Renards = { Couleur = Color3.fromRGB(255, 106, 0), Couleur2 = Color3.fromRGB(42, 36, 32), Base = "RenardBase" },
	["Vipères"] = { Couleur = Color3.fromRGB(71, 209, 31), Couleur2 = Color3.fromRGB(122, 47, 208), Base = "ViperBase" },
}

-- Retrouve l'équipe d'un joueur (attribut « Equipe » prioritaire, sinon le nom de sa Team).
function Config.EquipeDe(player)
	if not player then return nil end
	local attr = player:GetAttribute("Equipe")
	if attr and Config.Equipes[attr] then return attr end
	local nom = player.Team and string.lower(player.Team.Name) or ""
	if string.find(nom, "poule") then return "Poules" end
	if string.find(nom, "renard") then return "Renards" end
	if string.find(nom, "vip") then return "Vipères" end
	return nil
end

function Config.PeutAttaquer(equipeAttaquant, equipeVictime)
	return equipeAttaquant ~= nil and Config.Chasse[equipeAttaquant] == equipeVictime
end

----------------------------------------------------------------- COMBAT
Config.Combat = {
	Portee = 7,              -- distance max d'un coup (studs)
	AngleMax = 75,           -- cône devant le joueur (degrés)
	Recharge = 0.42,         -- délai entre deux coups
	FenetreCombo = 0.9,      -- temps pour enchaîner le coup suivant (combo 1-2-3)
	Degats = 0,              -- 0 = pas de dégâts (le jeu gère la capture via l'événement « Touche »)
	Recul = 38,              -- recul de la victime
	DonnerCouteau = true,    -- donne le couteau de l'équipe à l'apparition (mettre false si le jeu le fait déjà)
}

Config.Esquive = {
	Active = true,
	Touche = Enum.KeyCode.Q, Manette = Enum.KeyCode.ButtonB,
	Vitesse = 62,            -- vitesse du dash
	Duree = 0.18,
	Invincible = 0.35,       -- invincibilité (s)
	Recharge = 1.6,
}

-- Position du couteau dans la main (à ajuster en Play si besoin)
Config.Grip = CFrame.new(0, 0, 0)  -- ex : * CFrame.Angles(0, math.rad(90), 0) pour tourner le tranchant

-- IDs des animations publiées (« rbxassetid://123… »). Tant qu'un ID est vide :
--   - dans Studio, l'animation de ReplicatedStorage.Couteaux.Animations est utilisée (test en Play) ;
--   - en jeu publié, l'animation classique « Slash/Lunge » de Roblox est utilisée pour les coups.
Config.Animations = {
	Coup1 = "", Coup2 = "", Coup3 = "",   -- combo (Action2, haut du corps / corps entier pour l'estoc)
	EsquiveDroite = "", EsquiveGauche = "", EsquiveArriere = "",   -- sauts d'esquive (Action3)
	Course = "",                          -- sprint, remplace la course de Roblox (Movement)
	Garde = "",                           -- garde couteau en main (Action, haut du corps, boucle)
}

----------------------------------------------------------------- PALETTE
local M = Enum.Material
Config.Palette = {
	white = { Color3.fromHex("F4F1EA"), M.SmoothPlastic },
	cream = { Color3.fromHex("EADBB8"), M.SmoothPlastic },
	steel = { Color3.fromHex("D8DEE6"), M.SmoothPlastic, 0.18 },
	steel_dark = { Color3.fromHex("8E98A6"), M.SmoothPlastic, 0.12 },
	red = { Color3.fromHex("D62828"), M.SmoothPlastic },
	red_dark = { Color3.fromHex("8E1414"), M.SmoothPlastic },
	yellow = { Color3.fromHex("F6B21A"), M.SmoothPlastic },
	gold = { Color3.fromHex("F2C230"), M.SmoothPlastic, 0.2 },
	black = { Color3.fromHex("1B1B1F"), M.SmoothPlastic },
	gray_dark = { Color3.fromHex("3A3D44"), M.SmoothPlastic, 0.1 },
	orange = { Color3.fromHex("FF6A00"), M.SmoothPlastic },
	fox_dark = { Color3.fromHex("2A2420"), M.SmoothPlastic },
	green = { Color3.fromHex("47D11F"), M.SmoothPlastic },
	green_dark = { Color3.fromHex("1E4D1E"), M.SmoothPlastic },
	purple = { Color3.fromHex("7A2FD0"), M.SmoothPlastic },
	purple_dark = { Color3.fromHex("3B1670"), M.SmoothPlastic },
	orange_glow = { Color3.fromHex("FF7A1A"), M.Neon },
	yellow_glow = { Color3.fromHex("FFD23A"), M.Neon },
	green_glow = { Color3.fromHex("7CFF2E"), M.Neon },
	outline = { Color3.fromHex("000000"), M.SmoothPlastic },
}

----------------------------------------------------------------- SONS (SFX)
-- Sons intégrés à Roblox (marchent tout de suite). Pour de plus beaux sons :
-- Boîte à outils > Sons, puis remplacer par "rbxassetid://<ID>".
Config.Sons = {
	Degainer = "rbxasset://sounds/unsheath.wav",
	Coup = "rbxasset://sounds/swordslash.wav",
	Estoc = "rbxasset://sounds/swordlunge.wav",
	Impact = "rbxasset://sounds/swordslash.wav",
	Electrique = "rbxasset://sounds/electronicpingshort.wav",
	Esquive = "rbxasset://sounds/swordlunge.wav",
}

----------------------------------------------------------------- COUTEAUX + EFFETS (VFX)
local C = Color3.fromRGB
--[[ Champs :
	Trainee = { couleur début, couleur fin, largeur }   -> traînée lumineuse pendant le coup
	Aura    = { Type = "etincelles"|"feu"|"fumee"|"plumes"|"bulles"|"gouttes", Couleur, Debit }
	Lumiere = couleur d'une lueur autour de la lame (nil = aucune) ; Clignote = true pour l'électrique
	Impact  = "plumes"|"etoiles"|"eclair"|"onde"|"eclat"|"fumee"|"spectre"|"flammes"|"origami"|"poison"|"couronne"
	Hauteur = hauteur des sons (1 = normal) ; Secousse = force de la secousse de caméra à l'impact
]]
Config.Couteaux = {
	-- POULES
	PouleBase = { Nom = "Couteau de base", Equipe = "Poules", Rarete = "Commun",
		Trainee = { C(255, 255, 255), C(214, 40, 40), 1 }, Impact = "plumes", Hauteur = 1.05, Secousse = 0.25 },
	PouleRoyal = { Nom = "Couteau royal", Equipe = "Poules", Rarete = "Légendaire",
		Trainee = { C(255, 225, 90), C(255, 255, 255), 1.1 }, Aura = { Type = "etincelles", Couleur = C(255, 215, 70), Debit = 6 },
		Lumiere = C(255, 210, 80), Impact = "etoiles", Hauteur = 1.1, Secousse = 0.35 },
	PoulePlume = { Nom = "Couteau plume", Equipe = "Poules", Rarete = "Rare",
		Trainee = { C(255, 255, 255), C(214, 40, 40), 1.2 }, Aura = { Type = "plumes", Couleur = C(255, 255, 255), Debit = 3 },
		Impact = "plumes", Hauteur = 1.25, Secousse = 0.25 },
	PouleElectrique = { Nom = "Couteau électrique", Equipe = "Poules", Rarete = "Épique",
		Trainee = { C(255, 230, 60), C(255, 140, 0), 1.1 }, Aura = { Type = "etincelles", Couleur = C(255, 225, 60), Debit = 14 },
		Lumiere = C(255, 220, 60), Clignote = true, Impact = "eclair", Hauteur = 1.15, Secousse = 0.45 },
	PouleGeant = { Nom = "Couteau géant", Equipe = "Poules", Rarete = "Mythique",
		Trainee = { C(255, 80, 80), C(255, 255, 255), 1.8 }, Impact = "onde", Hauteur = 0.72, Secousse = 0.8 },

	-- RENARDS
	RenardBase = { Nom = "Couteau de base", Equipe = "Renards", Rarete = "Commun",
		Trainee = { C(255, 140, 40), C(255, 70, 0), 1 }, Impact = "eclat", Hauteur = 1.05, Secousse = 0.25 },
	RenardFurtif = { Nom = "Couteau furtif", Equipe = "Renards", Rarete = "Rare",
		Trainee = { C(40, 34, 30), C(255, 106, 0), 0.8 }, Aura = { Type = "fumee", Couleur = C(40, 35, 32), Debit = 5 },
		Impact = "fumee", Hauteur = 1.2, Secousse = 0.25 },
	RenardSpectre = { Nom = "Couteau spectre", Equipe = "Renards", Rarete = "Épique",
		Trainee = { C(255, 150, 50), C(255, 60, 0), 1.2 }, Aura = { Type = "feu", Couleur = C(255, 120, 30), Debit = 8 },
		Lumiere = C(255, 120, 30), Impact = "spectre", Hauteur = 0.95, Secousse = 0.4 },
	RenardLegendaire = { Nom = "Couteau légendaire", Equipe = "Renards", Rarete = "Légendaire",
		Trainee = { C(255, 210, 60), C(255, 70, 0), 1.3 }, Aura = { Type = "feu", Couleur = C(255, 110, 20), Debit = 16 },
		Lumiere = C(255, 110, 20), Impact = "flammes", Hauteur = 0.9, Secousse = 0.55 },
	RenardOrigami = { Nom = "Couteau origami", Equipe = "Renards", Rarete = "Mythique",
		Trainee = { C(255, 106, 0), C(30, 30, 30), 1.2 }, Impact = "origami", Hauteur = 1.3, Secousse = 0.45 },

	-- VIPÈRES
	ViperBase = { Nom = "Couteau de base", Equipe = "Vipères", Rarete = "Commun",
		Trainee = { C(90, 230, 50), C(122, 47, 208), 1 }, Impact = "poison", Hauteur = 1.05, Secousse = 0.25 },
	ViperToxique = { Nom = "Couteau toxique", Equipe = "Vipères", Rarete = "Épique",
		Trainee = { C(140, 255, 60), C(40, 120, 20), 1.2 }, Aura = { Type = "bulles", Couleur = C(124, 255, 46), Debit = 10 },
		Lumiere = C(124, 255, 46), Impact = "poison", Hauteur = 0.95, Secousse = 0.4 },
	ViperSerpent = { Nom = "Couteau serpent", Equipe = "Vipères", Rarete = "Rare",
		Trainee = { C(122, 47, 208), C(71, 209, 31), 1.1 }, Aura = { Type = "fumee", Couleur = C(90, 30, 160), Debit = 5 },
		Impact = "poison", Hauteur = 1.15, Secousse = 0.3 },
	ViperVenin = { Nom = "Couteau venin", Equipe = "Vipères", Rarete = "Légendaire",
		Trainee = { C(124, 255, 46), C(122, 47, 208), 1.2 }, Aura = { Type = "gouttes", Couleur = C(124, 255, 46), Debit = 7 },
		Lumiere = C(124, 255, 46), Impact = "poison", Hauteur = 1.0, Secousse = 0.45 },
	ViperRoyal = { Nom = "Couteau royal", Equipe = "Vipères", Rarete = "Mythique",
		Trainee = { C(124, 255, 46), C(255, 215, 70), 1.3 }, Aura = { Type = "etincelles", Couleur = C(124, 255, 46), Debit = 10 },
		Lumiere = C(124, 255, 46), Impact = "couronne", Hauteur = 0.9, Secousse = 0.6 },
}

return Config
