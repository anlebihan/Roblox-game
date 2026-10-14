--[[ ModuleScript : ReplicatedStorage.Interface.Ouverture       — TRIPLE HUNT —
     Ouverture animée d'une caisse DU JEU (celle choisie dans la boutique) :
       1. achat (D.Actions.AcheterCaisse — c'est le jeu qui décide du couteau gagné)
       2. la caisse tremble de plus en plus fort, éclair
       3. roue de couteaux qui ralentit sur le couteau gagné (PASSER pour aller directement au résultat)
       4. révélation : rayons de la couleur de la rareté, ondes, étincelles, ÉQUIPER / CONTINUER
     X5 : 5 cartes qui se retournent une par une.
     D.OuvertureAnimee = false -> on appelle seulement D.Actions.AcheterCaisse (le jeu garde sa propre ouverture).
]]
local RunService = game:GetService("RunService")

local Ouverture = {}

function Ouverture.Init(Ctx)
	local S, D, joueur = Ctx.S, Ctx.D, Ctx.joueur
	local new = S.new

	local enCours = false
	local scene -- Frame plein écran de l'ouverture en cours

	local function rarete(id)
		local cat = D.Catalogue[id] or { Nom = tostring(id), Rarete = "Commun" }
		return cat, S.Raretes[cat.Rarete] or S.Raretes.Commun
	end

	local function attendre(t, passer)
		local t0 = os.clock()
		while os.clock() - t0 < t do
			if passer and passer.oui then return end
			RunService.RenderStepped:Wait()
		end
	end

	-- fond sombre + rayons tournants
	local function creerScene(couleur)
		scene = new("Frame", { Name = "Ouverture", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 4, 20),
			BackgroundTransparency = 1, ZIndex = 80, Active = true }, Ctx.Overlay)
		S.Tween(scene, 0.3, { BackgroundTransparency = 0.18 })
		local rayons = S.Icone(scene, "fx_rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(1500, 1500),
			ImageColor3 = couleur, ImageTransparency = 1, ZIndex = 81 })
		S.Tween(rayons, 0.6, { ImageTransparency = 0.75 })
		local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, ZIndex = 82 }, scene)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0) }) }, vignette)
		local conn = RunService.RenderStepped:Connect(function()
			rayons.Rotation = os.clock() * 9
		end)
		scene.Destroying:Connect(function() conn:Disconnect() end)
		return rayons
	end

	local function flash(couleur, force)
		local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = couleur or Color3.new(1, 1, 1), BackgroundTransparency = 1 - (force or 0.85),
			ZIndex = 98 }, scene)
		S.Tween(f, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.55, function() f:Destroy() end)
	end

	local function fermerScene()
		if not scene then return end
		local s = scene
		scene = nil
		for _, d in ipairs(s:GetDescendants()) do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then S.Tween(d, 0.25, { ImageTransparency = 1 })
			elseif d:IsA("TextLabel") or d:IsA("TextButton") then S.Tween(d, 0.25, { TextTransparency = 1 })
			elseif d:IsA("Frame") then S.Tween(d, 0.25, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then S.Tween(d, 0.25, { Transparency = 1 }) end
		end
		S.Tween(s, 0.3, { BackgroundTransparency = 1 })
		task.delay(0.32, function() s:Destroy() end)
	end

	------------------------------------------------------------ 1. la caisse tremble puis s'ouvre
	local function caisseQuiTremble(caisse, passer)
		local coul = caisse.Couleur or S.C.Or
		local halo = S.Icone(scene, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(300, 300),
			ImageColor3 = coul, ImageTransparency = 0.6, ZIndex = 83 })
		local img = S.Icone(scene, caisse.Image, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(60, 60),
			ZIndex = 84 })
		local nom = S.Texte(scene, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 150), Size = UDim2.fromOffset(600, 40),
			Text = string.upper(caisse.Nom or caisse.Id or ""), TextColor3 = coul, TextTransparency = 1, ZIndex = 84 }, "titre")
		S.Tween(img, 0.45, { Size = UDim2.fromOffset(300, 300) }, Enum.EasingStyle.Back)
		S.Tween(nom, 0.3, { TextTransparency = 0 })
		S.Son("Ouvrir")
		attendre(0.45, passer)
		-- tremblement croissant
		local t0 = os.clock()
		local duree = 1.3
		local dernierCoup = 0
		while os.clock() - t0 < duree and not passer.oui do
			local a = (os.clock() - t0) / duree
			local f = a * a * 14
			img.Position = UDim2.new(0.5, (math.random() - 0.5) * f, 0.42, (math.random() - 0.5) * f)
			img.Rotation = (math.random() - 0.5) * f * 0.6
			halo.ImageTransparency = 0.6 - a * 0.5
			halo.Size = UDim2.fromOffset(300 + a * 260, 300 + a * 260)
			if os.clock() - dernierCoup > 0.32 - a * 0.22 then
				dernierCoup = os.clock()
				S.Son("Tic", 0.9 + a, 0.25)
				if math.random() < 0.5 then Ctx.Etincelles(scene, UDim2.fromScale(0.5, 0.42), coul, 2) end
			end
			RunService.RenderStepped:Wait()
		end
		-- planche d'ouverture (optionnelle) : 4x4 images de 256 px
		if caisse.OuvertureSprite and not passer.oui then
			img.Image = S.Image(caisse.OuvertureSprite)
			img.ImageRectSize = Vector2.new(256, 256)
			for i = 0, (caisse.OuvertureImages or 16) - 1 do
				img.ImageRectOffset = Vector2.new((i % 4) * 256, (i // 4) * 256)
				attendre(1 / 20, passer)
			end
		end
		img.Position = UDim2.fromScale(0.5, 0.42)
		img.Rotation = 0
		flash(Color3.new(1, 1, 1), 0.8)
		S.Son("Impact")
		Ctx.Onde(scene, UDim2.fromScale(0.5, 0.42), coul, 700, 0.6)
		Ctx.Etincelles(scene, UDim2.fromScale(0.5, 0.42), coul, 22)
		-- la caisse monte et rapetisse au-dessus de la roue
		S.Tween(img, 0.45, { Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(170, 170) }, Enum.EasingStyle.Quart)
		S.Tween(halo, 0.45, { Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(260, 260), ImageTransparency = 0.6 }, Enum.EasingStyle.Quart)
		S.Tween(nom, 0.45, { Position = UDim2.new(0.5, 0, 0, 214), Size = UDim2.fromOffset(500, 32) }, Enum.EasingStyle.Quart)
		return img, halo, nom
	end

	------------------------------------------------------------ 2. la roue
	local LARGEUR, ECART = 150, 10
	local function tirageVisuel(contenu)
		-- tirage pondéré par les chances de rareté, pour remplir la roue de façon crédible
		local poids, total = {}, 0
		for _, id in ipairs(contenu) do
			local cat = D.Catalogue[id] or {}
			local w = (D.Chances[cat.Rarete or "Commun"] or 10) / 1
			local n = 0
			for _, autre in ipairs(contenu) do
				if (D.Catalogue[autre] or {}).Rarete == cat.Rarete then n += 1 end
			end
			w = w / math.max(n, 1)
			table.insert(poids, w)
			total += w
		end
		local x = math.random() * total
		for i, w in ipairs(poids) do
			x -= w
			if x <= 0 then return contenu[i] end
		end
		return contenu[#contenu]
	end

	local function roue(caisse, gagnant, passer)
		local contenu = caisse.Contenu or { gagnant }
		local N, IG = 46, 40
		local bande = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 180),
			BackgroundColor3 = Color3.fromRGB(8, 4, 20), BackgroundTransparency = 0.35, ClipsDescendants = true, ZIndex = 85 }, scene)
		for _, y in ipairs({ 0, 1 }) do
			local l = new("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = S.C.Or,
				BorderSizePixel = 0, ZIndex = 86 }, bande)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 1) }) }, l)
		end
		local rail = new("Frame", { Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(N * (LARGEUR + ECART), 170), BackgroundTransparency = 1,
			ZIndex = 86 }, bande)
		for i = 1, N do
			local id = (i == IG) and gagnant or tirageVisuel(contenu)
			Ctx.CarteCouteau(rail, id, { Position = UDim2.fromOffset((i - 1) * (LARGEUR + ECART), 0), Size = UDim2.fromOffset(LARGEUR, 170), ZIndex = 86,
				Active = false, Selectable = false })
		end
		-- dégradés sur les bords
		for _, cote in ipairs({ 0, 1 }) do
			local g = new("Frame", { AnchorPoint = Vector2.new(cote, 0), Position = UDim2.fromScale(cote, 0), Size = UDim2.new(0.22, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(8, 4, 20), BorderSizePixel = 0, ZIndex = 90 }, bande)
			new("UIGradient", { Rotation = cote == 0 and 0 or 180, Transparency = NumberSequence.new(0, 1) }, g)
		end
		-- repère central
		local repere = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 200),
			BackgroundColor3 = S.C.Or, BorderSizePixel = 0, ZIndex = 92 }, scene)
		S.Icone(repere, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 260),
			ImageColor3 = S.C.Or, ImageTransparency = 0.4, ZIndex = 91 })
		for _, y in ipairs({ 0, 1 }) do
			local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromOffset(16, 16), Rotation = 45,
				BackgroundColor3 = S.C.Or, ZIndex = 93 }, repere)
			new("UIStroke", { Color = S.C.Encre, Thickness = 2 }, p)
		end
		local statut = S.Texte(scene, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 110), Size = UDim2.fromOffset(400, 18),
			Text = "TIRAGE EN COURS", TextColor3 = S.C.Doux, ZIndex = 92, Contour = false })

		-- défilement : décélération douce, arrêt légèrement décalé dans la carte gagnante (suspense)
		local pas = LARGEUR + ECART
		local fin = (IG - 1) * pas + LARGEUR / 2 + (math.random() - 0.5) * (LARGEUR * 0.7)
		local depart = LARGEUR / 2
		local duree = 5.2
		local t0 = os.clock()
		local derniereCarte = -1
		while true do
			local a = math.clamp((os.clock() - t0) / duree, 0, 1)
			if passer.oui then a = 1 end
			local e = 1 - (1 - a) ^ 4
			local x = depart + (fin - depart) * e
			rail.Position = UDim2.new(0.5, -x, 0, 5)
			local carte = math.floor(x / pas)
			if carte ~= derniereCarte then
				derniereCarte = carte
				S.Son("Tic", 1.6 + math.random() * 0.2, 0.18)
				repere.Size = UDim2.fromOffset(6, 210)
				S.Tween(repere, 0.12, { Size = UDim2.fromOffset(4, 200) })
			end
			if a >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		-- recentrage sur la carte gagnante
		local centre = (IG - 1) * pas + LARGEUR / 2
		S.Tween(rail, 0.35, { Position = UDim2.new(0.5, -centre, 0, 5) }, Enum.EasingStyle.Back)
		statut.Text = ""
		attendre(0.4)
		local _, r = rarete(gagnant)
		flash(r.Couleur, 0.5)
		return bande, repere, statut
	end

	------------------------------------------------------------ 3. révélation
	local function revelation(caisse, gagnant, etaitNouveau, fini)
		local cat, r = rarete(gagnant)
		local rayons = creerScene(r.Couleur)
		rayons.ImageTransparency = 0.6
		S.Son("Gain")
		S.Son("Lame")
		local ordre = r.Ordre or 1
		flash(r.Couleur, 0.6)
		Ctx.Onde(scene, UDim2.fromScale(0.5, 0.36), r.Couleur, 900, 0.7)
		task.delay(0.15, function() if scene then Ctx.Onde(scene, UDim2.fromScale(0.5, 0.36), Color3.new(1, 1, 1), 600, 0.5) end end)
		Ctx.Etincelles(scene, UDim2.fromScale(0.5, 0.36), r.Couleur, 14 + ordre * 6)
		-- cercles fins
		for i, d in ipairs({ 300, 400 }) do
			local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(d * 0.6, d * 0.6),
				BackgroundTransparency = 1, ZIndex = 84 }, scene)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
			local st = new("UIStroke", { Color = r.Couleur, Thickness = 1.5, Transparency = 1 }, c)
			S.Tween(c, 0.6 + i * 0.1, { Size = UDim2.fromOffset(d, d) }, Enum.EasingStyle.Back)
			S.Tween(st, 0.5, { Transparency = 0.35 + i * 0.15 })
		end
		local halo = S.Icone(scene, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(420, 420),
			ImageColor3 = r.Couleur, ImageTransparency = 0.35, ZIndex = 85 })
		local img = S.Icone(scene, D.ImageCouteau(gagnant), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromOffset(60, 60), Rotation = -120, ZIndex = 86 })
		S.Tween(img, 0.7, { Size = UDim2.fromOffset(360, 360), Rotation = 0 }, Enum.EasingStyle.Back)
		local flotte = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			img.Position = UDim2.new(0.5, 0, 0.36, math.sin(t * 2) * 8)
			img.Rotation = math.sin(t * 1.4) * 3
			halo.ImageTransparency = 0.35 + math.sin(t * 3) * 0.1
		end)
		-- textes
		local tR = S.Texte(scene, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.64, 0), Size = UDim2.fromOffset(400, 18),
			Text = string.upper(cat.Rarete), TextColor3 = r.Couleur, TextTransparency = 1, ZIndex = 87, Contour = false })
		local tN = S.Texte(scene, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.64, 26), Size = UDim2.fromOffset(700, 52),
			Text = string.upper(cat.Nom), TextColor3 = r.Couleur, TextTransparency = 1, ZIndex = 87 }, "titre")
		local echN = new("UIScale", { Scale = 1.6 }, tN)
		task.delay(0.3, function()
			S.Tween(tR, 0.3, { TextTransparency = 0 })
			S.Tween(tN, 0.3, { TextTransparency = 0 })
			S.Tween(echN, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		if etaitNouveau then
			local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.64, 86), Size = UDim2.fromOffset(150, 28),
				BackgroundColor3 = Color3.new(1, 1, 1), Rotation = -3, ZIndex = 87 }, scene)
			new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 63, 164), Color3.fromRGB(255, 140, 30)) }, b)
			S.Texte(b, { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = "NOUVEAU !", ZIndex = 88 })
			local e = new("UIScale", { Scale = 0 }, b)
			task.delay(0.6, function() S.Tween(e, 0.4, { Scale = 1 }, Enum.EasingStyle.Back) end)
		else
			S.Texte(scene, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.64, 88), Size = UDim2.fromOffset(300, 16), Text = "DÉJÀ POSSÉDÉ",
				TextColor3 = S.C.Doux, ZIndex = 87, Contour = false })
		end
		-- boutons
		local zone = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(420, 58), BackgroundTransparency = 1,
			ZIndex = 89 }, scene)
		local function terminer()
			flotte:Disconnect()
			fermerScene()
			fini()
		end
		local deja = D.Etat.CouteauEquipe == gagnant
		S.BoutonSkin(zone, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(200, 58), ZIndex = 89 }, deja and "ÉQUIPÉ" or "ÉQUIPER",
			deja and "sombre" or "vert", function()
				if not deja and D.Actions.EquiperCouteau then
					local ok = D.Actions.EquiperCouteau(gagnant)
					if ok ~= false then D.Mettre("CouteauEquipe", gagnant) end
				end
				terminer()
			end)
		S.BoutonSkin(zone, { Position = UDim2.fromOffset(220, 0), Size = UDim2.fromOffset(200, 58), ZIndex = 89 }, "CONTINUER", "violet", terminer)
		local e = new("UIScale", { Scale = 0 }, zone)
		task.delay(0.8, function() S.Tween(e, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end

	------------------------------------------------------------ X5 : cartes qui se retournent
	local function revelationMultiple(caisse, gagnants, nouveaux, fini)
		local meilleur = 1
		for _, id in ipairs(gagnants) do
			local _, r = rarete(id)
			meilleur = math.max(meilleur, r.Ordre or 1)
		end
		local coulMeilleure = S.C.Or
		for _, r in pairs(S.Raretes) do if r.Ordre == meilleur then coulMeilleure = r.Couleur end end
		creerScene(coulMeilleure)
		S.Texte(scene, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(600, 40),
			Text = string.upper(caisse.Nom or caisse.Id or "") .. "  ×" .. #gagnants, TextColor3 = caisse.Couleur or S.C.Or, ZIndex = 84 }, "titre")
		local n = #gagnants
		local L, H, E = 190, 250, 22
		local total = n * L + (n - 1) * E
		local dosCartes = {}
		for i in ipairs(gagnants) do
			local x = -total / 2 + (i - 1) * (L + E) + L / 2
			-- dos de carte
			local dos = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.46, 0), Size = UDim2.fromOffset(L, H),
				BackgroundColor3 = Color3.fromRGB(40, 22, 80), ZIndex = 85 }, scene)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(60, 34, 120), Color3.fromRGB(18, 9, 40)) }, dos)
			new("UIStroke", { Color = S.C.Violet, Transparency = 0.4, Thickness = 1.5 }, dos)
			S.Icone(dos, caisse.Image, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120), ZIndex = 86,
				ImageTransparency = 0.3 })
			dosCartes[i] = dos
			local echDos = new("UIScale", { Scale = 0 }, dos)
			S.Tween(echDos, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			attendre(0.08)
		end
		attendre(0.5)
		for i, id in ipairs(gagnants) do
			local cat, r = rarete(id)
			local x = -total / 2 + (i - 1) * (L + E) + L / 2
			-- retournement : la carte s'aplatit, puis la face apparaît
			local d = dosCartes[i]
			S.Tween(d, 0.14, { Size = UDim2.fromOffset(0, H) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.15, function() d:Destroy() end)
			attendre(0.15)
			local face = Ctx.CarteCouteau(scene, id, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.46, 0), Size = UDim2.fromOffset(0, H),
				ZIndex = 86 })
			S.Tween(face, 0.2, { Size = UDim2.fromOffset(L, H) }, Enum.EasingStyle.Back)
			S.Texte(face, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.new(1, 0, 0, 18), Text = string.upper(cat.Nom),
				TextColor3 = r.Couleur, ZIndex = 90 }, "titre")
			if nouveaux[i] then
				local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(100, 22),
					BackgroundColor3 = Color3.new(1, 1, 1), Rotation = -4, ZIndex = 91 }, face)
				new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 63, 164), Color3.fromRGB(255, 140, 30)) }, b)
				S.Texte(b, { Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "NOUVEAU", ZIndex = 92 })
			end
			Ctx.Onde(scene, UDim2.new(0.5, x, 0.46, 0), r.Couleur, 260 + (r.Ordre or 1) * 40, 0.45)
			if (r.Ordre or 1) >= 4 then
				flash(r.Couleur, 0.4)
				Ctx.Etincelles(scene, UDim2.new(0.5, x, 0.46, 0), r.Couleur, 16)
				S.Son("Gain")
			else
				S.Son("Lame", 1 + (r.Ordre or 1) * 0.1, 0.4)
			end
			attendre(0.35)
		end
		local zone = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(220, 58), BackgroundTransparency = 1,
			ZIndex = 89 }, scene)
		S.BoutonSkin(zone, { Size = UDim2.fromScale(1, 1), ZIndex = 89 }, "CONTINUER", "violet", function()
			fermerScene()
			fini()
		end)
	end

	------------------------------------------------------------ point d'entrée (appelé par la boutique)
	function Ctx.OuvrirCaisse(caisse, n)
		if enCours or not D.Actions.AcheterCaisse then return end
		n = n or 1
		enCours = true

		-- achat : AcheterCaisse(id, n) -> ok, idGagné | {ids}   (ou ok, "message" si refusé)
		local avant = {}
		for _, id in ipairs(D.Etat.Couteaux or {}) do avant[id] = true end
		local ok, res
		local reussi = pcall(function() ok, res = D.Actions.AcheterCaisse(caisse.Id, n) end)
		if not reussi or not ok then
			enCours = false
			S.Son("Erreur")
			if Ctx.Notifier then Ctx.Notifier(type(res) == "string" and res or "Achat impossible", Color3.fromRGB(200, 40, 50)) end
			return
		end
		local gagnants = type(res) == "table" and res or { res }
		-- si le jeu ne gère qu'une caisse à la fois, on achète les suivantes une par une
		if n > 1 and #gagnants < n then
			for _ = #gagnants + 1, n do
				local ok2, r2 = D.Actions.AcheterCaisse(caisse.Id, 1)
				if not ok2 then break end
				table.insert(gagnants, type(r2) == "table" and r2[1] or r2)
			end
		end
		if #gagnants == 0 or gagnants[1] == nil then enCours = false; return end
		local nouveaux = {}
		for i, id in ipairs(gagnants) do
			nouveaux[i] = not avant[id]
			avant[id] = true
		end
		-- le jeu garde sa propre animation d'ouverture
		if D.OuvertureAnimee == false then enCours = false; return end

		if Ctx.Fermer then Ctx.Fermer() end
		local function fini()
			enCours = false
			task.delay(0.35, function() Ctx.Ouvrir("Boutique", nil, "Caisses") end)
		end
		task.spawn(function()
			local passer = { oui = joueur:GetAttribute("Param_OuvertureRapide") == true }
			creerScene(caisse.Couleur or S.C.Or)
			local btnPasser = S.BoutonSkin(scene, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(150, 46), ZIndex = 95 },
				"PASSER", "sombre", function() passer.oui = true end)
			local img, halo, nom = caisseQuiTremble(caisse, passer)
			attendre(0.35, passer)
			if #gagnants == 1 then
				local bande, repere, statut = roue(caisse, gagnants[1], passer)
				attendre(0.5, passer)
				for _, o in ipairs({ bande, repere, statut, img, halo, nom, btnPasser }) do o:Destroy() end
				local ancienne = scene
				scene = nil
				ancienne:Destroy()
				revelation(caisse, gagnants[1], nouveaux[1], fini)
			else
				local ancienne = scene
				scene = nil
				ancienne:Destroy()
				revelationMultiple(caisse, gagnants, nouveaux, fini)
			end
		end)
	end
end

return Ouverture
