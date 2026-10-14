--[[ ModuleScript : ReplicatedStorage.Interface.Style          — TRIPLE HUNT —
     Style « esport » de l'interface : verre violet sombre, coins biseautés (textures 9-slice),
     liserés néon fins, polices Montserrat (titres) et Oswald (étiquettes), icônes 3D Blender,
     reflets qui balaient les boutons, sons d'interface.
]]
local TweenService = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local SoundService = game:GetService("SoundService")

local S = {}

----------------------------------------------------------------- couleurs
S.C = {
	Encre = Color3.fromRGB(8, 5, 18),
	Fond = Color3.fromRGB(12, 6, 28),
	Violet = Color3.fromRGB(184, 150, 255),
	Or = Color3.fromRGB(255, 210, 63),
	Texte = Color3.fromRGB(239, 233, 255),
	Doux = Color3.fromRGB(185, 172, 223),
	Poule = Color3.fromRGB(255, 90, 60),
	Renard = Color3.fromRGB(255, 140, 30),
	Vipere = Color3.fromRGB(120, 240, 60),
	Vert = Color3.fromRGB(40, 190, 80),
	Rouge = Color3.fromRGB(255, 70, 70),
	Cyan = Color3.fromRGB(79, 195, 255),
}
S.Equipes = {
	Poules = { Nom = "POULES", Un = "POULE", Couleur = S.C.Poule, Cible = "Vipères", Menace = "Renards" },
	Renards = { Nom = "RENARDS", Un = "RENARD", Couleur = S.C.Renard, Cible = "Poules", Menace = "Vipères" },
	["Vipères"] = { Nom = "VIPÈRES", Un = "VIPÈRE", Couleur = S.C.Vipere, Cible = "Renards", Menace = "Poules" },
}
S.Raretes = {
	Commun = { Couleur = Color3.fromRGB(168, 179, 196), Fond = Color3.fromRGB(58, 66, 86), Ordre = 1 },
	Rare = { Couleur = Color3.fromRGB(63, 164, 255), Fond = Color3.fromRGB(18, 58, 112), Ordre = 2 },
	["Épique"] = { Couleur = Color3.fromRGB(178, 92, 255), Fond = Color3.fromRGB(62, 20, 108), Ordre = 3 },
	["Légendaire"] = { Couleur = Color3.fromRGB(255, 178, 26), Fond = Color3.fromRGB(110, 66, 0), Ordre = 4 },
	Mythique = { Couleur = Color3.fromRGB(255, 63, 164), Fond = Color3.fromRGB(110, 14, 64), Ordre = 5 },
}

----------------------------------------------------------------- polices
local function police(famille, poids, style, secours)
	local ok, f = pcall(Font.new, "rbxasset://fonts/families/" .. famille .. ".json", poids, style)
	return ok and f or Font.fromEnum(secours)
end
S.PoliceTitre = police("Montserrat", Enum.FontWeight.Black, Enum.FontStyle.Italic, Enum.Font.GothamBlack)
S.PoliceLabel = police("Oswald", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal, Enum.Font.Oswald)
S.PoliceCorps = police("Oswald", Enum.FontWeight.Regular, Enum.FontStyle.Normal, Enum.Font.Oswald)

----------------------------------------------------------------- images
local images = {}
pcall(function()
	local m = ReplicatedFirst:WaitForChild("ImagesInterface", 5)
	if m then images = require(m) end
end)
function S.Image(nom)
	if not nom or nom == "" then return "" end
	if string.find(nom, "rbxasset") then return nom end
	return images[nom] or ""
end

-- textures 9-slice : nom -> SliceCenter (voir generer_skins.py)
S.Slices = {
	skin_panneau = Rect.new(36, 36, 220, 220), skin_tuile = Rect.new(30, 30, 162, 162), skin_tuile_or = Rect.new(30, 30, 162, 162),
	skin_ligne = Rect.new(18, 18, 238, 78), skin_bouton_vert = Rect.new(24, 24, 168, 72), skin_bouton_or = Rect.new(24, 24, 168, 72),
	skin_bouton_rouge = Rect.new(24, 24, 168, 72), skin_bouton_violet = Rect.new(24, 24, 168, 72), skin_bouton_sombre = Rect.new(24, 24, 168, 72),
	skin_onglet = Rect.new(30, 10, 162, 54), skin_onglet_actif = Rect.new(30, 10, 162, 54),
}

----------------------------------------------------------------- sons
S.Sons = {
	Clic = { "rbxasset://sounds/electronicpingshort.wav", 1.8, 0.3 },
	Survol = { "rbxasset://sounds/electronicpingshort.wav", 2.6, 0.08 },
	Ouvrir = { "rbxasset://sounds/swordlunge.wav", 1.4, 0.35 },
	Fermer = { "rbxasset://sounds/swordlunge.wav", 1.9, 0.25 },
	Tic = { "rbxasset://sounds/electronicpingshort.wav", 2.8, 0.15 },
	Gain = { "rbxasset://sounds/electronicpingshort.wav", 1.1, 0.6 },
	Lame = { "rbxasset://sounds/unsheath.wav", 1.0, 0.6 },
	Impact = { "rbxasset://sounds/swordslash.wav", 0.6, 0.5 },
	Erreur = { "rbxasset://sounds/swordslash.wav", 0.5, 0.3 },
}
S.VolumeEffets = 1
local dossierSons
function S.Son(nom, hauteur, volume)
	local d = S.Sons[nom]
	if not d then return end
	if not dossierSons then
		dossierSons = Instance.new("Folder")
		dossierSons.Name = "SonsInterface"
		dossierSons.Parent = SoundService
	end
	local s = Instance.new("Sound")
	s.SoundId = d[1]
	s.PlaybackSpeed = (hauteur or d[2]) * (0.97 + math.random() * 0.06)
	s.Volume = (volume or d[3]) * S.VolumeEffets
	local groupe = SoundService:FindFirstChild("Effets")
	if groupe and groupe:IsA("SoundGroup") then s.SoundGroup = groupe end
	s.Parent = dossierSons
	s:Play()
	task.delay(3, function() s:Destroy() end)
end

----------------------------------------------------------------- outils
function S.new(classe, props, parent)
	local o = Instance.new(classe)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local new = S.new

function S.Tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- image 9-slice
function S.Skin(parent, nom, props, echelleSlice)
	local i = new("ImageLabel", { Name = nom, BackgroundTransparency = 1, Image = S.Image(nom), ScaleType = Enum.ScaleType.Slice,
		SliceCenter = S.Slices[nom] or Rect.new(24, 24, 72, 72), SliceScale = echelleSlice or 0.7 }, parent)
	for k, v in pairs(props or {}) do i[k] = v end
	return i
end

function S.Texte(parent, props, genre)
	local t = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = S.C.Texte, TextScaled = true, RichText = true,
		FontFace = (genre == "titre" or genre == "chiffre") and S.PoliceTitre or (genre == "corps" and S.PoliceCorps or S.PoliceLabel) }, parent)
	for k, v in pairs(props) do
		if k ~= "Contour" then t[k] = v end
	end
	if props.Contour ~= false then
		new("UIStroke", { Color = S.C.Encre, Thickness = 1.4, Transparency = 0.35 }, t)
	end
	return t
end

function S.Icone(parent, nom, props)
	local i = new("ImageLabel", { BackgroundTransparency = 1, Image = S.Image(nom), ScaleType = Enum.ScaleType.Fit }, parent)
	for k, v in pairs(props or {}) do i[k] = v end
	return i
end

-- reflet diagonal qui balaie un élément (à appeler au survol ou en boucle)
function S.Reflet(parent)
	local clip = parent:FindFirstChild("_Reflet")
	if not clip then
		clip = new("Frame", { Name = "_Reflet", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
			ClipsDescendants = true, ZIndex = parent.ZIndex + 5 }, parent)
		new("ImageLabel", { Name = "B", BackgroundTransparency = 1, Image = S.Image("fx_brillance"), ImageTransparency = 0.45,
			Size = UDim2.fromScale(0.9, 1.6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.6, 0.5),
			ZIndex = parent.ZIndex + 5 }, clip)
	end
	local b = clip.B
	b.Position = UDim2.fromScale(-0.6, 0.5)
	S.Tween(b, 0.55, { Position = UDim2.fromScale(1.6, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
end

-- zone cliquable animée (survol : grossit + reflet ; appui : s'enfonce) ; rappel(bouton)
function S.Bouton(parent, props, rappel)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Selectable = true }, parent)
	for k, v in pairs(props) do b[k] = v end
	local echelle = new("UIScale", { Scale = 1 }, b)
	local survol = false
	b.MouseEnter:Connect(function()
		survol = true
		S.Tween(echelle, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
		S.Reflet(b)
		S.Son("Survol")
	end)
	b.MouseLeave:Connect(function() survol = false; S.Tween(echelle, 0.18, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() S.Tween(echelle, 0.07, { Scale = 0.92 }) end)
	b.MouseButton1Up:Connect(function() S.Tween(echelle, 0.25, { Scale = survol and 1.06 or 1 }, Enum.EasingStyle.Back) end)
	b.SelectionGained:Connect(function() S.Tween(echelle, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back) end)
	b.SelectionLost:Connect(function() S.Tween(echelle, 0.18, { Scale = 1 }) end)
	if rappel then
		b.Activated:Connect(function()
			S.Son("Clic")
			rappel(b)
		end)
	end
	return b, echelle
end

-- bouton texturé : skin = "vert" | "or" | "rouge" | "violet" | "sombre"
function S.BoutonSkin(parent, props, texte, skin, rappel, sousTexte)
	local b = S.Bouton(parent, props, rappel)
	S.Skin(b, "skin_bouton_" .. (skin or "sombre"), { Size = UDim2.fromScale(1, 1), ZIndex = b.ZIndex })
	local fonce = (skin == "or")
	local t = S.Texte(b, { Name = "Texte", Size = UDim2.new(1, -24, sousTexte and 0.48 or 0.56, 0),
		Position = UDim2.fromScale(0.5, sousTexte and 0.38 or 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Text = texte,
		TextColor3 = fonce and Color3.fromRGB(42, 22, 0) or Color3.new(1, 1, 1), ZIndex = b.ZIndex + 2, Contour = not fonce }, "titre")
	local st
	if sousTexte then
		st = S.Texte(b, { Name = "SousTexte", Size = UDim2.new(1, -24, 0.28, 0), Position = UDim2.fromScale(0.5, 0.74),
			AnchorPoint = Vector2.new(0.5, 0.5), Text = sousTexte, TextColor3 = fonce and Color3.fromRGB(90, 54, 0) or Color3.fromRGB(230, 255, 224),
			ZIndex = b.ZIndex + 2, Contour = false }, "chiffre")
	end
	return b, t, st
end

-- onglet en biais
function S.Onglet(parent, props, texte, rappel)
	local b = S.Bouton(parent, props, rappel)
	local fond = S.Skin(b, "skin_onglet", { Size = UDim2.fromScale(1, 1), ZIndex = b.ZIndex }, 0.6)
	local t = S.Texte(b, { Size = UDim2.new(1, -40, 0.5, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = string.upper(texte), ZIndex = b.ZIndex + 1 })
	local function actif(oui)
		fond.Image = S.Image(oui and "skin_onglet_actif" or "skin_onglet")
		t.TextColor3 = oui and Color3.fromRGB(42, 22, 0) or S.C.Texte
	end
	return b, actif
end

-- pastille de notification
function S.Pastille(parent, texte, couleur)
	local p = new("Frame", { Name = "Pastille", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24), BackgroundColor3 = couleur or Color3.fromRGB(255, 48, 69), ZIndex = parent.ZIndex + 6,
		Visible = texte ~= nil }, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
	new("UIStroke", { Color = S.C.Encre, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	local t = S.Texte(p, { Size = UDim2.new(1, -6, 1, -8), Position = UDim2.fromOffset(3, 4), Text = texte or "", ZIndex = p.ZIndex + 1,
		Contour = false }, "chiffre")
	-- petit rebond régulier
	task.spawn(function()
		while p.Parent do
			task.wait(2.5 + math.random())
			if p.Visible then
				S.Tween(p, 0.12, { Size = UDim2.fromOffset(30, 30) }, Enum.EasingStyle.Quad)
				task.wait(0.12)
				S.Tween(p, 0.35, { Size = UDim2.fromOffset(24, 24) }, Enum.EasingStyle.Back)
			end
		end
	end)
	return p, t
end

-- barre fine en biais (dégradé des équipes)
function S.Barre(parent, props, degrade)
	local fond = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do fond[k] = v end
	local rempli = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		ZIndex = fond.ZIndex }, fond)
	new("UIGradient", { Color = degrade or ColorSequence.new({
		ColorSequenceKeypoint.new(0, S.C.Poule), ColorSequenceKeypoint.new(0.35, S.C.Or),
		ColorSequenceKeypoint.new(0.6, S.C.Renard), ColorSequenceKeypoint.new(1, S.C.Vipere) }) }, rempli)
	return fond, rempli
end

-- séparateur lumineux
function S.Separateur(parent, props)
	local l = new("Frame", { BackgroundColor3 = S.C.Violet, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, parent)
	for k, v in pairs(props or {}) do l[k] = v end
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1) }) }, l)
	return l
end

function S.Nombre(n)
	local s = tostring(math.floor(n or 0))
	local res = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (res:gsub("^ ", ""))
end

function S.Temps(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

return S
