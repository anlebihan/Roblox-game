--[[ LocalScript : ReplicatedFirst.EcranChargement      — TRIPLE HUNT —
     Écran de chargement cinématique (rendus 3D Blender en couches) :
       0,0 s  le ciel et le portail apparaissent (zoom lent, anneau qui tourne, rayons)
       0,5 s  le rocher monte depuis le bas
       1,4 s  les 3 couteaux géants tombent du ciel et se plantent : flash, secousse, poussière, son
       2,6 s  le logo arrive en rebondissant, reflet brillant qui passe dessus
       3,0 s  barre de chargement en forme de lame + astuces qui s'écrivent
       fin    « PRÊT ! » -> bouton JOUER qui pulse -> coup de lame qui tranche l'écran -> jeu
     Effets permanents : braises qui montent, étoiles qui scintillent, parallaxe à la souris.
     Images : dossier interface/images, importées dans Roblox puis enregistrées par InstallerImages.lua.
]]
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

----------------------------------------------------------------- RÉGLAGES
-- IDs des images : remplis automatiquement depuis ReplicatedFirst.ImagesInterface (InstallerImages.lua),
-- nom du fichier (sans .png) -> "rbxassetid://…"
local IMAGES = {}
local DECOUPE = { -- généré par exporter_images.py : { fichier, x, y, largeur, hauteur } en fraction de l'image
	Ciel = { { "chargement_ciel_1", 0.00000, 0.00000, 0.50208, 0.50370 }, { "chargement_ciel_2", 0.49792, 0.00000, 0.50208, 0.50370 }, { "chargement_ciel_3", 0.00000, 0.49630, 0.50208, 0.50370 }, { "chargement_ciel_4", 0.49792, 0.49630, 0.50208, 0.50370 } },
	Rocher = { { "chargement_rocher_1", 0.00000, 0.00000, 0.50208, 0.50370 }, { "chargement_rocher_2", 0.49792, 0.00000, 0.50208, 0.50370 }, { "chargement_rocher_3", 0.00000, 0.49630, 0.50208, 0.50370 }, { "chargement_rocher_4", 0.49792, 0.49630, 0.50208, 0.50370 } },
	CouteauRenard = { { "chargement_RenardLegendaire", 0.46302, 0.31296, 0.07396, 0.56759 } },
	CouteauPoule = { { "chargement_PouleRoyal", 0.16667, 0.47963, 0.10052, 0.45926 } },
	CouteauVipere = { { "chargement_ViperRoyal", 0.73906, 0.47500, 0.10677, 0.48704 } },
	OmbreRenard = { { "chargement_ombre_RenardLegendaire", 0.40937, 0.86481, 0.18385, 0.13519 } },
	OmbrePoule = { { "chargement_ombre_PouleRoyal", 0.09115, 0.91111, 0.20938, 0.08889 } },
	OmbreVipere = { { "chargement_ombre_ViperRoyal", 0.63385, 0.91944, 0.25729, 0.08056 } },
	Logo = { { "chargement_logo_final", 0.29688, 0.00185, 0.40781, 0.25648 } },
	LogoMasque = { { "chargement_logo_masque", 0.29688, 0.00185, 0.40781, 0.25648 } },
}
-- FIN DECOUPE
local SONS = {
	Musique = "",                                       -- ID d'une musique (Boîte à outils > Audio), vide = pas de musique
	Whoosh = "rbxasset://sounds/swordlunge.wav",
	Impact = "rbxasset://sounds/swordslash.wav",
	Etincelle = "rbxasset://sounds/electronicpingshort.wav",
	Lame = "rbxasset://sounds/unsheath.wav",
	Clic = "rbxasset://sounds/electronicpingshort.wav",
}
local ASTUCES = {
	"Le 🦊 Renard attrape la 🐔 Poule, la Poule attrape la 🐍 Vipère, la Vipère attrape le Renard !",
	"Appuie sur A pour esquiver : tu es invincible pendant le saut !",
	"Touche un coéquipier en prison pour le libérer.",
	"Dans ton camp, personne ne peut t'attraper.",
	"Enchaîne 3 coups pour un estoc qui va plus loin.",
	"Ouvre des caisses pour gagner des couteaux légendaires !",
}
do
	local ok, liste = pcall(function() return require(ReplicatedFirst:WaitForChild("ImagesInterface", 2)) end)
	if ok and type(liste) == "table" then IMAGES = liste end
end
local function img(nom) return IMAGES[nom] or "" end
local DUREE_MIN = 7          -- durée minimale de l'écran (s), pour profiter de l'intro
local TEXTE_PRET = "PRÊT !"
local COULEURS = {
	Color3.fromRGB(255, 70, 40), Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 120, 20),
	Color3.fromRGB(120, 255, 60), Color3.fromRGB(180, 90, 255),
}

----------------------------------------------------------------- démarrage
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
local joueur = Players.LocalPlayer
local playerGui = joueur:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

local function new(classe, props, parent)
	local o = Instance.new(classe)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local gui = new("ScreenGui", { Name = "EcranChargement", IgnoreGuiInset = true, ResetOnSpawn = false,
	DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local noir = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)

-- scène 16:9 qui couvre tout l'écran (comme un fond « cover »)
local scene = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, ClipsDescendants = false }, noir)
local function ajusterScene()
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local k = math.max(v.X / 1920, v.Y / 1080) * 1.04            -- marge pour la parallaxe / secousse
	scene.Size = UDim2.fromOffset(1920 * k, 1080 * k)
end
ajusterScene()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterScene) end

-- une couche = un cadre plein écran contenant ses morceaux d'image (voir DECOUPE)
local function couche(nom, cle, z, parent)
	local cadre = new("Frame", { Name = nom, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z }, parent or scene)
	for _, m in ipairs(DECOUPE[cle] or {}) do
		new("ImageLabel", { Name = m[1], Image = img(m[1]), BackgroundTransparency = 1, ZIndex = z, ImageTransparency = 1,
			Position = UDim2.fromScale(m[2], m[3]), Size = UDim2.fromScale(m[4], m[5]) }, cadre)
	end
	return cadre
end
local function transp(cadre, v)
	for _, i in ipairs(cadre:GetChildren()) do
		if i:IsA("ImageLabel") then i.ImageTransparency = v end
	end
end

local ciel = couche("Ciel", "Ciel", 1)
local PORTAIL = Vector2.new(0.5, 0.51)       -- centre du portail dans le rendu (fraction de l'image)
local rayons = new("ImageLabel", { Image = img("fx_rayons"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(PORTAIL.X, PORTAIL.Y), Size = UDim2.fromScale(0.75, 0.75 * 16 / 9), ZIndex = 2,
	ImageColor3 = Color3.fromRGB(190, 140, 255), ImageTransparency = 1 }, scene)
local anneau = new("ImageLabel", { Image = img("fx_anneau"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(PORTAIL.X, PORTAIL.Y), Size = UDim2.fromScale(0.42, 0.42 * 16 / 9), ZIndex = 2,
	ImageTransparency = 1 }, scene)
local etoiles = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, scene)
local rocher = couche("Rocher", "Rocher", 4)
local couteaux = {
	{ img = couche("Renard", "CouteauRenard", 5), ombre = couche("OmbreRenard", "OmbreRenard", 4), t = 1.4,
		impact = Vector2.new(0.5, 0.87), couleur = Color3.fromRGB(255, 120, 20) },
	{ img = couche("Poule", "CouteauPoule", 5), ombre = couche("OmbrePoule", "OmbrePoule", 4), t = 1.85,
		impact = Vector2.new(0.19, 0.92), couleur = Color3.fromRGB(255, 70, 40) },
	{ img = couche("Vipere", "CouteauVipere", 5), ombre = couche("OmbreVipere", "OmbreVipere", 4), t = 2.2,
		impact = Vector2.new(0.83, 0.94), couleur = Color3.fromRGB(120, 255, 60) },
}
local braises = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, scene)

-- logo (couche plein écran rendue dans la scène) + reflet ; il grossit autour de sa position
local LOGO = Vector2.new(0.5, 0.125)        -- centre du titre dans le rendu
local logoCadre = new("Frame", { AnchorPoint = LOGO, Position = UDim2.fromScale(LOGO.X, LOGO.Y),
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8 }, scene)
local logo = couche("Logo", "Logo", 8, logoCadre)
local reflet = couche("Reflet", "LogoMasque", 9, logoCadre)
local refletGrad = new("UIGradient", { Rotation = 20, Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }, reflet:FindFirstChildOfClass("ImageLabel") or reflet)
local logoEchelle = new("UIScale", { Scale = 0 }, logoCadre)

-- dégradé sombre en bas de l'écran (lisibilité de la barre)
local ombreBas = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.34),
	BackgroundColor3 = Color3.fromRGB(6, 3, 14), BackgroundTransparency = 1, ZIndex = 19 }, noir)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0.15) }) }, ombreBas)

-- HUD bas (hors scène, pour rester lisible sur mobile)
local bas = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1.3, 0),
	Size = UDim2.new(0.5, 0, 0.17, 0), BackgroundTransparency = 1, ZIndex = 20 }, noir)
new("UISizeConstraint", { MaxSize = Vector2.new(760, 140) }, bas)
local barreFond = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12),
	Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = Color3.fromRGB(14, 10, 32), ZIndex = 20 }, bas)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, barreFond)
new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(8, 5, 18) }, barreFond)
local barre = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 21,
	ClipsDescendants = true }, barreFond)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, barre)
new("UIGradient", { Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 50, 40)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 200, 30)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 120, 20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 240, 50)) }) }, barre)
local rayures = new("Frame", { Size = UDim2.fromScale(3, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
	ZIndex = 22 }, barre)
local rayGrad = new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new((function()
	local k = {}
	for i = 0, 20 do
		local x = i / 20
		k[#k + 1] = NumberSequenceKeypoint.new(x, (i % 2 == 0) and 0 or 1)
	end
	return k
end)()) }, rayures)
local brillance = new("Frame", { Size = UDim2.fromScale(1, 0.35), Position = UDim2.fromScale(0, 0.08),
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 23 }, barre)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, brillance)
local pct = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "0%", TextScaled = true,
	Font = Enum.Font.LuckiestGuy, TextColor3 = Color3.new(1, 1, 1), ZIndex = 24 }, barreFond)
new("UIStroke", { Thickness = 2.5, Color = Color3.new(0, 0, 0) }, pct)
new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.08, 0) }, pct)
local astuce = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(1, 0.22), BackgroundTransparency = 1, Text = "", TextScaled = true, Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(235, 230, 255), ZIndex = 20, RichText = true }, bas)
new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }, astuce)
local etat = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.1),
	Size = UDim2.fromScale(0.6, 0.2), BackgroundTransparency = 1, Text = "CHARGEMENT DE LA VALLÉE…", TextScaled = true,
	Font = Enum.Font.LuckiestGuy, TextColor3 = Color3.new(1, 1, 1), ZIndex = 20 }, bas)
new("UIStroke", { Thickness = 2.5, Color = Color3.new(0, 0, 0) }, etat)

-- bouton JOUER
local jouer = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78),
	Size = UDim2.fromScale(0.2, 0.11), BackgroundColor3 = Color3.new(1, 1, 1), Text = "",
	AutoButtonColor = false, Visible = false, ZIndex = 30 }, noir)
new("UIAspectRatioConstraint", { AspectRatio = 3.2 }, jouer)
new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, jouer)
new("UIStroke", { Thickness = 5, Color = Color3.fromRGB(8, 5, 18), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, jouer)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(130, 255, 120), Color3.fromRGB(30, 170, 70)) }, jouer)
local jouerTexte = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "▶ JOUER",
	TextScaled = true, Font = Enum.Font.LuckiestGuy, TextColor3 = Color3.new(1, 1, 1), ZIndex = 31 }, jouer)
new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.1, 0) }, jouerTexte)
new("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0) }, jouerTexte)
local jouerEchelle = new("UIScale", { Scale = 0 }, jouer)
local passer = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(150, 46), BackgroundColor3 = Color3.fromRGB(90, 96, 120), Text = "PASSER ⏭", TextScaled = true,
	Font = Enum.Font.LuckiestGuy, TextColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 30, AutoButtonColor = true }, noir)
new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, passer)
new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(8, 5, 18), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, passer)
new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.12, 0) }, passer)

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
	ZIndex = 40 }, noir)
local lame = new("ImageLabel", { Image = img("fx_lame"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(2.2, 0.35), Position = UDim2.fromScale(-1, 0.5), Rotation = -18, ZIndex = 41,
	ImageColor3 = Color3.fromRGB(255, 240, 200), ImageTransparency = 0 }, noir)

----------------------------------------------------------------- sons
local function son(id, volume, hauteur, boucle)
	if not id or id == "" then return nil end
	local s = new("Sound", { SoundId = id, Volume = volume or 0.6, PlaybackSpeed = hauteur or 1, Looped = boucle or false }, gui)
	s:Play()
	if not boucle then task.delay(5, function() s:Destroy() end) end
	return s
end
local musique = son(SONS.Musique, 0, 1, true)

----------------------------------------------------------------- courbes
local function seg(t, t0, t1) return math.clamp((t - t0) / (t1 - t0), 0, 1) end
local E = {
	quadOut = function(x) return 1 - (1 - x) ^ 2 end,
	quadIn = function(x) return x * x end,
	quartOut = function(x) return 1 - (1 - x) ^ 4 end,
	sine = function(x) return 0.5 - math.cos(math.pi * x) / 2 end,
	backOut = function(x) local c = 1.9; return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2 end,
}

----------------------------------------------------------------- particules
local rnd = Random.new(7)
local parts = {}
local function particule(parent, props)
	local p = new("ImageLabel", { Image = props.image or img("fx_braise"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(props.taille, props.taille * 16 / 9), ImageColor3 = props.couleur or Color3.new(1, 1, 1),
		ImageTransparency = 1, ZIndex = props.z or 6, Rotation = props.rot or 0 }, parent)
	props.obj, props.age = p, 0
	parts[#parts + 1] = props
end
local impacts = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, scene)   -- fissures (sur le rocher)
local fissures = {}
-- impact d'un couteau : fissure lumineuse + éclats de roche + poussière
local function impactRoche(pos, couleur)
	local f = new("ImageLabel", { Image = img("fx_fissure"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(pos.X, pos.Y + 0.005), Size = UDim2.fromScale(0, 0), ImageColor3 = couleur, ZIndex = 4 }, impacts)
	-- lumière de l'impact sur le rocher (couleur de l'équipe), qui s'éteint
	local l = new("ImageLabel", { Image = img("fx_braise"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(pos.X, pos.Y), Size = UDim2.fromScale(0.34, 0.34 * 0.55 * 16 / 9), ImageColor3 = couleur,
		ImageTransparency = 0.2, ZIndex = 4 }, impacts)
	fissures[#fissures + 1] = { obj = f, t = 0, pos = pos, lumiere = l }
	for i = 1, 14 do
		local a = rnd:NextNumber(-math.pi * 0.95, -math.pi * 0.05)      -- vers le haut, en éventail
		local v = rnd:NextNumber(0.35, 0.8)
		particule(braises, { image = img("fx_eclat" .. ((i - 1) % 6 + 1)), x = pos.X, y = pos.Y,
			vx = math.cos(a) * v * 0.7, vy = math.sin(a) * v, g = 2.4, vie = rnd:NextNumber(0.9, 1.3),
			taille = rnd:NextNumber(0.018, 0.05), rot = rnd:NextNumber(0, 360), vrot = rnd:NextNumber(-600, 600),
			opaque = true, z = 6 })
	end
	for _ = 1, 6 do
		particule(braises, { image = img("fx_fumee"), x = pos.X + rnd:NextNumber(-0.03, 0.03), y = pos.Y - 0.01,
			vx = rnd:NextNumber(-0.06, 0.06), vy = -rnd:NextNumber(0.02, 0.07), g = 0, vie = rnd:NextNumber(1.0, 1.5),
			taille = rnd:NextNumber(0.05, 0.08), croissance = 0.09, couleur = Color3.fromRGB(150, 130, 190):Lerp(couleur, 0.25),
			rot = rnd:NextNumber(0, 360), vrot = rnd:NextNumber(-40, 40), fumee = true, z = 6 })
	end
end
local function poussiere(pos)
	for _ = 1, 14 do
		local a = rnd:NextNumber(math.pi * 1.05, math.pi * 1.95)
		local v = rnd:NextNumber(0.08, 0.22)
		particule(braises, { x = pos.X, y = pos.Y, vx = math.cos(a) * v, vy = math.sin(a) * v * 0.9, g = 0.35,
			vie = rnd:NextNumber(0.5, 0.9), taille = rnd:NextNumber(0.012, 0.03), couleur = Color3.fromRGB(200, 180, 220), z = 6 })
	end
	for _ = 1, 8 do
		local a = rnd:NextNumber(0, math.pi * 2)
		particule(braises, { x = pos.X, y = pos.Y - 0.02, vx = math.cos(a) * 0.3, vy = math.sin(a) * 0.3 - 0.15, g = 0.6,
			vie = 0.5, taille = 0.012, couleur = COULEURS[rnd:NextInteger(1, #COULEURS)], image = img("fx_etincelle"), z = 7 })
	end
end
for _ = 1, 26 do
	local e = new("ImageLabel", { Image = img("fx_etincelle"), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(rnd:NextNumber(0.02, 0.98), rnd:NextNumber(0.02, 0.5)),
		Size = UDim2.fromScale(0.008, 0.008 * 16 / 9), ImageTransparency = 1, ZIndex = 2 }, etoiles)
	e:SetAttribute("phase", rnd:NextNumber(0, 6.28))
	e:SetAttribute("vitesse", rnd:NextNumber(1.5, 4))
end

----------------------------------------------------------------- chargement réel
local progresReel, jeuCharge = 0, false
task.spawn(function()
	pcall(function() ContentProvider:PreloadAsync({ ciel, rocher, logoCadre, anneau, rayons }) end)
	if not game:IsLoaded() then game.Loaded:Wait() end
	local liste = {}
	for _, racine in ipairs({ game:GetService("ReplicatedStorage"), workspace, game:GetService("SoundService") }) do
		for _, d in ipairs(racine:GetDescendants()) do
			if d:IsA("Decal") or d:IsA("Texture") or d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("MeshPart")
				or d:IsA("Sound") or d:IsA("Animation") or d:IsA("SpecialMesh") or d:IsA("SurfaceAppearance") then
				liste[#liste + 1] = d
			end
		end
	end
	local paquet = 40
	local n = math.max(1, math.ceil(#liste / paquet))
	for i = 1, n do
		local morceau = table.move(liste, (i - 1) * paquet + 1, math.min(i * paquet, #liste), 1, {})
		pcall(function() ContentProvider:PreloadAsync(morceau) end)
		progresReel = i / n
	end
	progresReel, jeuCharge = 1, true
end)

----------------------------------------------------------------- parallaxe
local souris = Vector2.zero
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local v = workspace.CurrentCamera.ViewportSize
		souris = Vector2.new(input.Position.X / v.X - 0.5, input.Position.Y / v.Y - 0.5)
	end
end)
local parallaxe = Vector2.zero

----------------------------------------------------------------- boucle principale
local t0 = os.clock()
local affiche, pretDepuis, sortie = 0, nil, nil
local astuceIndex, astuceDebut = 0, 0
local impactsJoues = {}
local secousse = 0
local prochaineBraise = 0
local dernierReflet = 3.2
local connexion

local function quitter()
	if sortie then return end
	sortie = os.clock()
	son(SONS.Lame, 0.8, 0.9)
	son(SONS.Impact, 0.6, 0.7)
end
jouer.MouseButton1Click:Connect(function()
	son(SONS.Clic, 0.5, 1.4)
	quitter()
end)
passer.MouseButton1Click:Connect(function()
	son(SONS.Clic, 0.4, 1.2)
	if jeuCharge then quitter() else DUREE_MIN = 0 end
end)
UserInputService.InputBegan:Connect(function(input)
	if jouer.Visible and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA) then quitter() end
end)

local function positionCouche(img, dx, dy, k)
	img.Position = UDim2.fromScale(0.5 + dx + parallaxe.X * k, 0.5 + dy + parallaxe.Y * k)
end

connexion = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	parallaxe = parallaxe:Lerp(-souris * 0.02, math.min(1, dt * 4))

	-- secousse (après les impacts)
	secousse = math.max(0, secousse - dt * 4)
	local sx = (rnd:NextNumber() - 0.5) * secousse * 0.02
	local sy = (rnd:NextNumber() - 0.5) * secousse * 0.02
	scene.Position = UDim2.fromScale(0.5 + sx, 0.5 + sy)

	-- ciel : fondu + zoom lent
	transp(ciel, 1 - E.sine(seg(t, 0, 0.9)))
	local zoom = 1.1 - 0.1 * E.quadOut(seg(t, 0, 12))
	ciel.Size = UDim2.fromScale(zoom, zoom)
	positionCouche(ciel, 0, 0, 0.25)

	-- portail : anneau qui tourne et pulse, rayons
	local a = E.backOut(seg(t, 0.4, 1.3))
	anneau.Size = UDim2.fromScale(0.42 * a, 0.42 * a * 16 / 9)
	anneau.Rotation = t * 25
	anneau.ImageTransparency = 1 - seg(t, 0.4, 0.9) * (0.22 + 0.1 * math.sin(t * 3))
	anneau.ImageColor3 = Color3.fromHSV((0.75 + 0.06 * math.sin(t * 0.7)) % 1, 0.55, 1)
	rayons.Rotation = -t * 6
	rayons.ImageTransparency = 1 - seg(t, 0.6, 1.6) * (0.14 + 0.05 * math.sin(t * 2))
	rayons.Position = UDim2.fromScale(PORTAIL.X + parallaxe.X * 0.25, PORTAIL.Y + parallaxe.Y * 0.25)
	anneau.Position = rayons.Position

	-- étoiles qui scintillent
	for _, e in ipairs(etoiles:GetChildren()) do
		local v = 0.5 + 0.5 * math.sin(t * e:GetAttribute("vitesse") + e:GetAttribute("phase"))
		e.ImageTransparency = 1 - seg(t, 0.3, 1.2) * v * 0.9
	end

	-- rocher qui monte
	local r = E.quartOut(seg(t, 0.5, 1.3))
	transp(rocher, 1 - seg(t, 0.5, 0.8))
	positionCouche(rocher, 0, 0.3 * (1 - r), 0.6)

	-- couteaux qui tombent et se plantent
	for i, c in ipairs(couteaux) do
		local chute = seg(t, c.t - 0.3, c.t)
		transp(c.img, chute > 0 and 0 or 1)
		transp(c.ombre, 1 - E.quadIn(seg(chute, 0.75, 1)))      -- l'ombre se forme au contact
		positionCouche(c.ombre, 0, 0, 0.6)
		positionCouche(c.img, 0, -1.1 * (1 - E.quadIn(chute)), 0.8)
		if chute > 0 and not impactsJoues[i .. "w"] then
			impactsJoues[i .. "w"] = true
			son(SONS.Whoosh, 0.5, 1.3 + i * 0.1)
		end
		if chute >= 1 and not impactsJoues[i] then
			impactsJoues[i] = true
			secousse = (i == 1) and 1 or 0.7
			flash.BackgroundTransparency = (i == 1) and 0.55 or 0.72
			son(SONS.Impact, 0.9, 0.55 + i * 0.08)
			son(SONS.Whoosh, 0.35, 0.45)                                  -- grondement de roche
			poussiere(c.impact)
			impactRoche(c.impact, c.couleur)
		end
	end
	flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 5)
	for _, f in ipairs(fissures) do
		f.t += dt
		local g = E.quartOut(seg(f.t, 0, 0.14))
		f.obj.Size = UDim2.fromScale(0.15 * g, 0.15 * 0.42 * 16 / 9 * g)
		f.obj.ImageTransparency = 0.05 + 0.4 * seg(f.t, 0.15, 1.2) + 0.08 * math.sin(t * 4 + f.pos.X * 10)
		f.obj.Position = UDim2.fromScale(f.pos.X + parallaxe.X * 0.6, f.pos.Y + 0.005 + parallaxe.Y * 0.6)
		f.lumiere.ImageTransparency = 0.2 + 0.8 * E.quadOut(seg(f.t, 0.05, 0.9))
		f.lumiere.Position = f.obj.Position
	end

	-- logo
	local l = seg(t, 2.6, 3.2)
	logoEchelle.Scale = E.backOut(l)
	logoCadre.Rotation = -8 * (1 - E.quartOut(l))
	transp(logo, l > 0 and 0 or 1)
	logoCadre.Position = UDim2.fromScale(LOGO.X + parallaxe.X * 1.2, LOGO.Y + parallaxe.Y * 1.2 + 0.006 * math.sin(t * 1.6))
	if l > 0 and not impactsJoues.logo then impactsJoues.logo = true; son(SONS.Etincelle, 0.5, 0.8) end
	-- reflet qui passe toutes les 4 s
	if t > dernierReflet then dernierReflet = t + 4 end
	local rf = 1 - seg(dernierReflet - t, 3.3, 4)                 -- 0 -> 1 pendant 0,7 s
	transp(reflet, (t > 3.2 and rf > 0 and rf < 1) and 0.2 or 1)
	refletGrad.Offset = Vector2.new(-1 + 2 * rf, 0)

	-- braises qui montent (en continu)
	if t > 0.8 and t > prochaineBraise then
		prochaineBraise = t + 0.07
		particule(braises, { x = rnd:NextNumber(0.05, 0.95), y = 1.02, vx = 0, vy = -rnd:NextNumber(0.12, 0.25), g = 0,
			vie = rnd:NextNumber(2.5, 4.5), taille = rnd:NextNumber(0.005, 0.013), couleur = COULEURS[rnd:NextInteger(1, #COULEURS)],
			onde = rnd:NextNumber(0, 6.28), z = 6 })
	end
	for i = #parts, 1, -1 do
		local p = parts[i]
		p.age += dt
		local k = p.age / p.vie
		if k >= 1 then
			p.obj:Destroy(); table.remove(parts, i)
		else
			p.vy += (p.g or 0) * dt
			p.x += (p.vx + (p.onde and 0.02 * math.cos(t * 2 + p.onde) or 0)) * dt
			p.y += p.vy * dt
			p.obj.Position = UDim2.fromScale(p.x + parallaxe.X * 0.9, p.y + parallaxe.Y * 0.9)
			if p.vrot then p.obj.Rotation += p.vrot * dt end
			if p.croissance then
				local tl = p.taille + p.croissance * p.age
				p.obj.Size = UDim2.fromScale(tl, tl * 16 / 9)
			end
			if p.opaque then
				p.obj.ImageTransparency = math.clamp((k - 0.7) / 0.3, 0, 1)            -- éclats : pleins puis fondu
			elseif p.fumee then
				p.obj.ImageTransparency = 0.35 + 0.65 * k
			else
				p.obj.ImageTransparency = 1 - math.sin(math.pi * math.min(1, k * 1.2)) * 0.95
			end
		end
	end

	-- bas de l'écran : barre + astuces
	bas.Position = UDim2.new(0.5, 0, 1 + 0.3 * (1 - E.backOut(seg(t, 3.0, 3.6))), -10)
	ombreBas.BackgroundTransparency = 1 - seg(t, 2.8, 3.4)
	local cible = math.min(progresReel, (t - 3) / math.max(DUREE_MIN - 3, 0.1))
	cible = math.clamp(cible, 0, 1)
	affiche += (cible - affiche) * math.min(1, dt * 5)
	if cible >= 1 and affiche > 0.995 then affiche = 1 end
	barre.Size = UDim2.fromScale(math.max(affiche, 0.04), 1)
	rayGrad.Offset = Vector2.new(-((t * 0.15) % 0.1), 0)
	pct.Text = math.floor(affiche * 100 + 0.5) .. "%"
	if t > 3.2 then
		if astuceIndex == 0 or t - astuceDebut > 5 then
			astuceIndex = astuceIndex % #ASTUCES + 1
			astuceDebut = t
			astuce.Text = "💡 " .. ASTUCES[astuceIndex]
		end
		astuce.MaxVisibleGraphemes = math.floor((t - astuceDebut) * 45)
	end

	-- prêt -> bouton JOUER
	if affiche >= 1 and jeuCharge and not pretDepuis then
		pretDepuis = t
		etat.Text = TEXTE_PRET
		jouer.Visible = true
		son(SONS.Etincelle, 0.6, 1.2)
	end
	if pretDepuis then
		local b = seg(t, pretDepuis, pretDepuis + 0.5)
		jouerEchelle.Scale = E.backOut(b) * (1 + 0.05 * math.sin((t - pretDepuis) * 6))
		etat.TextColor3 = Color3.fromHSV(0.3, 0.5 + 0.3 * math.sin(t * 6), 1)
	end
	passer.Visible = t > 2.5 and not pretDepuis and not sortie

	-- musique : fondu d'entrée
	if musique then musique.Volume = 0.45 * seg(t, 0, 2) * (sortie and (1 - seg(os.clock() - sortie, 0, 0.9)) or 1) end

	-- sortie : coup de lame + zoom + fondu
	if sortie then
		local s = os.clock() - sortie
		lame.Position = UDim2.fromScale(-1 + 3 * E.quartOut(seg(s, 0, 0.35)), 0.5)
		if s > 0.15 and s < 0.2 then flash.BackgroundTransparency = 0 end
		local f = E.quadIn(seg(s, 0.2, 0.9))
		noir.BackgroundTransparency = f
		for _, o in ipairs(noir:GetDescendants()) do
			if o:IsA("ImageLabel") then o.ImageTransparency = math.max(o.ImageTransparency, f)
			elseif o:IsA("TextLabel") or o:IsA("TextButton") then o.TextTransparency = f; o.BackgroundTransparency = math.max(o.BackgroundTransparency, f)
			elseif o:IsA("Frame") then o.BackgroundTransparency = math.max(o.BackgroundTransparency, f)
			elseif o:IsA("UIStroke") then o.Transparency = f end
		end
		local z = 1 + 0.25 * f
		local v = workspace.CurrentCamera.ViewportSize
		local k = math.max(v.X / 1920, v.Y / 1080) * 1.04 * z
		scene.Size = UDim2.fromOffset(1920 * k, 1080 * k)
		if s > 0.95 then
			connexion:Disconnect()
			pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
			gui:Destroy()
		end
	end
end)
