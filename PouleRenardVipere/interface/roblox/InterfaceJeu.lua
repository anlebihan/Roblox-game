--[[ LocalScript : StarterPlayer.StarterPlayerScripts.InterfaceJeu      — TRIPLE HUNT —
     Démarre toute l'interface de jeu (style de l'écran de chargement) :
       ReplicatedStorage.Interface.Style      style, textures, sons
       ReplicatedStorage.Interface.Donnees    pont avec le jeu (pièces, niveau, couteaux, caisses, manche…)
       ReplicatedStorage.Interface.HUD        lobby + manche + boutons mobiles + fil + alertes
       ReplicatedStorage.Interface.Panneaux   boutique (caisses / couteaux / pièces), paramètres, quêtes, cadeau, classement
       ReplicatedStorage.Interface.Ouverture  ouverture animée des caisses
     Toute l'interface est dessinée pour 1280x720 puis mise à l'échelle (mobile, PC, console).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local joueur = Players.LocalPlayer
local dossier = ReplicatedStorage:WaitForChild("Interface")
local S = require(dossier:WaitForChild("Style"))
local D = require(dossier:WaitForChild("Donnees"))
local new = S.new

local gui = new("ScreenGui", { Name = "InterfaceJeu", ResetOnSpawn = false, IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, joueur:WaitForChild("PlayerGui"))

-- racine en « pixels de maquette » (1280x720) mise à l'échelle de l'écran
local racine = new("Frame", { Name = "Racine", BackgroundTransparency = 1 }, gui)
local echelle = new("UIScale", {}, racine)
local function ajuster()
	local v = gui.AbsoluteSize
	if v.X < 10 then return end
	local k = math.clamp(math.min(v.X / 1280, v.Y / 720), 0.55, 1.6)
	echelle.Scale = k
	racine.Size = UDim2.fromOffset(v.X / k, v.Y / k)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajuster)
ajuster()

-- couches
local coucheHUD = new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, racine)
local voile = new("Frame", { Name = "Voile", BackgroundColor3 = Color3.fromRGB(8, 4, 20), BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false }, racine)
local couchePanneaux = new("Frame", { Name = "Panneaux", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 }, racine)
local coucheOverlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 80 }, racine)

----------------------------------------------------------------- contexte partagé
local Ctx = {
	S = S, D = D, joueur = joueur, gui = gui, racine = racine, echelle = echelle,
	HUD = coucheHUD, Panneaux = couchePanneaux, Overlay = coucheOverlay, Voile = voile,
}

-- position (en pixels de maquette) du centre d'un élément
function Ctx.Centre(o)
	local k = echelle.Scale
	local p = (o.AbsolutePosition + o.AbsoluteSize / 2 - racine.AbsolutePosition) / k
	return UDim2.fromOffset(p.X, p.Y)
end

-- anneau qui s'élargit (effet de clic / d'impact)
function Ctx.Onde(parent, position, couleur, taille, duree)
	local a = new("ImageLabel", { BackgroundTransparency = 1, Image = S.Image("fx_anneau"), ImageColor3 = couleur or S.C.Violet,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(20, 20), ImageTransparency = 0.1,
		ZIndex = 95 }, parent)
	S.Tween(a, duree or 0.45, { Size = UDim2.fromOffset(taille or 220, taille or 220), ImageTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay((duree or 0.45) + 0.05, function() a:Destroy() end)
end

-- étincelles qui jaillissent d'un point
function Ctx.Etincelles(parent, position, couleur, n)
	for _ = 1, n or 10 do
		local e = new("ImageLabel", { BackgroundTransparency = 1, Image = S.Image("fx_etincelle"), ImageColor3 = couleur or S.C.Or,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(18, 18), ZIndex = 96 }, parent)
		local a = math.random() * math.pi * 2
		local d = 60 + math.random() * 120
		S.Tween(e, 0.6 + math.random() * 0.3, { Position = position + UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d),
			ImageTransparency = 1, Rotation = math.random(-180, 180), Size = UDim2.fromOffset(6, 6) }, Enum.EasingStyle.Quart)
		task.delay(1, function() e:Destroy() end)
	end
end

----------------------------------------------------------------- fenêtres (ouverture depuis le bouton cliqué)
local fenetreOuverte, sourceOuverte
local fenetres = {}

function Ctx.CreerFenetre(nom, taille)
	local f = new("CanvasGroup", { Name = nom, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(taille.X, taille.Y), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 50 }, couchePanneaux)
	new("UIScale", { Scale = 1 }, f)
	S.Skin(f, "skin_panneau", { Size = UDim2.fromScale(1, 1), ZIndex = 50 }, 1)
	fenetres[nom] = f
	return f
end

function Ctx.Ouvrir(nom, source, ...)
	local f = fenetres[nom]
	if not f then return end
	if fenetreOuverte == f then return end
	if fenetreOuverte then Ctx.Fermer(true) end
	fenetreOuverte, sourceOuverte = f, source
	if Ctx["AvantOuverture_" .. nom] then Ctx["AvantOuverture_" .. nom](...) end
	local depart = source and Ctx.Centre(source) or UDim2.fromScale(0.5, 0.5)
	voile.Visible = true
	S.Tween(voile, 0.25, { BackgroundTransparency = 0.45 })
	f.Visible = true
	f.Position = depart
	f.UIScale.Scale = 0.2
	f.Rotation = -4
	f.GroupTransparency = 1
	S.Tween(f, 0.42, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0, GroupTransparency = 0 }, Enum.EasingStyle.Back)
	S.Tween(f.UIScale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
	if source then Ctx.Onde(racine, depart, S.C.Violet, 260, 0.5) end
	S.Son("Ouvrir")
	if Ctx.HUDMasquer then Ctx.HUDMasquer(true) end
end

function Ctx.Fermer(rapide)
	local f, src = fenetreOuverte, sourceOuverte
	if not f then return end
	fenetreOuverte, sourceOuverte = nil, nil
	local cible = (src and src.Parent) and Ctx.Centre(src) or UDim2.fromScale(0.5, 0.5)
	local t = rapide and 0.12 or 0.25
	S.Tween(f, t, { Position = cible, GroupTransparency = 1, Rotation = 3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	S.Tween(f.UIScale, t, { Scale = 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if not rapide then
		S.Tween(voile, 0.25, { BackgroundTransparency = 1 })
		S.Son("Fermer")
		if Ctx.HUDMasquer then Ctx.HUDMasquer(false) end
	end
	task.delay(t + 0.02, function()
		if fenetreOuverte ~= f then f.Visible = false end
		if not fenetreOuverte then voile.Visible = false end
	end)
end

function Ctx.FenetreOuverte() return fenetreOuverte end

-- lettre affichée pour une touche (suit le clavier : la touche « Q » d'un QWERTY s'affiche « A » sur un AZERTY)
function Ctx.NomTouche(nom)
	local ok, code = pcall(function() return Enum.KeyCode[nom] end)
	if not ok or not code then return tostring(nom) end
	local ok2, txt = pcall(function() return game:GetService("UserInputService"):GetStringForKeyCode(code) end)
	if ok2 and txt and txt ~= "" then return string.upper(txt) end
	return code.Name
end

-- bouton X standard
function Ctx.BoutonFermer(fenetre)
	local b = S.BoutonSkin(fenetre, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 16), Size = UDim2.fromOffset(52, 52),
		ZIndex = 60 }, "X", "rouge", function() Ctx.Fermer() end)
	return b
end

-- Échap / bouton B de la manette : ferme la fenêtre
game:GetService("UserInputService").InputBegan:Connect(function(input, traite)
	if (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) and fenetreOuverte then
		Ctx.Fermer()
	end
end)

----------------------------------------------------------------- modules
local Ouverture = require(dossier:WaitForChild("Ouverture"))
local Panneaux = require(dossier:WaitForChild("Panneaux"))
local HUD = require(dossier:WaitForChild("HUD"))
Ouverture.Init(Ctx)
Panneaux.Init(Ctx)
HUD.Init(Ctx)

-- boucle commune (animations continues)
RunService.RenderStepped:Connect(function(dt)
	if Ctx.Tick then
		for _, f in ipairs(Ctx.Tick) do f(dt) end
	end
end)
