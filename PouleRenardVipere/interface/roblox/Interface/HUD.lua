--[[ ModuleScript : ReplicatedStorage.Interface.HUD             — TRIPLE HUNT —
     Lobby : profil + niveau, prochaine manche, pièces, paramètres, raccourcis (boutique, quêtes, caisses,
             cadeau, couteaux, top), choix / affichage de l'équipe.
     Manche : « tu es / chasse / fuis », chrono, équipes (libres / total), fil des captures, alerte « X proche ! »,
             boutons tactiles FRAPPER / ESQUIVE (recharge) / SPRINT, combo, notifications de capture.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HUD = {}

function HUD.Init(Ctx)
	local S, D, joueur = Ctx.S, Ctx.D, Ctx.joueur
	local new = S.new
	local racine = Ctx.HUD
	Ctx.Tick = Ctx.Tick or {}

	local Config
	pcall(function() Config = require(ReplicatedStorage:WaitForChild("Couteaux", 5):WaitForChild("Config", 5)) end)
	local function equipeDe(p)
		if p == joueur and D.Etat.EquipeJoueur then return D.Etat.EquipeJoueur end
		if Config and Config.EquipeDe then return Config.EquipeDe(p) end
		return p:GetAttribute("Equipe")
	end

	local tactile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- groupes affichés selon le mode
	local lobby = new("Frame", { Name = "Lobby", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, racine)
	local manche = new("Frame", { Name = "Manche", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, racine)
	local commun = new("Frame", { Name = "Commun", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, racine)

	------------------------------------------------------------ profil (lobby)
	local profil = S.Skin(lobby, "skin_panneau", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(316, 86) }, 0.7)
	local avatar = new("ImageLabel", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = Color3.fromRGB(217, 122, 32),
		ZIndex = 2 }, profil)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, avatar)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 207, 122), Color3.fromRGB(217, 122, 32)) }, avatar)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(joueur.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then avatar.Image = img end
	end)
	local nomJ = S.Texte(profil, { Position = UDim2.fromOffset(82, 14), Size = UDim2.fromOffset(150, 22), Text = string.upper(joueur.DisplayName),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, "titre")
	local niveau = new("Frame", { Position = UDim2.fromOffset(238, 16), Size = UDim2.fromOffset(62, 20), BackgroundColor3 = S.C.Violet, ZIndex = 2 }, profil)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, niveau)
	local niveauT = S.Texte(niveau, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Text = "NIV 1", TextColor3 = Color3.fromRGB(26, 11, 51),
		ZIndex = 3, Contour = false }, "chiffre")
	local barreXP, rempliXP = S.Barre(profil, { Position = UDim2.fromOffset(82, 44), Size = UDim2.fromOffset(218, 9), ZIndex = 2 })
	local texteXP = S.Texte(profil, { Position = UDim2.fromOffset(82, 57), Size = UDim2.fromOffset(218, 14), Text = "", TextColor3 = S.C.Doux,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Contour = false })

	local function majProfil()
		local e = D.Etat
		niveauT.Text = "NIV " .. tostring(e.Niveau or 1)
		local p = math.clamp((e.XP or 0) / math.max(e.XPMax or 1, 1), 0, 1)
		S.Tween(rempliXP, 0.6, { Size = UDim2.fromScale(p, 1) }, Enum.EasingStyle.Quart)
		texteXP.Text = S.Nombre(e.XP or 0) .. " / " .. S.Nombre(e.XPMax or 0) .. " XP"
	end

	------------------------------------------------------------ prochaine manche (lobby)
	local attente = S.Skin(lobby, "skin_panneau", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(340, 78) }, 0.7)
	local attenteT = S.Texte(attente, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 16), Text = "PROCHAINE MANCHE DANS",
		TextColor3 = S.C.Doux, ZIndex = 2, Contour = false })
	local attenteN = S.Texte(attente, { Position = UDim2.fromOffset(20, 32), Size = UDim2.new(1, -40, 0, 34), Text = "0:00", TextColor3 = S.C.Or, ZIndex = 2 }, "chiffre")
	S.Separateur(lobby, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 94), Size = UDim2.fromOffset(280, 1) })

	------------------------------------------------------------ pièces + paramètres (commun)
	local pieces = S.Skin(commun, "skin_panneau", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -90, 0, 12), Size = UDim2.fromOffset(214, 64) }, 0.7)
	local iconePiece = S.Icone(pieces, "icone_piece", { Position = UDim2.fromOffset(-6, -4), Size = UDim2.fromOffset(62, 62), ZIndex = 3 })
	local piecesT = S.Texte(pieces, { Position = UDim2.fromOffset(62, 16), Size = UDim2.fromOffset(100, 30), Text = "0", TextColor3 = S.C.Or,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, "chiffre")
	local plus = S.BoutonSkin(pieces, { Position = UDim2.new(1, -46, 0, 13), Size = UDim2.fromOffset(36, 36), ZIndex = 3 }, "+", "vert", function(b)
		Ctx.Ouvrir("Boutique", b, "Pieces")
	end)
	local reglages = S.Bouton(commun, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(68, 68) }, function(b)
		Ctx.Ouvrir("Parametres", b)
	end)
	S.Skin(reglages, "skin_tuile", { Size = UDim2.fromScale(1, 1) }, 0.6)
	local iconeReglages = S.Icone(reglages, "icone_parametres", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(50, 50), ZIndex = 2 })
	reglages.MouseEnter:Connect(function() S.Tween(iconeReglages, 0.5, { Rotation = iconeReglages.Rotation + 90 }, Enum.EasingStyle.Back) end)

	local valeurPieces = 0
	local function majPieces(anime)
		local cible = D.Etat.Pieces or 0
		local depart = valeurPieces
		valeurPieces = cible
		if not anime or cible == depart then piecesT.Text = S.Nombre(cible) return end
		local diff = cible - depart
		if diff > 0 then
			local flot = S.Texte(commun, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 72), Size = UDim2.fromOffset(120, 26),
				Text = "+" .. S.Nombre(diff), TextColor3 = S.C.Or, ZIndex = 20 }, "chiffre")
			S.Tween(flot, 1.1, { Position = UDim2.new(1, -110, 0, 40), TextTransparency = 1 }, Enum.EasingStyle.Quart)
			task.delay(1.2, function() flot:Destroy() end)
			S.Tween(iconePiece, 0.12, { Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset(-12, -10) })
			task.delay(0.12, function() S.Tween(iconePiece, 0.35, { Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(-6, -4) }, Enum.EasingStyle.Back) end)
		end
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < 0.8 do
				local a = (os.clock() - t0) / 0.8
				piecesT.Text = S.Nombre(depart + diff * (1 - (1 - a) ^ 3))
				task.wait()
			end
			piecesT.Text = S.Nombre(cible)
		end)
	end

	------------------------------------------------------------ raccourcis (lobby)
	local dock = new("Frame", { Name = "Dock", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 126), Size = UDim2.fromOffset(200, 340) }, lobby)
	local tuiles = {}
	local liste = {
		{ "Boutique", "icone_boutique", "BOUTIQUE", function(b) Ctx.Ouvrir("Boutique", b, "Pieces") end },
		{ "Quetes", "icone_quetes", "QUÊTES", function(b) Ctx.Ouvrir("Quetes", b) end },
		{ "Caisses", "icone_caisses", "CAISSES", function(b) Ctx.Ouvrir("Boutique", b, "Caisses") end, true },
		{ "Cadeau", "icone_cadeau", "CADEAU", function(b) Ctx.Ouvrir("Cadeau", b) end },
		{ "Couteaux", "icone_couteaux", "COUTEAUX", function(b) Ctx.Ouvrir("Boutique", b, "Couteaux") end },
		{ "Classement", "icone_classement", "TOP", function(b) Ctx.Ouvrir("Classement", b) end },
	}
	for i, t in ipairs(liste) do
		local col, lig = (i - 1) % 2, (i - 1) // 2
		local b = S.Bouton(dock, { Name = t[1], Position = UDim2.fromOffset(col * 98, lig * 110), Size = UDim2.fromOffset(94, 100) }, t[4])
		local halo
		if t[5] then
			halo = S.Icone(b, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(150, 150),
				ImageColor3 = S.C.Or, ImageTransparency = 0.5, ZIndex = 0 })
		end
		S.Skin(b, t[5] and "skin_tuile_or" or "skin_tuile", { Size = UDim2.fromScale(1, 1), ZIndex = 1 }, 0.6)
		local ic = S.Icone(b, t[2], { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(72, 72), ZIndex = 3 })
		local lab = S.Texte(b, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -14, 0, 15), Text = t[3],
			TextColor3 = t[5] and S.C.Or or S.C.Texte, ZIndex = 3 })
		local pastille, pastilleT = S.Pastille(b, nil)
		tuiles[t[1]] = { bouton = b, icone = ic, pastille = pastille, pastilleT = pastilleT, halo = halo, phase = i * 0.7 }
		b.MouseEnter:Connect(function() S.Tween(ic, 0.25, { Position = UDim2.new(0.5, 0, 0, -14), Rotation = -6 }, Enum.EasingStyle.Back) end)
		b.MouseLeave:Connect(function() S.Tween(ic, 0.25, { Position = UDim2.new(0.5, 0, 0, -6), Rotation = 0 }) end)
		-- entrée en glissant depuis la gauche
		local p0 = b.Position
		b.Position = p0 - UDim2.fromOffset(240, 0)
		task.delay(0.15 + i * 0.06, function() S.Tween(b, 0.5, { Position = p0 }, Enum.EasingStyle.Back) end)
	end
	-- respiration du halo des caisses + reflet régulier
	local tReflet = 0
	table.insert(Ctx.Tick, function(dt)
		local t = os.clock()
		local c = tuiles.Caisses
		if c and c.halo then
			c.halo.ImageTransparency = 0.45 + 0.25 * math.sin(t * 2.4)
			c.halo.Size = UDim2.fromOffset(140 + 14 * math.sin(t * 2.4), 140 + 14 * math.sin(t * 2.4))
		end
		tReflet += dt
		if tReflet > 3.5 and lobby.Visible then
			tReflet = 0
			S.Reflet(tuiles.Caisses.bouton)
		end
	end)

	local function pastille(nom, texte, couleur)
		local t = tuiles[nom]
		if not t then return end
		t.pastille.Visible = texte ~= nil
		t.pastilleT.Text = texte or ""
		if couleur then t.pastille.BackgroundColor3 = couleur end
	end
	local function majPastilles()
		local e = D.Etat
		pastille("Caisses", (e.CaissesGratuites or 0) > 0 and tostring(e.CaissesGratuites) or nil)
		pastille("Cadeau", e.CadeauPret and "!" or nil, Color3.fromRGB(34, 197, 94))
		local n = 0
		for _, q in ipairs(e.Quetes or {}) do
			if (q.Progres or 0) >= (q.Objectif or 1) and not q.Reclamee then n += 1 end
		end
		pastille("Quetes", n > 0 and tostring(n) or nil)
	end

	------------------------------------------------------------ choix de l'équipe (lobby)
	local zoneEquipes = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(700, 110),
		BackgroundTransparency = 1 }, lobby)
	local ombreBas = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = Color3.fromRGB(10, 5, 24), BackgroundTransparency = 0.3, ZIndex = 0 }, lobby)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.25) }, ombreBas)
	local titreEquipes = S.Texte(zoneEquipes, { Size = UDim2.new(1, 0, 0, 18), Text = "CHOISIS TON ÉQUIPE", ZIndex = 2 })
	local cartes = {}
	for i, eq in ipairs({ "Poules", "Renards", "Vipères" }) do
		local info = S.Equipes[eq]
		local b = S.Bouton(zoneEquipes, { Position = UDim2.fromOffset((i - 1) * 236, 30), Size = UDim2.fromOffset(220, 76), ZIndex = 2 }, function()
			if D.Actions.ChoisirEquipe then
				task.spawn(D.Actions.ChoisirEquipe, eq)
				D.Mettre("EquipeJoueur", eq)
			end
		end)
		local fond = S.Skin(b, "skin_bouton_sombre", { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, 0.6)
		new("Frame", { Position = UDim2.fromOffset(10, 14), Size = UDim2.new(0, 4, 1, -28), BackgroundColor3 = info.Couleur, BorderSizePixel = 0, ZIndex = 3 }, b)
		S.Texte(b, { Position = UDim2.fromOffset(24, 14), Size = UDim2.new(1, -36, 0, 26), Text = info.Nom, TextColor3 = info.Couleur,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "titre")
		local sous = S.Texte(b, { Position = UDim2.fromOffset(24, 44), Size = UDim2.new(1, -36, 0, 16), Text = "",
			TextColor3 = S.C.Doux, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Contour = false })
		local lueur = S.Icone(b, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 160),
			ImageColor3 = info.Couleur, ImageTransparency = 1, ZIndex = 1 })
		cartes[eq] = { bouton = b, sous = sous, lueur = lueur, fond = fond }
	end
	local function majEquipes()
		local mien = equipeDe(joueur)
		local choix = D.Actions.ChoisirEquipe ~= nil
		titreEquipes.Text = choix and "CHOISIS TON ÉQUIPE" or "TON ÉQUIPE"
		local comptes = { Poules = 0, Renards = 0, ["Vipères"] = 0 }
		for _, p in ipairs(Players:GetPlayers()) do
			local e = equipeDe(p)
			if e and comptes[e] then comptes[e] += 1 end
		end
		for eq, c in pairs(cartes) do
			local info = S.Equipes[eq]
			c.sous.Text = string.format("%d JOUEUR%s · CHASSENT LES %s", comptes[eq], comptes[eq] > 1 and "S" or "", S.Equipes[info.Cible].Nom)
			c.bouton.Visible = choix or eq == mien
			S.Tween(c.lueur, 0.3, { ImageTransparency = (eq == mien) and 0.45 or 1 })
		end
		if not choix then
			local c = cartes[mien or ""]
			if c then c.bouton.Position = UDim2.fromOffset(240, 30) end
		end
	end

	------------------------------------------------------------ MANCHE : rôle
	local role = S.Skin(manche, "skin_panneau", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(230, 126) }, 0.7)
	S.Texte(role, { Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(150, 13), Text = "TU ES", TextColor3 = S.C.Doux,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Contour = false })
	local roleNom = S.Texte(role, { Position = UDim2.fromOffset(18, 28), Size = UDim2.fromOffset(190, 28), Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2 }, "titre")
	local function ligneRole(y)
		local barre = new("Frame", { Position = UDim2.fromOffset(18, y), Size = UDim2.fromOffset(6, 18), BorderSizePixel = 0, ZIndex = 2 }, role)
		local t = S.Texte(role, { Position = UDim2.fromOffset(32, y), Size = UDim2.fromOffset(180, 18), Text = "", TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2, Contour = false })
		return barre, t
	end
	local barreChasse, texteChasse = ligneRole(66)
	local barreFuis, texteFuis = ligneRole(92)
	local function majRole()
		local eq = equipeDe(joueur)
		local info = S.Equipes[eq or ""]
		if not info then roleNom.Text = "SPECTATEUR"; return end
		roleNom.Text = info.Un
		roleNom.TextColor3 = info.Couleur
		local cible, menace = S.Equipes[info.Cible], S.Equipes[info.Menace]
		barreChasse.BackgroundColor3 = cible.Couleur
		barreFuis.BackgroundColor3 = menace.Couleur
		texteChasse.Text = string.format('CHASSE LES <font color="#%s">%s</font>', cible.Couleur:ToHex(), cible.Nom)
		texteFuis.Text = string.format('FUIS LES <font color="#%s">%s</font>', menace.Couleur:ToHex(), menace.Nom)
	end

	------------------------------------------------------------ MANCHE : chrono + équipes
	local chrono = S.Skin(manche, "skin_panneau", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(220, 92) }, 0.7)
	local chronoManche = S.Texte(chrono, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 14), Text = "MANCHE 1", TextColor3 = S.C.Doux,
		ZIndex = 2, Contour = false })
	local chronoT = S.Texte(chrono, { Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -40, 0, 46), Text = "3:00", TextColor3 = S.C.Or, ZIndex = 2 }, "chiffre")
	local chronoEchelle = new("UIScale", { Scale = 1 }, chrono)

	local barresEquipes = {}
	local function barreEquipe(eq, pos, taille)
		local info = S.Equipes[eq]
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = pos, Size = taille, BackgroundTransparency = 1 }, manche)
		S.Skin(f, "skin_onglet", { Size = UDim2.fromScale(1, 1) }, 0.6)
		local n = S.Texte(f, { Position = UDim2.fromOffset(26, 8), Size = UDim2.new(0, 34, 1, -16), Text = "0", TextColor3 = info.Couleur, ZIndex = 2 }, "chiffre")
		S.Texte(f, { Position = UDim2.fromOffset(64, 9), Size = UDim2.new(0, 90, 0, 18), Text = info.Nom, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
		local points = new("Frame", { Position = UDim2.fromOffset(64, 31), Size = UDim2.fromOffset(110, 6), BackgroundTransparency = 1, ZIndex = 2 }, f)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3) }, points)
		local trait = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -6), Size = UDim2.new(0, 0, 0, 3), BackgroundColor3 = info.Couleur,
			BorderSizePixel = 0, ZIndex = 2 }, f)
		barresEquipes[eq] = { cadre = f, n = n, points = points, trait = trait, couleur = info.Couleur, ancien = -1 }
	end
	barreEquipe("Poules", UDim2.new(0.5, -250, 0, 12), UDim2.fromOffset(210, 56))
	barreEquipe("Renards", UDim2.new(0.5, 250, 0, 12), UDim2.fromOffset(210, 56))
	barreEquipe("Vipères", UDim2.new(0.5, 0, 0, 102), UDim2.fromOffset(210, 50))

	local function majEquipesManche()
		local m = D.Etat.Manche or {}
		chronoManche.Text = "MANCHE " .. tostring(m.Numero or 1)
		for eq, b in pairs(barresEquipes) do
			local d = (m.Equipes or {})[eq] or { Libres = 0, Total = 0 }
			b.n.Text = tostring(d.Libres)
			if d.Libres ~= b.ancien then
				if b.ancien >= 0 and d.Libres < b.ancien then
					-- une capture dans cette équipe : la barre tressaille
					S.Tween(b.cadre, 0.06, { Rotation = -3 })
					task.delay(0.06, function() S.Tween(b.cadre, 0.3, { Rotation = 0 }, Enum.EasingStyle.Elastic) end)
				end
				b.ancien = d.Libres
			end
			for _, c in ipairs(b.points:GetChildren()) do
				if c:IsA("Frame") then c:Destroy() end
			end
			for i = 1, math.min(d.Total, 10) do
				local p = new("Frame", { Size = UDim2.fromOffset(14, 5), BackgroundColor3 = i <= d.Libres and b.couleur or Color3.fromRGB(58, 45, 85),
					BorderSizePixel = 0, ZIndex = 2 }, b.points)
				new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) }, p)
			end
			S.Tween(b.trait, 0.4, { Size = UDim2.new((d.Total > 0 and d.Libres / d.Total or 0) * 0.86, 0, 0, 3) })
		end
	end

	------------------------------------------------------------ chronos (décompte local entre deux mises à jour)
	local repere, valeurRepere, repereAttente, valeurAttente = os.clock(), 0, os.clock(), 0
	local dernierTic = -1
	local function majTemps()
		local m = D.Etat.Manche or {}
		repere, valeurRepere = os.clock(), m.TempsRestant or 0
		repereAttente, valeurAttente = os.clock(), m.AvantDebut or 0
	end
	table.insert(Ctx.Tick, function()
		local reste = math.max(0, valeurRepere - (os.clock() - repere))
		chronoT.Text = S.Temps(math.ceil(reste))
		if reste <= 10 and reste > 0 and manche.Visible then
			chronoT.TextColor3 = Color3.fromRGB(255, 90, 80)
			local s = math.ceil(reste)
			if s ~= dernierTic then
				dernierTic = s
				chronoEchelle.Scale = 1.15
				S.Tween(chronoEchelle, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				S.Son("Tic", 1.4, 0.3)
			end
		else
			chronoT.TextColor3 = S.C.Or
		end
		local att = math.max(0, valeurAttente - (os.clock() - repereAttente))
		attenteN.Text = (D.Etat.Manche and D.Etat.Manche.AvantDebut) and S.Temps(math.ceil(att)) or "…"
		attenteT.Text = (D.Etat.Manche and D.Etat.Manche.AvantDebut) and "PROCHAINE MANCHE DANS" or "EN ATTENTE DE JOUEURS"
	end)

	------------------------------------------------------------ fil des captures
	local fil = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 100), Size = UDim2.fromOffset(320, 200),
		BackgroundTransparency = 1 }, commun)
	new("UIListLayout", { Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }, fil)
	local ordreFil = 0
	local function ajouterFil(texteRiche, vert)
		if joueur:GetAttribute("Param_Fil") == false then return end
		ordreFil += 1
		local l = new("Frame", { Size = UDim2.fromOffset(310, 32), BackgroundColor3 = vert and Color3.fromRGB(20, 120, 50) or S.C.Fond,
			BackgroundTransparency = 0.12, LayoutOrder = -ordreFil, ClipsDescendants = true }, fil)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1),
			NumberSequenceKeypoint.new(1, 0) }) }, l)
		local t = S.Texte(l, { Position = UDim2.fromOffset(310, 7), Size = UDim2.new(1, -20, 0, 18), Text = texteRiche, TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2, Contour = false })
		S.Tween(t, 0.35, { Position = UDim2.fromOffset(8, 7) }, Enum.EasingStyle.Quart)
		local enfants = {}
		for _, c in ipairs(fil:GetChildren()) do if c:IsA("Frame") then table.insert(enfants, c) end end
		if #enfants > 5 then table.sort(enfants, function(a, b) return a.LayoutOrder < b.LayoutOrder end); enfants[#enfants]:Destroy() end
		task.delay(6, function()
			if l.Parent then
				S.Tween(l, 0.4, { BackgroundTransparency = 1 })
				S.Tween(t, 0.4, { TextTransparency = 1 })
				task.delay(0.45, function() l:Destroy() end)
			end
		end)
	end
	local function hex(eq) local i = S.Equipes[eq or ""]; return i and i.Couleur:ToHex() or "efe9ff" end
	local function filCapture(a, ea, v, ev, special)
		if special then
			ajouterFil(string.format('<font color="#%s">%s</font>  %s', hex(ea), a or "?", special), true)
		else
			ajouterFil(string.format('<font color="#%s">%s</font>  <font color="#b9acdf">ATTRAPE</font>  <font color="#%s">%s</font>',
				hex(ea), a or "?", hex(ev), v or "?"))
		end
	end
	D.Capture:Connect(filCapture)

	------------------------------------------------------------ notifications (bas, centre)
	local zoneNotif = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(560, 60),
		BackgroundTransparency = 1 }, commun)
	local function notifier(texte, couleur, gain)
		couleur = couleur or S.C.Vert
		for _, c in ipairs(zoneNotif:GetChildren()) do c:Destroy() end
		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 58),
			BackgroundColor3 = couleur, BackgroundTransparency = 0.08, ClipsDescendants = true }, zoneNotif)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0.05),
			NumberSequenceKeypoint.new(0.82, 0.05), NumberSequenceKeypoint.new(1, 1) }) }, b)
		local ligne = new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, b)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1) }) }, ligne)
		local t = S.Texte(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(gain and 0.42 or 0.5, 0.5), Size = UDim2.fromOffset(300, 30),
			Text = string.upper(texte), ZIndex = 3, TextTransparency = 1 }, "titre")
		if gain then
			S.Icone(b, "icone_piece", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.68, 0.5), Size = UDim2.fromOffset(36, 36), ZIndex = 3 })
			S.Texte(b, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.72, 0, 0.5, 0), Size = UDim2.fromOffset(90, 26),
				Text = "+" .. S.Nombre(gain), TextColor3 = S.C.Or, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, "chiffre")
		end
		S.Tween(b, 0.35, { Size = UDim2.fromOffset(540, 58) }, Enum.EasingStyle.Quart)
		S.Tween(t, 0.3, { TextTransparency = 0 })
		Ctx.Onde(zoneNotif, UDim2.fromScale(0.5, 0.5), couleur, 300, 0.6)
		S.Son("Gain")
		task.delay(2.2, function()
			if b.Parent then
				S.Tween(b, 0.3, { Size = UDim2.fromOffset(40, 58), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				S.Tween(t, 0.2, { TextTransparency = 1 })
				task.delay(0.32, function() b:Destroy() end)
			end
		end)
	end
	Ctx.Notifier = notifier
	D.Notification:Connect(notifier)

	-- captures vues par le client (vrais joueurs, via les effets des couteaux)
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Couteaux", 10)
		remotes = remotes and remotes:WaitForChild("Remotes", 10)
		local rfx = remotes and remotes:WaitForChild("FX", 10)
		if not rfx then return end
		rfx.OnClientEvent:Connect(function(type_, _, _, _, attaquant, victime)
			if type_ ~= "Impact" then return end
			if typeof(attaquant) == "Instance" and typeof(victime) == "Instance" then
				filCapture(attaquant.DisplayName, equipeDe(attaquant), victime.DisplayName, equipeDe(victime))
				if attaquant == joueur then notifier("Capture !", S.C.Vert) end
				if victime == joueur then notifier("Tu es attrapé !", Color3.fromRGB(200, 40, 50)) end
			end
		end)
	end)

	------------------------------------------------------------ alerte « X proche ! »
	local alerte = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, manche)
	local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 70, 50), BackgroundTransparency = 0.55 }, alerte)
	local vigGrad = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(1, 1) }) }, vignette)
	local fleche = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 80), BackgroundTransparency = 1 }, alerte)
	local flecheT = S.Texte(fleche, { Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = Color3.fromRGB(255, 122, 98) }, "titre")
	local flecheI = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(255, 122, 98), Rotation = 45 }, fleche)
	new("UIStroke", { Color = S.C.Encre, Thickness = 2 }, flecheI)
	local cible = nil
	local accu = 0
	table.insert(Ctx.Tick, function(dt)
		accu += dt
		if accu > 0.15 then
			accu = 0
			cible = nil
			if manche.Visible and joueur:GetAttribute("Param_Danger") ~= false and not joueur:GetAttribute("EnPrison") then
				local mien = equipeDe(joueur)
				local menace = mien and S.Equipes[mien] and S.Equipes[mien].Menace
				local moi = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
				if menace and moi then
					local meilleur = 38
					local function tester(modele, eq)
						local r = modele and modele:FindFirstChild("HumanoidRootPart")
						if r and eq == menace then
							local d = (r.Position - moi.Position).Magnitude
							if d < meilleur then meilleur, cible = d, r end
						end
					end
					for _, p in ipairs(Players:GetPlayers()) do
						if p ~= joueur and not p:GetAttribute("EnPrison") then tester(p.Character, equipeDe(p)) end
					end
					for _, m in ipairs(workspace:GetChildren()) do      -- bots : modèles avec l'attribut « Equipe »
						if m:IsA("Model") and m:GetAttribute("Equipe") and not Players:GetPlayerFromCharacter(m) and not m:GetAttribute("EnPrison") then
							tester(m, m:GetAttribute("Equipe"))
						end
					end
				end
			end
		end
		alerte.Visible = cible ~= nil
		if cible then
			local cam = workspace.CurrentCamera
			local rel = cam.CFrame:PointToObjectSpace(cible.Position)
			local dir = Vector2.new(rel.X, -rel.Y)
			if rel.Z < 0 and math.abs(rel.X / -rel.Z) < 0.6 then
				alerte.Visible = false                           -- devant et à l'écran : pas besoin d'alerte
				return
			end
			if dir.Magnitude < 0.01 then dir = Vector2.new(0, 1) end
			dir = dir.Unit
			local ang = math.atan2(dir.Y, dir.X)
			fleche.Position = UDim2.fromScale(0.5 + math.cos(ang) * 0.42, 0.5 + math.sin(ang) * 0.38)
			flecheI.Rotation = math.deg(ang) + 45 - 90
			vigGrad.Rotation = math.deg(ang) + 180
			local menace = S.Equipes[S.Equipes[equipeDe(joueur) or ""] and S.Equipes[equipeDe(joueur)].Menace or ""]
			flecheT.Text = menace and (menace.Un .. " PROCHE !") or ""
			vignette.BackgroundTransparency = 0.55 + 0.15 * math.sin(os.clock() * 8)
		end
	end)

	------------------------------------------------------------ boutons d'action (tactile) + recharge d'esquive
	local actions = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(340, 260),
		BackgroundTransparency = 1 }, manche)
	local function boutonRond(nom, icone, label, couleur, pos, taille, rappel)
		local b = S.Bouton(actions, { Name = nom, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(taille, taille) }, rappel)
		local anneau = S.Icone(b, "skin_anneau_segments", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.18, 1.18), ImageColor3 = couleur, ZIndex = 1 })
		local halo = S.Icone(b, "fx_braise", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7),
			ImageColor3 = couleur, ImageTransparency = 0.7, ZIndex = 0 })
		S.Icone(b, "skin_cercle", { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
		local ic = S.Icone(b, icone, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.56, 0.56), ZIndex = 3 })
		S.Texte(b, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.7, 0.13), Text = label, ZIndex = 3 })
		local voileRecharge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 4 }, b)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, voileRecharge)
		local recharge = S.Texte(voileRecharge, { Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.25, 0.35), Text = "", ZIndex = 5 }, "chiffre")
		return { bouton = b, anneau = anneau, halo = halo, icone = ic, voile = voileRecharge, recharge = recharge, couleur = couleur }
	end
	local function frapper()
		local char = joueur.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local tool
		for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then tool = t end end
		if not tool then
			for _, t in ipairs(joueur.Backpack:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("CouteauId") then hum:EquipTool(t); tool = t; break end
			end
		end
		if tool then tool:Activate() end
	end
	local function esquiver()
		local c = ReplicatedStorage:FindFirstChild("Couteaux")
		local e = c and c:FindFirstChild("EsquiveDemande")
		if e then e:Fire() end
	end
	local bFrapper = boutonRond("Frapper", "icone_frapper", "FRAPPER", S.C.Poule, UDim2.new(1, -75, 1, -75), 150, function(b)
		frapper()
		Ctx.Onde(actions, UDim2.new(1, -75, 1, -75), S.C.Poule, 230, 0.35)
	end)
	local bEsquive = boutonRond("Esquive", "icone_esquive", "ESQUIVE", S.C.Cyan, UDim2.new(1, -230, 1, -52), 104, function() esquiver() end)
	local touche = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.85, 0, 0.08, 0), Size = UDim2.fromOffset(28, 22),
		BackgroundColor3 = S.C.Or, ZIndex = 6, Visible = not tactile }, bEsquive.bouton)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, touche)
	local toucheT = S.Texte(touche, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Text = "A", TextColor3 = Color3.fromRGB(42, 22, 0),
		ZIndex = 7, Contour = false }, "chiffre")
	local bSprint
	if D.Actions.Sprint then
		local actif = false
		bSprint = boutonRond("Sprint", "icone_sprint", "SPRINT", S.C.Or, UDim2.new(1, -212, 1, -184), 82, function()
			actif = not actif
			D.Actions.Sprint(actif)
		end)
	end
	-- sur PC : seul l'indicateur d'esquive reste (les touches font le reste)
	if not tactile then
		bFrapper.bouton.Visible = false
		bEsquive.bouton.Position = UDim2.new(1, -60, 1, -60)
		bEsquive.bouton.Size = UDim2.fromOffset(92, 92)
		if bSprint then bSprint.bouton.Visible = false end
	end
	local function majTouche()
		toucheT.Text = Ctx.NomTouche(joueur:GetAttribute("Param_ToucheEsquive") or "Q")
	end
	joueur:GetAttributeChangedSignal("Param_ToucheEsquive"):Connect(majTouche)
	majTouche()
	-- CouteauxClient n'affiche plus son propre bouton tactile d'esquive : c'est celui-ci qui le remplace
	joueur:SetAttribute("InterfaceActive", true)
	local etaitPret = true
	table.insert(Ctx.Tick, function()
		local t = os.clock()
		bFrapper.anneau.Rotation = t * 20
		bEsquive.anneau.Rotation = -t * 25
		if bSprint then bSprint.anneau.Rotation = t * 30 end
		local debut, duree = joueur:GetAttribute("EsquiveDebut"), joueur:GetAttribute("EsquiveRecharge")
		local reste = (debut and duree) and math.max(0, duree - (os.clock() - debut)) or 0
		if reste > 0 then
			bEsquive.voile.BackgroundTransparency = 0.45
			bEsquive.recharge.Text = string.format("%.1f", reste)
			bEsquive.anneau.ImageTransparency = 0.7
			etaitPret = false
		else
			bEsquive.voile.BackgroundTransparency = 1
			bEsquive.recharge.Text = ""
			bEsquive.anneau.ImageTransparency = 0
			if not etaitPret then
				etaitPret = true
				Ctx.Onde(actions, bEsquive.bouton.Position, S.C.Cyan, 170, 0.4)
			end
		end
	end)

	------------------------------------------------------------ combo
	local combo = S.Texte(manche, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -214), Size = UDim2.fromOffset(200, 34), Text = "",
		TextColor3 = S.C.Or, Rotation = -6, ZIndex = 10 }, "titre")
	local comboEchelle = new("UIScale", { Scale = 1 }, combo)
	joueur:GetAttributeChangedSignal("CouteauxCombo"):Connect(function()
		local c = joueur:GetAttribute("CouteauxCombo")
		if not c or c < 2 then return end
		combo.Text = "COMBO x" .. c
		combo.TextTransparency = 0
		comboEchelle.Scale = 1.6
		S.Tween(comboEchelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.9, function() S.Tween(combo, 0.3, { TextTransparency = 1 }) end)
	end)

	------------------------------------------------------------ bascule lobby / manche (avec transition)
	local enManche = nil
	local function majMode()
		local actif = D.Etat.Manche and D.Etat.Manche.Active or false
		if actif == enManche then return end
		enManche = actif
		local sortant, entrant = actif and lobby or manche, actif and manche or lobby
		S.Son(actif and "Lame" or "Ouvrir")
		sortant.Visible = false
		entrant.Visible = true
		for _, c in ipairs(entrant:GetChildren()) do
			if c:IsA("GuiObject") and c ~= alerte then
				local p = c.Position
				c.Position = p + UDim2.fromOffset(0, (p.Y.Scale > 0.5) and 140 or -140)
				S.Tween(c, 0.5, { Position = p }, Enum.EasingStyle.Back)
			end
		end
	end

	-- masquer le HUD quand une fenêtre est ouverte
	function Ctx.HUDMasquer(oui)
		lobby.Visible = (not oui) and not enManche
		manche.Visible = (not oui) and (enManche == true)
	end

	------------------------------------------------------------ écoute des données
	D.Change:Connect(function(cle)
		if cle == "Pieces" then majPieces(true)
		elseif cle == "Niveau" or cle == "XP" or cle == "XPMax" then majProfil()
		elseif cle == "CaissesGratuites" or cle == "CadeauPret" or cle == "Quetes" then majPastilles()
		elseif cle == "Manche" then majTemps(); majEquipesManche(); majMode(); majEquipes()
		elseif cle == "EquipeJoueur" then majRole(); majEquipes()
		end
	end)
	joueur:GetPropertyChangedSignal("Team"):Connect(function() majRole(); majEquipes() end)
	Players.PlayerAdded:Connect(majEquipes)
	Players.PlayerRemoving:Connect(function() task.wait(); majEquipes() end)

	majPieces(false); majProfil(); majPastilles(); majTemps(); majEquipesManche(); majRole(); majEquipes(); majMode()
end

return HUD
