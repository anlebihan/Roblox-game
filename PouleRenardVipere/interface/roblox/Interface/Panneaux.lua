--[[ ModuleScript : ReplicatedStorage.Interface.Panneaux        — TRIPLE HUNT —
     Fenêtres : Boutique (onglets CAISSES / COUTEAUX / PIÈCES), Paramètres, Quêtes, Cadeau, Classement.
     Les caisses affichées sont celles du jeu (D.Caisses, remplies par le BranchementInterface) : rien n'est remplacé.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")

local Panneaux = {}

function Panneaux.Init(Ctx)
	local S, D, joueur = Ctx.S, Ctx.D, Ctx.joueur
	local new = S.new
	Ctx.Tick = Ctx.Tick or {}

	------------------------------------------------------------ outils communs
	local function contenu(f)
		return new("Frame", { Name = "Contenu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51 }, f)
	end
	local function titre(parent, texte, icone)
		local x = 30
		if icone then
			S.Icone(parent, icone, { Position = UDim2.fromOffset(20, -6), Size = UDim2.fromOffset(72, 72), ZIndex = 2 })
			x = 96
		end
		S.Texte(parent, { Position = UDim2.fromOffset(x, 20), Size = UDim2.fromOffset(340, 40), Text = texte, TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2 }, "titre")
		S.Separateur(parent, { Position = UDim2.fromOffset(30, 82), Size = UDim2.new(1, -60, 0, 1) })
	end
	local function defilement(parent, props)
		local sf = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = S.C.Violet,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, parent)
		for k, v in pairs(props) do sf[k] = v end
		return sf
	end
	local function vider(o)
		for _, c in ipairs(o:GetChildren()) do
			if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
		end
	end

	-- pastille de pièces (dans les fenêtres)
	local pills = {}
	local function pillePieces(parent, pos)
		local p = S.Skin(parent, "skin_bouton_sombre", { AnchorPoint = Vector2.new(1, 0), Position = pos, Size = UDim2.fromOffset(180, 46), ZIndex = 2 }, 0.6)
		S.Icone(p, "icone_piece", { Position = UDim2.fromOffset(-8, -6), Size = UDim2.fromOffset(56, 56), ZIndex = 3 })
		local t = S.Texte(p, { Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -66, 0, 26), Text = S.Nombre(D.Etat.Pieces or 0),
			TextColor3 = S.C.Or, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "chiffre")
		table.insert(pills, t)
		return p
	end
	D.Change:Connect(function(cle)
		if cle == "Pieces" then
			for _, t in ipairs(pills) do t.Text = S.Nombre(D.Etat.Pieces or 0) end
		end
	end)

	-- carte d'un couteau (fond de rareté, image, liseré de couleur)
	local function carteCouteau(parent, id, props, rappel)
		local cat = D.Catalogue[id] or { Nom = tostring(id), Rarete = "Commun" }
		local r = S.Raretes[cat.Rarete] or S.Raretes.Commun
		local b = S.Bouton(parent, props, rappel)
		local fond = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = r.Fond, BorderSizePixel = 0, ZIndex = 2 }, b)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(r.Fond, Color3.fromRGB(14, 7, 30)) }, fond)
		new("UIStroke", { Color = r.Couleur, Transparency = 0.6, Thickness = 1 }, fond)
		local lueur = new("ImageLabel", { BackgroundTransparency = 1, Image = S.Image("fx_braise"), ImageColor3 = r.Couleur, ImageTransparency = 0.6,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1.1, 1.1), ZIndex = 3 }, b)
		local img = S.Icone(b, D.ImageCouteau(id), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.86, 0.78), ZIndex = 4 })
		if img.Image == "" then
			S.Texte(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.86, 0.3),
				Text = string.upper(cat.Nom), TextColor3 = r.Couleur, ZIndex = 4 }, "titre")
		end
		new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = r.Couleur,
			BorderSizePixel = 0, ZIndex = 5 }, b)
		b.MouseEnter:Connect(function()
			S.Tween(img, 0.25, { Rotation = -8, Size = UDim2.fromScale(0.96, 0.88) }, Enum.EasingStyle.Back)
			S.Tween(lueur, 0.25, { ImageTransparency = 0.3 })
		end)
		b.MouseLeave:Connect(function()
			S.Tween(img, 0.25, { Rotation = 0, Size = UDim2.fromScale(0.86, 0.78) })
			S.Tween(lueur, 0.25, { ImageTransparency = 0.6 })
		end)
		return b, img, cat, r
	end
	Ctx.CarteCouteau = carteCouteau

	local function possede(id)
		for _, c in ipairs(D.Etat.Couteaux or {}) do if c == id then return true end end
		return false
	end
	Ctx.Possede = possede

	--==========================================================================================
	-- BOUTIQUE
	--==========================================================================================
	local fB = Ctx.CreerFenetre("Boutique", Vector2.new(1184, 660))
	local cB = contenu(fB)
	S.Texte(cB, { Position = UDim2.fromOffset(30, 20), Size = UDim2.fromOffset(220, 42), Text = "BOUTIQUE", TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2 }, "titre")
	S.Separateur(cB, { Position = UDim2.fromOffset(30, 82), Size = UDim2.new(1, -60, 0, 1) })
	pillePieces(cB, UDim2.new(1, -84, 0, 20))
	Ctx.BoutonFermer(fB)

	local pages, onglets = {}, {}
	local ongletActif
	local function choisirOnglet(nom)
		if ongletActif == nom then return end
		ongletActif = nom
		for n, p in pairs(pages) do
			if n == nom then
				p.Visible = true
				p.Position = UDim2.fromOffset(40, 100)
				S.Tween(p, 0.3, { Position = UDim2.fromOffset(0, 100) }, Enum.EasingStyle.Quart)
			else
				p.Visible = false
			end
		end
		for n, a in pairs(onglets) do a(n == nom) end
	end
	for i, o in ipairs({ { "Caisses", "CAISSES" }, { "Couteaux", "COUTEAUX" }, { "Pieces", "PIÈCES" } }) do
		local _, actif = S.Onglet(cB, { Position = UDim2.fromOffset(250 + (i - 1) * 150, 28), Size = UDim2.fromOffset(142, 38), ZIndex = 2 }, o[2], function()
			choisirOnglet(o[1])
		end)
		onglets[o[1]] = actif
		pages[o[1]] = new("Frame", { Name = o[1], BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 1, -100),
			Visible = false, ZIndex = 2 }, cB)
	end

	------------------------------------------------ onglet CAISSES (les caisses du jeu)
	local pC = pages.Caisses
	local listeC = defilement(pC, { Position = UDim2.fromOffset(26, 26), Size = UDim2.fromOffset(240, 520), ZIndex = 2 })
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, listeC)
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }, listeC)

	local vitrine = new("Frame", { Position = UDim2.fromOffset(290, 0), Size = UDim2.fromOffset(500, 560), BackgroundTransparency = 1, ZIndex = 2 }, pC)
	local nomCaisse = S.Texte(vitrine, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 38), Text = "", ZIndex = 3 }, "titre")
	local sousCaisse = S.Texte(vitrine, { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 16), Text = "", TextColor3 = S.C.Doux, ZIndex = 3,
		Contour = false })
	local rayons = S.Icone(vitrine, "fx_rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 270), Size = UDim2.fromOffset(460, 460),
		ImageTransparency = 0.55, ZIndex = 2 })
	local socle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 420), Size = UDim2.fromOffset(280, 26),
		BackgroundColor3 = S.C.Or, BackgroundTransparency = 0.5, ZIndex = 2 }, vitrine)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, socle)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1) }) }, socle)
	local imageCaisse = new("ImageButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 280), Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false, ZIndex = 4 }, vitrine)
	local boutonsOuvrir = new("Frame", { Position = UDim2.fromOffset(0, 470), Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, ZIndex = 3 }, vitrine)

	local panC = S.Skin(pC, "skin_panneau", { Position = UDim2.fromOffset(806, 20), Size = UDim2.fromOffset(356, 530), ZIndex = 2 }, 0.6)
	S.Texte(panC, { Position = UDim2.fromOffset(20, 18), Size = UDim2.fromOffset(200, 16), Text = "CONTENU", TextColor3 = S.C.Doux,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Contour = false })
	local grilleContenu = defilement(panC, { Position = UDim2.fromOffset(18, 44), Size = UDim2.fromOffset(324, 246), ZIndex = 3 })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 112), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grilleContenu)
	S.Texte(panC, { Position = UDim2.fromOffset(20, 302), Size = UDim2.fromOffset(200, 16), Text = "CHANCES", TextColor3 = S.C.Doux,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Contour = false })
	local zoneChances = new("Frame", { Position = UDim2.fromOffset(20, 328), Size = UDim2.fromOffset(318, 180), BackgroundTransparency = 1, ZIndex = 3 }, panC)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, zoneChances)

	local caisseChoisie
	local spriteRotation -- { image, colonnes, images }
	local function afficherCaisse(c)
		caisseChoisie = c
		local coul = c.Couleur or S.C.Or
		nomCaisse.Text = string.upper(c.Nom or c.Id)
		nomCaisse.TextColor3 = coul
		sousCaisse.Text = string.format("%d COUTEAUX · OUVRE-LA POUR EN GAGNER UN", #(c.Contenu or {}))
		rayons.ImageColor3 = coul
		socle.BackgroundColor3 = coul
		spriteRotation = nil
		if c.Rotation then
			imageCaisse.Image = S.Image(c.Rotation)
			imageCaisse.ImageRectSize = Vector2.new(256, 256)
			spriteRotation = { n = c.RotationImages or 16 }
		else
			imageCaisse.Image = S.Image(c.Image)
			imageCaisse.ImageRectSize = Vector2.zero
			imageCaisse.ImageRectOffset = Vector2.zero
		end
		-- apparition
		imageCaisse.Size = UDim2.fromOffset(180, 180)
		S.Tween(imageCaisse, 0.45, { Size = UDim2.fromOffset(300, 300) }, Enum.EasingStyle.Back)
		Ctx.Onde(vitrine, UDim2.fromOffset(250, 280), coul, 380, 0.5)

		-- contenu
		vider(grilleContenu)
		local ids = table.clone(c.Contenu or {})
		table.sort(ids, function(a, b)
			local ra = S.Raretes[(D.Catalogue[a] or {}).Rarete or "Commun"] or S.Raretes.Commun
			local rb = S.Raretes[(D.Catalogue[b] or {}).Rarete or "Commun"] or S.Raretes.Commun
			return ra.Ordre < rb.Ordre
		end)
		for i, id in ipairs(ids) do
			local b = carteCouteau(grilleContenu, id, { LayoutOrder = i, ZIndex = 3 })
			if possede(id) then
				local v = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = S.C.Vert, ZIndex = 7 }, b)
				new("UICorner", { CornerRadius = UDim.new(1, 0) }, v)
				S.Texte(v, { Size = UDim2.fromScale(1, 1), Text = "✓", ZIndex = 8, Contour = false }, "chiffre")
			end
		end
		-- chances
		vider(zoneChances)
		local chances = c.Chances or D.Chances
		local ordre = {}
		for nom in pairs(chances) do table.insert(ordre, nom) end
		table.sort(ordre, function(a, b) return (S.Raretes[a] or S.Raretes.Commun).Ordre < (S.Raretes[b] or S.Raretes.Commun).Ordre end)
		for i, nom in ipairs(ordre) do
			local r = S.Raretes[nom] or S.Raretes.Commun
			local l = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3 }, zoneChances)
			S.Texte(l, { Size = UDim2.new(0, 90, 1, -4), Position = UDim2.fromOffset(0, 2), Text = nom, TextColor3 = r.Couleur,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Contour = false }, "corps")
			local fond = new("Frame", { Position = UDim2.new(0, 96, 0.5, -3), Size = UDim2.new(1, -160, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 3 }, l)
			local rempli = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = r.Couleur, BorderSizePixel = 0, ZIndex = 3 }, fond)
			S.Tween(rempli, 0.6 + i * 0.08, { Size = UDim2.fromScale(math.clamp(chances[nom] / 100, 0.01, 1), 1) }, Enum.EasingStyle.Quart)
			S.Texte(l, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.new(0, 54, 1, -4), Text = tostring(chances[nom]) .. "%",
				TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 }, "chiffre")
		end
		-- boutons d'ouverture
		vider(boutonsOuvrir)
		local gratuit = (D.Etat.CaissesGratuites or 0) > 0 and not c.PrixRobux
		local function ouvrir(n)
			if Ctx.OuvrirCaisse then Ctx.OuvrirCaisse(c, n) end
		end
		if c.PrixRobux then
			S.BoutonSkin(boutonsOuvrir, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(240, 60), ZIndex = 3 },
				"OUVRIR", "or", function() ouvrir(1) end, tostring(c.PrixRobux) .. " R$")
		else
			S.BoutonSkin(boutonsOuvrir, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, -10, 0, 0), Size = UDim2.fromOffset(190, 60), ZIndex = 3 },
				"OUVRIR X1", "vert", function() ouvrir(1) end, gratuit and "GRATUIT" or (S.Nombre(c.Prix or 0) .. " pièces"))
			if c.X5 ~= false then
				local prix5 = c.PrixX5 or (c.Prix or 0) * 5
				S.BoutonSkin(boutonsOuvrir, { Position = UDim2.new(0.5, 10, 0, 0), Size = UDim2.fromOffset(190, 60), ZIndex = 3 },
					"OUVRIR X5", "or", function() ouvrir(5) end, S.Nombre(prix5) .. " pièces")
			end
		end
	end
	-- rotation (planche 4x4) + flottement de la caisse + rayons qui tournent
	local tempsSprite = 0
	table.insert(Ctx.Tick, function(dt)
		if not (fB.Visible and pC.Visible) then return end
		local t = os.clock()
		rayons.Rotation = t * 12
		imageCaisse.Position = UDim2.fromOffset(250, 280 + math.sin(t * 2) * 8)
		imageCaisse.Rotation = math.sin(t * 1.3) * 2
		if spriteRotation then
			tempsSprite += dt
			local i = math.floor(tempsSprite * 12) % spriteRotation.n
			imageCaisse.ImageRectOffset = Vector2.new((i % 4) * 256, (i // 4) * 256)
		end
	end)
	imageCaisse.Activated:Connect(function()
		S.Tween(imageCaisse, 0.08, { Size = UDim2.fromOffset(320, 320) })
		task.delay(0.08, function() S.Tween(imageCaisse, 0.4, { Size = UDim2.fromOffset(300, 300) }, Enum.EasingStyle.Elastic) end)
		if caisseChoisie then Ctx.Etincelles(vitrine, UDim2.fromOffset(250, 260), caisseChoisie.Couleur or S.C.Or, 10) end
	end)

	local cartesCaisses = {}
	local function construireListeCaisses()
		vider(listeC)
		cartesCaisses = {}
		for i, c in ipairs(D.Caisses or {}) do
			local special = c.PrixRobux ~= nil
			local b = S.Bouton(listeC, { Size = UDim2.fromOffset(222, 92), LayoutOrder = i, ZIndex = 2 }, function()
				for _, k in pairs(cartesCaisses) do k.actif(false) end
				cartesCaisses[c].actif(true)
				afficherCaisse(c)
			end)
			local fond = S.Skin(b, "skin_tuile", { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, 0.5)
			local ic = S.Icone(b, c.Image, { Position = UDim2.fromOffset(4, 10), Size = UDim2.fromOffset(72, 72), ZIndex = 3 })
			local n = S.Texte(b, { Position = UDim2.fromOffset(84, 18), Size = UDim2.new(1, -94, 0, 22), Text = string.upper(c.Nom or c.Id),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, TextColor3 = special and S.C.Or or S.C.Texte }, "titre")
			local prix = special and (tostring(c.PrixRobux) .. " R$" .. (c.Badge and (" · " .. c.Badge) or "")) or (S.Nombre(c.Prix or 0) .. " PIÈCES")
			local p = S.Texte(b, { Position = UDim2.fromOffset(84, 46), Size = UDim2.new(1, -94, 0, 15), Text = prix, TextColor3 = S.C.Doux,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Contour = false })
			b.MouseEnter:Connect(function() S.Tween(ic, 0.25, { Rotation = -10 }, Enum.EasingStyle.Back) end)
			b.MouseLeave:Connect(function() S.Tween(ic, 0.25, { Rotation = 0 }) end)
			cartesCaisses[c] = {
				actif = function(oui)
					fond.Image = S.Image((oui or special) and "skin_tuile_or" or "skin_tuile")
					n.TextColor3 = (oui or special) and S.C.Or or S.C.Texte
					p.TextColor3 = oui and Color3.fromRGB(255, 232, 170) or S.C.Doux
				end,
			}
			cartesCaisses[c].actif(false)
		end
		local premiere = (D.Caisses or {})[1]
		if premiere then
			cartesCaisses[premiere].actif(true)
			afficherCaisse(premiere)
		end
	end

	------------------------------------------------ onglet COUTEAUX (inventaire)
	local pK = pages.Couteaux
	local grilleK = defilement(pK, { Position = UDim2.fromOffset(26, 22), Size = UDim2.fromOffset(760, 530), ZIndex = 2 })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(138, 156), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder }, grilleK)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6) }, grilleK)
	local detail = S.Skin(pK, "skin_panneau", { Position = UDim2.fromOffset(806, 20), Size = UDim2.fromOffset(356, 530), ZIndex = 2 }, 0.6)
	local dRayons = S.Icone(detail, "fx_rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(178, 190), Size = UDim2.fromOffset(330, 330),
		ImageTransparency = 0.6, ZIndex = 3 })
	local dImage = S.Icone(detail, "", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(178, 190), Size = UDim2.fromOffset(250, 250), ZIndex = 4 })
	local dRarete = S.Texte(detail, { Position = UDim2.fromOffset(20, 340), Size = UDim2.new(1, -40, 0, 16), Text = "", ZIndex = 4, Contour = false })
	local dNom = S.Texte(detail, { Position = UDim2.fromOffset(20, 362), Size = UDim2.new(1, -40, 0, 34), Text = "", ZIndex = 4 }, "titre")
	local dEquipe = S.Texte(detail, { Position = UDim2.fromOffset(20, 402), Size = UDim2.new(1, -40, 0, 16), Text = "", TextColor3 = S.C.Doux, ZIndex = 4,
		Contour = false })
	local dBouton = new("Frame", { Position = UDim2.fromOffset(48, 440), Size = UDim2.fromOffset(260, 60), BackgroundTransparency = 1, ZIndex = 4 }, detail)

	local function equipeDuCouteau(id)
		local cat = D.Catalogue[id]
		if cat and cat.Equipe then return cat.Equipe end
		local s = string.lower(tostring(id))
		if s:find("poule") then return "Poules" elseif s:find("renard") then return "Renards" elseif s:find("vip") then return "Vipères" end
		return nil
	end
	local couteauDetail
	local construireCouteaux
	local function afficherDetail(id)
		couteauDetail = id
		local cat = D.Catalogue[id] or { Nom = id, Rarete = "Commun" }
		local r = S.Raretes[cat.Rarete] or S.Raretes.Commun
		dImage.Image = S.Image(D.ImageCouteau(id))
		dImage.Rotation = -30
		dImage.Size = UDim2.fromOffset(150, 150)
		S.Tween(dImage, 0.5, { Rotation = 0, Size = UDim2.fromOffset(250, 250) }, Enum.EasingStyle.Back)
		dRayons.ImageColor3 = r.Couleur
		dRarete.Text = string.upper(cat.Rarete)
		dRarete.TextColor3 = r.Couleur
		dNom.Text = string.upper(cat.Nom)
		local eq = equipeDuCouteau(id)
		dEquipe.Text = eq and ("ÉQUIPE " .. S.Equipes[eq].Nom) or ""
		vider(dBouton)
		if D.Etat.CouteauEquipe == id then
			S.BoutonSkin(dBouton, { Size = UDim2.fromScale(1, 1), ZIndex = 4 }, "ÉQUIPÉ", "sombre")
		elseif possede(id) then
			S.BoutonSkin(dBouton, { Size = UDim2.fromScale(1, 1), ZIndex = 4 }, "ÉQUIPER", "vert", function()
				if D.Actions.EquiperCouteau then
					local ok = D.Actions.EquiperCouteau(id)
					if ok ~= false then
						D.Mettre("CouteauEquipe", id)
						S.Son("Lame")
						Ctx.Etincelles(detail, UDim2.fromOffset(178, 190), r.Couleur, 14)
						construireCouteaux()
						afficherDetail(id)
					end
				end
			end)
		else
			S.BoutonSkin(dBouton, { Size = UDim2.fromScale(1, 1), ZIndex = 4 }, "DANS LES CAISSES", "violet", function() choisirOnglet("Caisses") end)
		end
	end
	table.insert(Ctx.Tick, function()
		if fB.Visible and pK.Visible then dRayons.Rotation = os.clock() * 10 end
	end)
	construireCouteaux = function()
		vider(grilleK)
		local ids = {}
		for id in pairs(D.Catalogue) do table.insert(ids, id) end
		local ordreEq = { Poules = 1, Renards = 2, ["Vipères"] = 3 }
		table.sort(ids, function(a, b)
			local pa, pb = possede(a) and 0 or 1, possede(b) and 0 or 1
			if pa ~= pb then return pa < pb end
			local ea, eb = ordreEq[equipeDuCouteau(a) or ""] or 4, ordreEq[equipeDuCouteau(b) or ""] or 4
			if ea ~= eb then return ea < eb end
			local ra = (S.Raretes[D.Catalogue[a].Rarete] or S.Raretes.Commun).Ordre
			local rb = (S.Raretes[D.Catalogue[b].Rarete] or S.Raretes.Commun).Ordre
			if ra ~= rb then return ra > rb end
			return a < b
		end)
		for i, id in ipairs(ids) do
			local b, img = carteCouteau(grilleK, id, { LayoutOrder = i, ZIndex = 2 }, function() afficherDetail(id) end)
			if not possede(id) then
				img.ImageColor3 = Color3.fromRGB(40, 30, 60)
				local cadenas = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(30, 26),
					BackgroundColor3 = S.C.Doux, ZIndex = 6 }, b)
				new("UICorner", { CornerRadius = UDim.new(0, 5) }, cadenas)
				local anse = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(20, 18),
					BackgroundTransparency = 1, ZIndex = 6 }, cadenas)
				new("UICorner", { CornerRadius = UDim.new(1, 0) }, anse)
				new("UIStroke", { Color = S.C.Doux, Thickness = 4 }, anse)
			elseif D.Etat.CouteauEquipe == id then
				local e = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(80, 20),
					BackgroundColor3 = S.C.Or, ZIndex = 7 }, b)
				new("UICorner", { CornerRadius = UDim.new(0, 4) }, e)
				S.Texte(e, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Text = "ÉQUIPÉ", TextColor3 = Color3.fromRGB(42, 22, 0),
					ZIndex = 8, Contour = false }, "chiffre")
				local trait = b:FindFirstChildWhichIsA("Frame"):FindFirstChildOfClass("UIStroke")
				trait.Color, trait.Transparency, trait.Thickness = S.C.Or, 0, 2
			end
		end
		afficherDetail(couteauDetail or D.Etat.CouteauEquipe or ids[1])
	end

	------------------------------------------------ onglet PIÈCES (Robux)
	local pP = pages.Pieces
	local zonePacks = new("Frame", { Position = UDim2.fromOffset(40, 40), Size = UDim2.new(1, -80, 0, 470), BackgroundTransparency = 1, ZIndex = 2 }, pP)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 28), HorizontalAlignment = Enum.HorizontalAlignment.Center }, zonePacks)
	local function construirePacks()
		vider(zonePacks)
		for i, pack in ipairs(D.PacksPieces or {}) do
			local carte = S.Skin(zonePacks, i == #D.PacksPieces and "skin_tuile_or" or "skin_tuile", { Size = UDim2.fromOffset(320, 460), LayoutOrder = i, ZIndex = 2 }, 0.7)
			local r = S.Icone(carte, "fx_rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(160, 170), Size = UDim2.fromOffset(300, 300),
				ImageColor3 = S.C.Or, ImageTransparency = 0.7, ZIndex = 3 })
			table.insert(Ctx.Tick, function() if pP.Visible and fB.Visible then r.Rotation = os.clock() * (8 + i * 3) end end)
			-- pile de pièces : plus le pack est gros, plus il y en a
			for k = 1, math.min(i * 2 + 1, 7) do
				local a = (k - 1) / math.max(i * 2, 1) * math.pi - math.pi
				S.Icone(carte, "icone_piece", { AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(160 + (k == 1 and 0 or math.cos(a) * 60), 170 + (k == 1 and 0 or math.sin(a) * -30 + 30)),
					Size = UDim2.fromOffset(k == 1 and 150 or 90, k == 1 and 150 or 90), Rotation = (k - 1) * 17 % 40 - 20, ZIndex = k == 1 and 5 or 4 })
			end
			S.Texte(carte, { Position = UDim2.fromOffset(20, 296), Size = UDim2.new(1, -40, 0, 46), Text = S.Nombre(pack.Pieces), TextColor3 = S.C.Or, ZIndex = 5 }, "chiffre")
			S.Texte(carte, { Position = UDim2.fromOffset(20, 344), Size = UDim2.new(1, -40, 0, 16), Text = "PIÈCES", TextColor3 = S.C.Doux, ZIndex = 5, Contour = false })
			if pack.Badge then
				local bd = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(160, 20), Size = UDim2.fromOffset(170, 30),
					BackgroundColor3 = S.C.Rouge, Rotation = -3, ZIndex = 6 }, carte)
				new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 63, 164), Color3.fromRGB(255, 140, 30)) }, bd)
				S.Texte(bd, { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = pack.Badge, ZIndex = 7 }, "titre")
			end
			S.BoutonSkin(carte, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(160, 378), Size = UDim2.fromOffset(220, 58), ZIndex = 5 },
				tostring(pack.Robux) .. " R$", "vert", function()
					if D.Actions.AcheterPieces then
						task.spawn(D.Actions.AcheterPieces, pack)
					elseif pack.ProduitId and pack.ProduitId > 0 then
						MarketplaceService:PromptProductPurchase(joueur, pack.ProduitId)
					end
				end)
		end
	end

	function Ctx.AvantOuverture_Boutique(onglet)
		ongletActif = nil
		choisirOnglet(onglet or "Caisses")
	end

	D.Change:Connect(function(cle)
		if cle == "Caisses" then construireListeCaisses()
		elseif cle == "Couteaux" or cle == "CouteauEquipe" or cle == "Catalogue" then
			construireCouteaux()
			if caisseChoisie then afficherCaisse(caisseChoisie) end
		elseif cle == "CaissesGratuites" and caisseChoisie then afficherCaisse(caisseChoisie)
		elseif cle == "PacksPieces" then construirePacks()
		end
	end)
	construireListeCaisses()
	construireCouteaux()
	construirePacks()
	choisirOnglet("Caisses")

	--==========================================================================================
	-- PARAMÈTRES (attributs « Param_* » du joueur local, lus par le reste du jeu)
	--==========================================================================================
	local fP = Ctx.CreerFenetre("Parametres", Vector2.new(1028, 636))
	local cP = contenu(fP)
	local engrenage = S.Icone(cP, "icone_parametres", { Position = UDim2.fromOffset(20, -6), Size = UDim2.fromOffset(72, 72), ZIndex = 2 })
	S.Texte(cP, { Position = UDim2.fromOffset(96, 20), Size = UDim2.fromOffset(340, 40), Text = "PARAMÈTRES", TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2 }, "titre")
	S.Separateur(cP, { Position = UDim2.fromOffset(30, 82), Size = UDim2.new(1, -60, 0, 1) })
	Ctx.BoutonFermer(fP)
	table.insert(Ctx.Tick, function() if fP.Visible then engrenage.Rotation = os.clock() * 15 end end)

	local valeurs = {
		Musique = 70, Effets = 90, Secousses = true, Performance = false, Ombres = true,
		ToucheEsquive = "Q", Fil = true, Danger = true, OuvertureRapide = false,
	}
	if type(D.Etat.Parametres) == "table" then
		for k, v in pairs(D.Etat.Parametres) do valeurs[k] = v end
	end
	local function groupeSon(nom)
		local g = SoundService:FindFirstChild(nom)
		if not g then g = new("SoundGroup", { Name = nom }, SoundService) end
		return g
	end
	local sauvegarde = 0
	local function appliquer(cle, v)
		valeurs[cle] = v
		joueur:SetAttribute("Param_" .. cle, v)
		if cle == "Musique" then groupeSon("Musique").Volume = v / 100 * 0.5
		elseif cle == "Effets" then groupeSon("Effets").Volume = v / 100 * 0.5
		elseif cle == "Ombres" then Lighting.GlobalShadows = v
		end
		-- sauvegarde groupée (au plus une fois toutes les 2 s)
		sauvegarde += 1
		local n = sauvegarde
		task.delay(2, function()
			if n == sauvegarde and D.Actions.SauverParametres then pcall(D.Actions.SauverParametres, table.clone(valeurs)) end
		end)
	end
	for k, v in pairs(valeurs) do
		if k == "Ombres" then
			joueur:SetAttribute("Param_Ombres", v)
			if v == false then Lighting.GlobalShadows = false end
		else
			appliquer(k, v)
		end
	end
	sauvegarde = 0

	local rafraichir = {}
	local zoneLignes = new("Frame", { Position = UDim2.fromOffset(246, 106), Size = UDim2.fromOffset(756, 500), BackgroundTransparency = 1, ZIndex = 2 }, cP)
	local sections = {}
	local function ligne(parent, i, titreL, sous)
		local l = S.Skin(parent, "skin_ligne", { Position = UDim2.fromOffset(0, (i - 1) * 74), Size = UDim2.new(1, 0, 0, 60), ZIndex = 2 }, 0.6)
		S.Texte(l, { Position = UDim2.fromOffset(16, 9), Size = UDim2.fromOffset(380, 22), Text = titreL, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		S.Texte(l, { Position = UDim2.fromOffset(16, 34), Size = UDim2.fromOffset(420, 15), Text = sous, TextColor3 = S.C.Doux,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Contour = false }, "corps")
		return l
	end
	local glisse
	local function curseur(l, cle)
		local piste = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -86, 0.5, 0),
			Size = UDim2.fromOffset(250, 26), BackgroundTransparency = 1, ZIndex = 3 }, l)
		local fond = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 3 }, piste)
		local rempli = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 }, fond)
		new("UIGradient", { Color = ColorSequence.new(S.C.Violet, S.C.Or) }, rempli)
		local bouton = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18),
			Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5 }, piste)
		new("UIStroke", { Color = S.C.Or, Thickness = 2 }, bouton)
		local lueur = S.Icone(piste, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(60, 60),
			ImageColor3 = S.C.Or, ImageTransparency = 0.4, ZIndex = 4 })
		local val = S.Texte(l, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(50, 26), Text = "",
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 }, "chiffre")
		local function afficher(v)
			local a = v / 100
			rempli.Size = UDim2.fromScale(a, 1)
			bouton.Position = UDim2.fromScale(a, 0.5)
			lueur.Position = UDim2.fromScale(a, 0.5)
			val.Text = tostring(v)
		end
		local function depuis(x)
			local a = math.clamp((x - piste.AbsolutePosition.X) / math.max(piste.AbsoluteSize.X, 1), 0, 1)
			local v = math.floor(a * 100 + 0.5)
			if v ~= valeurs[cle] then appliquer(cle, v); afficher(v) end
		end
		piste.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				glisse = depuis
				depuis(input.Position.X)
				S.Tween(bouton, 0.15, { Size = UDim2.fromOffset(24, 24) })
				S.Son("Clic")
			end
		end)
		piste.InputEnded:Connect(function() S.Tween(bouton, 0.2, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Back) end)
		afficher(valeurs[cle])
		rafraichir[cle] = function() afficher(valeurs[cle]) end
	end
	UserInputService.InputChanged:Connect(function(input)
		if glisse and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			glisse(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then glisse = nil end
	end)
	local function interrupteur(l, cle)
		local b = S.Bouton(l, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(64, 30), ZIndex = 3 })
		local fond = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 }, b)
		new("UICorner", { CornerRadius = UDim.new(0, 5) }, fond)
		local grad = new("UIGradient", { Rotation = 90 }, fond)
		local pion = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4 }, b)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, pion)
		local function afficher(oui, anime)
			grad.Color = oui and ColorSequence.new(Color3.fromRGB(110, 245, 120), Color3.fromRGB(20, 150, 60))
				or ColorSequence.new(Color3.fromRGB(60, 45, 90), Color3.fromRGB(40, 28, 66))
			local pos = UDim2.new(oui and 1 or 0, oui and -17 or 17, 0.5, 0)
			if anime then S.Tween(pion, 0.25, { Position = pos }, Enum.EasingStyle.Back) else pion.Position = pos end
			pion.BackgroundColor3 = oui and Color3.new(1, 1, 1) or S.C.Doux
		end
		b.Activated:Connect(function()
			S.Son("Clic")
			appliquer(cle, not valeurs[cle])
			afficher(valeurs[cle], true)
		end)
		afficher(valeurs[cle], false)
		rafraichir[cle] = function() afficher(valeurs[cle], true) end
	end
	local function choixTouche(l, cle)
		local badge = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(40, 30),
			BackgroundColor3 = S.C.Or, ZIndex = 3 }, l)
		new("UICorner", { CornerRadius = UDim.new(0, 5) }, badge)
		local t = S.Texte(badge, { Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Text = Ctx.NomTouche(valeurs[cle]), TextColor3 = Color3.fromRGB(42, 22, 0),
			ZIndex = 4, Contour = false }, "chiffre")
		local attente = false
		local _, texteB = S.BoutonSkin(l, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(120, 38), ZIndex = 3 },
			"CHANGER", "sombre", function()
				attente = true
			end)
		local function maj() texteB.Text = attente and "APPUIE…" or "CHANGER" end
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if not attente then return end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Escape then
				attente = false
				appliquer(cle, input.KeyCode.Name)
				t.Text = Ctx.NomTouche(input.KeyCode.Name)
				S.Tween(badge, 0.1, { Size = UDim2.fromOffset(48, 36) })
				task.delay(0.1, function() S.Tween(badge, 0.3, { Size = UDim2.fromOffset(40, 30) }, Enum.EasingStyle.Back) end)
				maj()
			end
		end)
		table.insert(Ctx.Tick, function() if attente then texteB.Text = (os.clock() % 0.8 < 0.4) and "APPUIE…" or "" else maj() end end)
		rafraichir[cle] = function() t.Text = Ctx.NomTouche(valeurs[cle]) end
		return conn
	end

	local defSections = {
		{ "Son", "SON", {
			{ "MUSIQUE", "Volume de la musique", "curseur", "Musique" },
			{ "EFFETS SONORES", "Coups, impacts, interface", "curseur", "Effets" },
		} },
		{ "Graphismes", "GRAPHISMES", {
			{ "SECOUSSES DE CAMÉRA", "Quand tu frappes ou te fais toucher", "inter", "Secousses" },
			{ "MODE PERFORMANCE", "Moins d'effets pour les petits PC et les mobiles", "inter", "Performance" },
			{ "OMBRES", "Ombres en temps réel", "inter", "Ombres" },
		} },
		{ "Controles", "CONTRÔLES", {
			{ "TOUCHE D'ESQUIVE", "Clavier AZERTY ou QWERTY (manette : B)", "touche", "ToucheEsquive" },
		} },
		{ "Jeu", "JEU", {
			{ "FIL DES CAPTURES", "En haut à droite pendant la manche", "inter", "Fil" },
			{ "ALERTE DE DANGER", "Flèche quand un chasseur s'approche", "inter", "Danger" },
			{ "OUVERTURE RAPIDE", "Passe la roue des caisses", "inter", "OuvertureRapide" },
		} },
	}
	local ongletsP = {}
	local function sectionP(nom)
		for n, s in pairs(sections) do
			s.Visible = n == nom
			if n == nom then
				for i, l in ipairs(s:GetChildren()) do
					local p = l.Position
					l.Position = p + UDim2.fromOffset(60, 0)
					S.Tween(l, 0.3 + i * 0.05, { Position = p }, Enum.EasingStyle.Quart)
				end
			end
		end
		for n, a in pairs(ongletsP) do a(n == nom) end
	end
	for i, sdef in ipairs(defSections) do
		local _, actif = S.Onglet(cP, { Position = UDim2.fromOffset(30, 106 + (i - 1) * 62), Size = UDim2.fromOffset(192, 46), ZIndex = 2 }, sdef[2], function()
			sectionP(sdef[1])
		end)
		ongletsP[sdef[1]] = actif
		local s = new("Frame", { Name = sdef[1], Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, zoneLignes)
		sections[sdef[1]] = s
		for j, l in ipairs(sdef[3]) do
			local row = ligne(s, j, l[1], l[2])
			if l[3] == "curseur" then curseur(row, l[4])
			elseif l[3] == "inter" then interrupteur(row, l[4])
			elseif l[3] == "touche" then choixTouche(row, l[4])
			end
		end
	end
	sectionP("Son")
	-- paramètres sauvegardés arrivés après le démarrage (BranchementInterface)
	D.Change:Connect(function(cle)
		if cle ~= "Parametres" or type(D.Etat.Parametres) ~= "table" then return end
		for k, v in pairs(D.Etat.Parametres) do
			if valeurs[k] ~= nil and valeurs[k] ~= v then
				appliquer(k, v)
				if rafraichir[k] then rafraichir[k]() end
			end
		end
		sauvegarde += 1                                   -- pas de re-sauvegarde de ce qu'on vient de charger
	end)

	--==========================================================================================
	-- QUÊTES
	--==========================================================================================
	local fQ = Ctx.CreerFenetre("Quetes", Vector2.new(820, 560))
	local cQ = contenu(fQ)
	titre(cQ, "QUÊTES DU JOUR", "icone_quetes")
	Ctx.BoutonFermer(fQ)
	local listeQ = defilement(cQ, { Position = UDim2.fromOffset(30, 104), Size = UDim2.new(1, -60, 1, -150), ZIndex = 2 })
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, listeQ)
	new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4) }, listeQ)
	local renouvQ = S.Texte(cQ, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(500, 16), Text = "",
		TextColor3 = S.C.Doux, ZIndex = 2, Contour = false })
	local function construireQuetes()
		vider(listeQ)
		for i, q in ipairs(D.Etat.Quetes or {}) do
			local fini = (q.Progres or 0) >= (q.Objectif or 1)
			local l = S.Skin(listeQ, fini and not q.Reclamee and "skin_tuile_or" or "skin_tuile", { Size = UDim2.new(1, 0, 0, 96), LayoutOrder = i, ZIndex = 2 }, 0.5)
			S.Texte(l, { Position = UDim2.fromOffset(24, 16), Size = UDim2.fromOffset(400, 24), Text = string.upper(q.Nom or "?"),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "titre")
			local _, rempli = S.Barre(l, { Position = UDim2.fromOffset(24, 52), Size = UDim2.fromOffset(360, 10), ZIndex = 3 },
				ColorSequence.new(S.C.Violet, fini and S.C.Vert or S.C.Or))
			rempli.Size = UDim2.fromScale(0, 1)
			S.Tween(rempli, 0.6 + i * 0.1, { Size = UDim2.fromScale(math.clamp((q.Progres or 0) / math.max(q.Objectif or 1, 1), 0, 1), 1) }, Enum.EasingStyle.Quart)
			S.Texte(l, { Position = UDim2.fromOffset(394, 48), Size = UDim2.fromOffset(80, 18), Text = string.format("%d / %d", q.Progres or 0, q.Objectif or 1),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "chiffre")
			S.Icone(l, "icone_piece", { Position = UDim2.new(1, -262, 0, 22), Size = UDim2.fromOffset(48, 48), ZIndex = 3 })
			S.Texte(l, { Position = UDim2.new(1, -214, 0, 34), Size = UDim2.fromOffset(70, 24), Text = S.Nombre(q.Recompense or 0), TextColor3 = S.C.Or,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "chiffre")
			local zb = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(130, 50),
				BackgroundTransparency = 1, ZIndex = 3 }, l)
			if q.Reclamee then
				S.BoutonSkin(zb, { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, "FAIT", "sombre")
			elseif fini then
				local b = S.BoutonSkin(zb, { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, "RÉCLAMER", "vert", function(btn)
					if D.Actions.ReclamerQuete and D.Actions.ReclamerQuete(i) then
						Ctx.Etincelles(cQ, Ctx.Centre(btn) - Ctx.Centre(fQ) + UDim2.fromOffset(410, 280), S.C.Or, 16)
						if Ctx.Notifier then Ctx.Notifier("Quête terminée", S.C.Vert, q.Recompense) end
						construireQuetes()
					end
				end)
				task.spawn(function()
					while b.Parent do S.Reflet(b); task.wait(1.6) end
				end)
			else
				S.BoutonSkin(zb, { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, "EN COURS", "violet")
			end
		end
	end
	local repereQ, valeurQ = os.clock(), D.Etat.QuetesDans
	table.insert(Ctx.Tick, function()
		if not fQ.Visible then return end
		if valeurQ then
			renouvQ.Text = "NOUVELLES QUÊTES DANS " .. S.Temps(math.max(0, valeurQ - (os.clock() - repereQ)))
		else
			renouvQ.Text = "LES QUÊTES CHANGENT CHAQUE JOUR"
		end
	end)
	D.Change:Connect(function(cle)
		if cle == "Quetes" then construireQuetes()
		elseif cle == "QuetesDans" then repereQ, valeurQ = os.clock(), D.Etat.QuetesDans end
	end)
	construireQuetes()

	--==========================================================================================
	-- CADEAU DU JOUR
	--==========================================================================================
	local fG = Ctx.CreerFenetre("Cadeau", Vector2.new(560, 560))
	local cG = contenu(fG)
	titre(cG, "CADEAU DU JOUR")
	Ctx.BoutonFermer(fG)
	local gRayons = S.Icone(cG, "fx_rayons", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, 270), Size = UDim2.fromOffset(440, 440),
		ImageColor3 = S.C.Or, ImageTransparency = 0.55, ZIndex = 2 })
	local gIcone = S.Icone(cG, "icone_cadeau", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(280, 270), Size = UDim2.fromOffset(240, 240), ZIndex = 3 })
	local gTexte = S.Texte(cG, { Position = UDim2.fromOffset(30, 404), Size = UDim2.new(1, -60, 0, 20), Text = "", TextColor3 = S.C.Doux, ZIndex = 3, Contour = false })
	local gBouton = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(280, 440), Size = UDim2.fromOffset(260, 66), BackgroundTransparency = 1,
		ZIndex = 3 }, cG)
	local repereG, valeurG = os.clock(), D.Etat.CadeauDans or 0
	local function construireCadeau()
		vider(gBouton)
		if D.Etat.CadeauPret then
			gTexte.Text = "TON CADEAU T'ATTEND"
			S.BoutonSkin(gBouton, { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, "RÉCUPÉRER", "vert", function()
				if not D.Actions.RecupererCadeau then return end
				local ok, gain = D.Actions.RecupererCadeau()
				if ok then
					S.Tween(gIcone, 0.1, { Size = UDim2.fromOffset(300, 300), Rotation = 8 })
					task.delay(0.1, function() S.Tween(gIcone, 0.5, { Size = UDim2.fromOffset(240, 240), Rotation = 0 }, Enum.EasingStyle.Elastic) end)
					Ctx.Onde(cG, UDim2.fromOffset(280, 270), S.C.Or, 520, 0.6)
					Ctx.Etincelles(cG, UDim2.fromOffset(280, 270), S.C.Or, 24)
					if Ctx.Notifier then Ctx.Notifier("Cadeau récupéré", S.C.Vert, gain) end
					D.Mettre("CadeauPret", false)
				end
			end)
		else
			gTexte.Text = "PROCHAIN CADEAU DANS"
			S.BoutonSkin(gBouton, { Size = UDim2.fromScale(1, 1), ZIndex = 3 }, "…", "sombre")
		end
	end
	table.insert(Ctx.Tick, function()
		if not fG.Visible then return end
		local t = os.clock()
		gRayons.Rotation = t * 14
		gIcone.Position = UDim2.fromOffset(280, 270 + math.sin(t * 2.2) * 8)
		if D.Etat.CadeauPret then
			gIcone.Rotation = math.sin(t * 9) * (math.sin(t * 1.5) > 0.6 and 6 or 0)
		else
			local reste = math.max(0, valeurG - (t - repereG))
			local txt = gBouton:FindFirstChild("Texte", true)
			if txt then
				txt.Text = string.format("%d:%02d:%02d", reste // 3600, (reste % 3600) // 60, reste % 60)
			end
		end
	end)
	D.Change:Connect(function(cle)
		if cle == "CadeauPret" then construireCadeau()
		elseif cle == "CadeauDans" then repereG, valeurG = os.clock(), D.Etat.CadeauDans or 0 end
	end)
	construireCadeau()

	--==========================================================================================
	-- CLASSEMENT
	--==========================================================================================
	local fT = Ctx.CreerFenetre("Classement", Vector2.new(720, 600))
	local cT = contenu(fT)
	titre(cT, "CLASSEMENT", "icone_classement")
	Ctx.BoutonFermer(fT)
	local sousT = S.Texte(cT, { Position = UDim2.fromOffset(30, 92), Size = UDim2.new(1, -60, 0, 16), Text = "CAPTURES CETTE SEMAINE", TextColor3 = S.C.Doux,
		ZIndex = 2, Contour = false })
	local listeT = defilement(cT, { Position = UDim2.fromOffset(30, 122), Size = UDim2.new(1, -60, 1, -150), ZIndex = 2 })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, listeT)
	new("UIPadding", { PaddingRight = UDim.new(0, 10) }, listeT)
	local medailles = { Color3.fromRGB(255, 210, 63), Color3.fromRGB(200, 210, 230), Color3.fromRGB(215, 130, 70) }
	local function construireClassement()
		vider(listeT)
		if D.Etat.ClassementTitre then sousT.Text = D.Etat.ClassementTitre end
		for i, e in ipairs(D.Etat.Classement or {}) do
			local moi = e.Nom == joueur.Name or e.Nom == joueur.DisplayName
			local l = S.Skin(listeT, moi and "skin_tuile_or" or (i <= 3 and "skin_tuile" or "skin_ligne"), { Size = UDim2.new(1, 0, 0, i <= 3 and 68 or 54),
				LayoutOrder = i, ZIndex = 2 }, 0.5)
			local rang = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = medailles[i] or Color3.fromRGB(60, 45, 90), Rotation = 45, ZIndex = 3 }, l)
			new("UIStroke", { Color = S.C.Encre, Thickness = 2 }, rang)
			S.Texte(l, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 36, 0.5, 0), Size = UDim2.fromOffset(30, 22), Text = tostring(i),
				TextColor3 = i <= 3 and Color3.fromRGB(42, 22, 0) or S.C.Texte, ZIndex = 4, Contour = i > 3 }, "chiffre")
			S.Texte(l, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 76, 0.5, 0), Size = UDim2.fromOffset(330, i <= 3 and 26 or 20),
				Text = string.upper(e.Nom or "?"), TextColor3 = moi and S.C.Or or S.C.Texte, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "titre")
			S.Texte(l, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -22, 0.5, 0), Size = UDim2.fromOffset(140, i <= 3 and 28 or 22),
				Text = S.Nombre(e.Valeur or 0), TextColor3 = medailles[i] or S.C.Texte, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 }, "chiffre")
			-- entrée en cascade
			l.ImageTransparency = 1
			task.delay(i * 0.04, function() S.Tween(l, 0.3, { ImageTransparency = 0 }) end)
		end
	end
	function Ctx.AvantOuverture_Classement() construireClassement() end
	D.Change:Connect(function(cle) if cle == "Classement" or cle == "ClassementTitre" then construireClassement() end end)
	construireClassement()
end

return Panneaux
