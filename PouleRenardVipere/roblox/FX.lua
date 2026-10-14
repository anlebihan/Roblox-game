--[[ ModuleScript : ReplicatedStorage.Couteaux.FX   (utilisé côté CLIENT uniquement)
     Effets visuels (VFX) et sonores (SFX) des couteaux :
       FX.Equiper(tool)              aura, lueur, traînée prête, son + éclat de dégainage
       FX.Coup(tool, combo)          traînée lumineuse + son de coup (combo 1-2-3)
       FX.Impact(pos, id, victime)   explosion propre à chaque couteau + son + flash sur la victime
       FX.Esquive(character, equipe) images fantômes + nuage de poussière + son
       FX.Secousse(force, duree)     secousse de caméra
       FX.EsquiveParfaite(vChar, aChar, equipe)   traînée de fantômes dorés, ondes, « ding », lame de l'attaquant
                                                   qui ricoche, étoiles qui tournent au-dessus de l'attaquant désarmé
       FX.Ralenti(duree)             effet « ralenti » sur l'écran du joueur qui a fait l'esquive parfaite
]]
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local FX = {}

-- réglages du joueur (fenêtre Paramètres de l'interface) : moins d'effets / pas de secousses
local joueurLocal = game:GetService("Players").LocalPlayer
local function performance() return joueurLocal ~= nil and joueurLocal:GetAttribute("Param_Performance") == true end

local TEX = {
	etincelles = "rbxasset://textures/particles/sparkles_main.dds",
	feu = "rbxasset://textures/particles/fire_main.dds",
	fumee = "rbxasset://textures/particles/smoke_main.dds",
}

local function NS(a, b) return NumberSequence.new(a, b) end
local function NR(a, b) return NumberRange.new(a, b or a) end
local function CS(a, b) return ColorSequence.new(a, b or a) end

local function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- point invisible dans le monde pour accrocher des particules
local function pointMonde(pos, duree)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	Debris:AddItem(a, duree or 3)
	return a
end

local function son(id, parent, volume, hauteur)
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = (hauteur or 1) * (0.94 + math.random() * 0.12)
	s.RollOffMaxDistance = 80
	local groupe = game:GetService("SoundService"):FindFirstChild("Effets")   -- curseur « Effets sonores » des Paramètres
	if groupe and groupe:IsA("SoundGroup") then s.SoundGroup = groupe end
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 4)
	return s
end

local function sonA(id, pos, volume, hauteur)
	son(id, pointMonde(pos, 4), volume, hauteur)
end

-- émetteur générique
local function emetteur(parent, opts)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[opts.tex or "etincelles"]
	e.Color = opts.couleur2 and CS(opts.couleur, opts.couleur2) or CS(opts.couleur or Color3.new(1, 1, 1))
	e.LightEmission = opts.lumiere or 0.8
	e.Size = opts.taille or NS(0.4, 0)
	e.Transparency = opts.transparence or NS(0, 1)
	e.Lifetime = opts.vie or NR(0.4, 0.8)
	e.Speed = opts.vitesse or NR(6, 14)
	e.SpreadAngle = opts.ecart or Vector2.new(180, 180)
	e.Acceleration = opts.acceleration or Vector3.zero
	e.Drag = opts.frein or 3
	e.Rotation = NR(0, 360)
	e.RotSpeed = opts.rotation or NR(-180, 180)
	e.Rate = opts.debit or 0
	e.ZOffset = opts.zoffset or 0.5
	e.LockedToPart = opts.colle or false
	e.Enabled = (opts.debit or 0) > 0
	e.Parent = parent
	return e
end

local function rafale(pos, opts, n)
	local a = pointMonde(pos, 3)
	local e = emetteur(a, opts)
	n = n or 20
	e:Emit(performance() and math.max(1, math.floor(n * 0.35)) or n)
	return e
end

-- anneau néon qui grandit (onde de choc)
local function onde(pos, couleur, taille, duree)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = couleur
	p.Transparency = 0.15
	p.Size = Vector3.new(0.15, 1, 1)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	tween(p, duree or 0.35, { Size = Vector3.new(0.05, taille or 9, taille or 9), Transparency = 1 })
	Debris:AddItem(p, (duree or 0.35) + 0.1)
end

-- éclair en zigzag (néon)
local function eclair(depart, arrivee, couleur)
	local segments, pts = 5, { depart }
	for i = 1, segments - 1 do
		local p = depart:Lerp(arrivee, i / segments)
		pts[#pts + 1] = p + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6
	end
	pts[#pts + 1] = arrivee
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = couleur
		p.Size = Vector3.new(0.14, 0.14, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = workspace
		tween(p, 0.22, { Transparency = 1, Size = Vector3.new(0.02, 0.02, p.Size.Z) })
		Debris:AddItem(p, 0.3)
	end
end

-- éclats (origami) : petits triangles qui volent
local function eclats(pos, couleurs, n)
	if performance() then n = math.max(1, math.floor(n * 0.3)) end
	for i = 1, n do
		local w = Instance.new("WedgePart")
		w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
		w.Material = Enum.Material.Neon
		w.Color = couleurs[(i % #couleurs) + 1]
		w.Size = Vector3.new(0.05, 0.45, 0.45)
		w.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		w.Parent = workspace
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		tween(w, 0.55, {
			CFrame = CFrame.new(pos + dir * (4 + math.random() * 3)) * CFrame.Angles(math.random() * 9, math.random() * 9, 0),
			Transparency = 1,
		}, Enum.EasingStyle.Quart)
		Debris:AddItem(w, 0.6)
	end
end

------------------------------------------------------------------ CAMÉRA
local secousseForce, secousseFin = 0, 0
RunService:BindToRenderStep("CouteauxSecousse", Enum.RenderPriority.Camera.Value + 1, function()
	local reste = secousseFin - os.clock()
	if reste <= 0 then return end
	local f = secousseForce * math.clamp(reste * 4, 0, 1)
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * CFrame.Angles(
		math.rad((math.random() - 0.5) * f * 2), math.rad((math.random() - 0.5) * f * 2), 0)
end)

function FX.Secousse(force, duree)
	if joueurLocal and joueurLocal:GetAttribute("Param_Secousses") == false then return end
	secousseForce = math.max(force or 0.4, secousseForce * 0.5)
	secousseFin = os.clock() + (duree or 0.25)
end

------------------------------------------------------------------ OUTILS
local function infos(tool)
	local id = tool:GetAttribute("CouteauId")
	return id, id and Config.Couteaux[id]
end

local function plusGrandeLame(tool)
	if tool:FindFirstChild("ZoneLame") then return tool.ZoneLame end
	local best, vol = nil, 0
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and string.find(p.Name, "_Blade_") then
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > vol then best, vol = p, v end
		end
	end
	return best or tool:FindFirstChild("Handle")
end

------------------------------------------------------------------ ÉQUIPER
function FX.Equiper(tool)
	local id, def = infos(tool)
	local handle = tool:FindFirstChild("Handle")
	if not def or not handle or tool:FindFirstChild("FX_Pret") then return end
	local dossier = Instance.new("Folder")
	dossier.Name = "FX_Pret"
	dossier.Parent = tool

	-- traînée
	local a0, a1 = handle:FindFirstChild("LameBase"), handle:FindFirstChild("LamePointe")
	if a0 and a1 and def.Trainee then
		local tr = Instance.new("Trail")
		tr.Name = "FX_Trainee"
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = CS(def.Trainee[1], def.Trainee[2])
		tr.Transparency = NS(0.05, 1)
		tr.Lifetime = 0.2
		tr.LightEmission = 0.7
		tr.WidthScale = NS(def.Trainee[3] or 1, 0.2)
		tr.MinLength = 0.05
		tr.Enabled = false
		tr.Parent = handle
	end

	-- aura permanente
	local lame = plusGrandeLame(tool)
	local aura = def.Aura
	if aura and lame then
		local t = aura.Type
		local opts = { couleur = aura.Couleur, debit = aura.Debit or 6, colle = true, lumiere = 0.9 }
		if t == "etincelles" then
			opts.taille = NS(0.22, 0); opts.vie = NR(0.25, 0.5); opts.vitesse = NR(1, 3)
		elseif t == "feu" then
			opts.tex = "feu"; opts.taille = NS(0.45, 0.05); opts.vie = NR(0.3, 0.6); opts.vitesse = NR(1, 2)
			opts.acceleration = Vector3.new(0, 6, 0); opts.colle = false
		elseif t == "fumee" then
			opts.tex = "fumee"; opts.lumiere = 0; opts.taille = NS(0.3, 0.9); opts.transparence = NS(0.55, 1)
			opts.vie = NR(0.6, 1.1); opts.vitesse = NR(0.3, 1); opts.colle = false
		elseif t == "plumes" then
			opts.lumiere = 0.3; opts.taille = NS(0.25, 0.2); opts.vie = NR(1, 1.6); opts.vitesse = NR(0.5, 1.5)
			opts.acceleration = Vector3.new(0, -2, 0); opts.rotation = NR(-90, 90); opts.colle = false
		elseif t == "bulles" then
			opts.taille = NS(0.18, 0.05); opts.vie = NR(0.6, 1); opts.vitesse = NR(0.5, 1.2)
			opts.acceleration = Vector3.new(0, 4, 0); opts.colle = false
		elseif t == "gouttes" then
			opts.taille = NS(0.16, 0.06); opts.vie = NR(0.5, 0.8); opts.vitesse = NR(0, 0.3)
			opts.acceleration = Vector3.new(0, -14, 0); opts.colle = false
		end
		local e = emetteur(lame, opts)
		e.Name = "FX_Aura"
	end

	-- lueur
	if def.Lumiere then
		local l = Instance.new("PointLight")
		l.Name = "FX_Lueur"
		l.Color = def.Lumiere
		l.Range = 7
		l.Brightness = 1.4
		l.Shadows = false
		l.Parent = lame or handle
		if def.Clignote then
			task.spawn(function()
				while l.Parent and tool.Parent do
					l.Brightness = 0.6 + math.random() * 2
					task.wait(0.05 + math.random() * 0.1)
				end
			end)
		end
	end

	-- sons
	for nom, idSon in pairs({ Coup = Config.Sons.Coup, Estoc = Config.Sons.Estoc }) do
		local s = Instance.new("Sound")
		s.Name = "FX_" .. nom
		s.SoundId = idSon
		s.Volume = 0.55
		s.RollOffMaxDistance = 70
		s.Parent = handle
	end
end

-- appelé à chaque fois que le couteau est sorti (éclat + son)
function FX.Degainer(tool)
	FX.Equiper(tool)
	local id, def = infos(tool)
	local handle = tool:FindFirstChild("Handle")
	if not def or not handle then return end
	son(Config.Sons.Degainer, handle, 0.5, def.Hauteur)
	local equipe = Config.Equipes[def.Equipe]
	local e = emetteur(handle, { couleur = def.Trainee and def.Trainee[1] or Color3.new(1, 1, 1),
		couleur2 = equipe and equipe.Couleur, taille = NS(0.3, 0), vie = NR(0.25, 0.45), vitesse = NR(4, 9) })
	e:Emit(14)
	Debris:AddItem(e, 1)
end

------------------------------------------------------------------ COUP
function FX.Coup(tool, combo)
	local id, def = infos(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	if not def or not handle then return end
	FX.Equiper(tool)
	local tr = handle:FindFirstChild("FX_Trainee")
	if tr then
		tr.Enabled = true
		task.delay(combo == 3 and 0.32 or 0.24, function() if tr.Parent then tr.Enabled = false end end)
	end
	local s = handle:FindFirstChild(combo == 3 and "FX_Estoc" or "FX_Coup")
	if s then
		s.PlaybackSpeed = (def.Hauteur or 1) * (combo == 2 and 1.12 or 1) * (0.95 + math.random() * 0.1)
		s:Play()
	end
	if def.Impact == "eclair" then
		local p = handle:FindFirstChild("LamePointe")
		if p then rafale(p.WorldPosition, { couleur = Color3.fromRGB(255, 230, 60), taille = NS(0.25, 0), vie = NR(0.15, 0.3) }, 8) end
	end
end

------------------------------------------------------------------ IMPACT
local IMPACTS = {}

IMPACTS.plumes = function(pos)
	rafale(pos, { couleur = Color3.new(1, 1, 1), lumiere = 0.2, taille = NS(0.35, 0.25), vie = NR(0.8, 1.3),
		vitesse = NR(8, 14), acceleration = Vector3.new(0, -6, 0), frein = 4 }, 14)
	rafale(pos, { couleur = Color3.fromRGB(214, 40, 40), lumiere = 0.2, taille = NS(0.3, 0.2), vie = NR(0.8, 1.2),
		vitesse = NR(6, 12), acceleration = Vector3.new(0, -6, 0), frein = 4 }, 8)
end
IMPACTS.etoiles = function(pos)
	rafale(pos, { couleur = Color3.fromRGB(255, 220, 80), taille = NS(0.6, 0), vie = NR(0.4, 0.7), vitesse = NR(10, 18) }, 24)
	onde(pos, Color3.fromRGB(255, 215, 70), 8)
end
IMPACTS.eclair = function(pos)
	local jaune = Color3.fromRGB(255, 230, 60)
	for _ = 1, 4 do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
		eclair(pos, pos + dir * (4 + math.random() * 3), jaune)
	end
	rafale(pos, { couleur = jaune, couleur2 = Color3.new(1, 1, 1), taille = NS(0.35, 0), vie = NR(0.2, 0.4), vitesse = NR(14, 24) }, 26)
	onde(pos, jaune, 7, 0.25)
	sonA(Config.Sons.Electrique, pos, 0.7, 0.8)
end
IMPACTS.onde = function(pos)
	onde(pos, Color3.fromRGB(255, 255, 255), 14, 0.45)
	onde(pos, Color3.fromRGB(214, 40, 40), 10, 0.35)
	rafale(pos - Vector3.new(0, 2, 0), { tex = "fumee", couleur = Color3.fromRGB(220, 210, 190), lumiere = 0,
		taille = NS(1.2, 2.5), transparence = NS(0.3, 1), vie = NR(0.6, 0.9), vitesse = NR(10, 16), ecart = Vector2.new(5, 180) }, 16)
end
IMPACTS.eclat = function(pos)
	rafale(pos, { couleur = Color3.fromRGB(255, 150, 40), couleur2 = Color3.fromRGB(255, 60, 0), taille = NS(0.45, 0),
		vie = NR(0.3, 0.5), vitesse = NR(12, 20) }, 22)
	onde(pos, Color3.fromRGB(255, 106, 0), 7)
end
IMPACTS.fumee = function(pos)
	rafale(pos, { tex = "fumee", couleur = Color3.fromRGB(30, 26, 24), lumiere = 0, taille = NS(1, 2.2),
		transparence = NS(0.2, 1), vie = NR(0.6, 1), vitesse = NR(4, 9) }, 14)
	rafale(pos, { couleur = Color3.fromRGB(255, 106, 0), taille = NS(0.3, 0), vie = NR(0.3, 0.5), vitesse = NR(10, 16) }, 12)
end
IMPACTS.spectre = function(pos)
	rafale(pos, { tex = "feu", couleur = Color3.fromRGB(255, 140, 40), couleur2 = Color3.fromRGB(255, 50, 0), taille = NS(1.2, 0),
		vie = NR(0.4, 0.7), vitesse = NR(4, 10), acceleration = Vector3.new(0, 12, 0) }, 20)
	onde(pos, Color3.fromRGB(255, 120, 30), 9, 0.4)
end
IMPACTS.flammes = function(pos)
	rafale(pos, { tex = "feu", couleur = Color3.fromRGB(255, 210, 60), couleur2 = Color3.fromRGB(255, 60, 0), taille = NS(1.5, 0.2),
		vie = NR(0.4, 0.8), vitesse = NR(8, 16), acceleration = Vector3.new(0, 10, 0) }, 30)
	rafale(pos, { couleur = Color3.fromRGB(255, 200, 80), taille = NS(0.25, 0), vie = NR(0.6, 1), vitesse = NR(14, 22),
		acceleration = Vector3.new(0, -10, 0), frein = 1 }, 16)
	onde(pos, Color3.fromRGB(255, 110, 20), 10)
end
IMPACTS.origami = function(pos)
	eclats(pos, { Color3.fromRGB(255, 106, 0), Color3.fromRGB(25, 25, 25), Color3.fromRGB(255, 170, 60) }, 14)
	onde(pos, Color3.fromRGB(255, 106, 0), 8, 0.3)
end
IMPACTS.poison = function(pos, def)
	local c = def and def.Trainee and def.Trainee[1] or Color3.fromRGB(124, 255, 46)
	rafale(pos, { tex = "fumee", couleur = c, lumiere = 0.4, taille = NS(0.8, 2), transparence = NS(0.3, 1),
		vie = NR(0.6, 1), vitesse = NR(3, 7) }, 14)
	rafale(pos, { couleur = c, taille = NS(0.3, 0.1), vie = NR(0.5, 0.9), vitesse = NR(8, 14),
		acceleration = Vector3.new(0, -25, 0), frein = 1 }, 16)
	onde(pos, c, 7)
end
IMPACTS.couronne = function(pos)
	local v = Color3.fromRGB(124, 255, 46)
	rafale(pos, { couleur = v, couleur2 = Color3.fromRGB(255, 215, 70), taille = NS(0.7, 0), vie = NR(0.4, 0.8), vitesse = NR(12, 22) }, 30)
	onde(pos, v, 12, 0.4)
	onde(pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 215, 70), 8, 0.3)
end

function FX.Impact(pos, id, victime)
	local def = Config.Couteaux[id]
	if not def then return end
	local f = IMPACTS[def.Impact] or IMPACTS.eclat
	f(pos, def)
	sonA(Config.Sons.Impact, pos, 0.8, (def.Hauteur or 1) * 0.8)
	-- flash blanc sur la victime
	if victime and victime.Parent then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.new(1, 1, 1)
		h.FillTransparency = 0.2
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = victime
		tween(h, 0.25, { FillTransparency = 1 })
		Debris:AddItem(h, 0.3)
	end
end

------------------------------------------------------------------ ESQUIVE
-- images fantômes (copies néon du personnage qui s'effacent)
local function fantomes(character, couleur, n, intervalle, base)
	task.spawn(function()
		for i = 1, n do
			if not character.Parent then return end
			for _, p in ipairs(character:GetChildren()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
					local g = p:Clone()
					g:ClearAllChildren()
					g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
					g.Material = Enum.Material.Neon
					g.Color = couleur
					g.Transparency = (base or 0.45) + i * (0.32 / n)
					if g:IsA("MeshPart") then g.TextureID = "" end
					g.Parent = workspace
					tween(g, 0.3 + n * 0.02, { Transparency = 1 })
					Debris:AddItem(g, 0.35 + n * 0.02)
				end
			end
			task.wait(intervalle or 0.045)
		end
	end)
end

function FX.Esquive(character, equipe)
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local couleur = (Config.Equipes[equipe or ""] or {}).Couleur or Color3.new(1, 1, 1)
	sonA(Config.Sons.Esquive, root.Position, 0.5, 1.45)
	rafale(root.Position - Vector3.new(0, 2.6, 0), { tex = "fumee", couleur = Color3.fromRGB(230, 225, 215), lumiere = 0,
		taille = NS(0.8, 1.6), transparence = NS(0.4, 1), vie = NR(0.4, 0.6), vitesse = NR(4, 8), ecart = Vector2.new(5, 180) }, 10)
	fantomes(character, couleur, 4, 0.045)
end

------------------------------------------------------------------ ESQUIVE PARFAITE
local OR = Color3.fromRGB(255, 214, 90)
function FX.EsquiveParfaite(vChar, aChar, equipe)
	local vRoot = vChar and vChar:FindFirstChild("HumanoidRootPart")
	if not vRoot then return end
	local couleur = (Config.Equipes[equipe or ""] or {}).Couleur or OR
	local pos = vRoot.Position
	-- son : « ding » cristallin + souffle grave
	sonA(Config.Sons.Parfaite, pos, 0.9, 1.25)
	task.delay(0.06, function() sonA(Config.Sons.Parfaite, pos, 0.6, 1.9) end)
	sonA(Config.Sons.Esquive, pos, 0.7, 0.8)
	-- flash de lumière dorée
	local a = pointMonde(pos, 1)
	local lum = Instance.new("PointLight")
	lum.Color, lum.Range, lum.Brightness = OR, 18, 6
	lum.Parent = a
	tween(lum, 0.6, { Brightness = 0 })
	-- ondes au sol + anneau vertical
	local sol = pos - Vector3.new(0, 2.8, 0)
	onde(sol, OR, 16, 0.45)
	task.delay(0.08, function() onde(sol, couleur, 11, 0.4) end)
	task.delay(0.16, function() onde(sol, Color3.new(1, 1, 1), 7, 0.3) end)
	local anneau = Instance.new("Part")
	anneau.Shape = Enum.PartType.Cylinder
	anneau.Anchored, anneau.CanCollide, anneau.CanQuery, anneau.CanTouch, anneau.CastShadow = true, false, false, false, false
	anneau.Material, anneau.Color, anneau.Transparency = Enum.Material.Neon, OR, 0.1
	anneau.Size = Vector3.new(0.1, 2, 2)
	anneau.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
	if aChar and aChar:FindFirstChild("HumanoidRootPart") then
		anneau.CFrame = CFrame.lookAt(pos, aChar.HumanoidRootPart.Position) * CFrame.Angles(0, math.rad(90), 0)
	end
	anneau.Parent = workspace
	tween(anneau, 0.4, { Size = Vector3.new(0.02, 12, 12), Transparency = 1 })
	Debris:AddItem(anneau, 0.45)
	-- étincelles dorées + poussière
	rafale(pos, { couleur = OR, couleur2 = Color3.new(1, 1, 1), taille = NS(0.35, 0), vie = NR(0.4, 0.9), vitesse = NR(14, 28),
		frein = 4, lumiere = 1 }, 34)
	rafale(sol, { tex = "fumee", couleur = Color3.fromRGB(240, 230, 210), lumiere = 0, taille = NS(1, 2.4), transparence = NS(0.35, 1),
		vie = NR(0.5, 0.8), vitesse = NR(8, 14), ecart = Vector2.new(5, 180) }, 16)
	-- longue traînée de fantômes dorés pendant la vrille
	fantomes(vChar, OR, 9, 0.05, 0.35)

	-- l'attaquant : la lame frappe le vide et ricoche
	local aRoot = aChar and aChar:FindFirstChild("HumanoidRootPart")
	if aRoot then
		local tool = aChar:FindFirstChildWhichIsA("Tool")
		local lame = tool and plusGrandeLame(tool)
		local pl = lame and lame.Position or (aRoot.Position + aRoot.CFrame.LookVector * 2)
		sonA(Config.Sons.Parade, pl, 0.8, 0.55)
		rafale(pl, { couleur = Color3.new(1, 1, 1), couleur2 = OR, taille = NS(0.25, 0), vie = NR(0.2, 0.4), vitesse = NR(18, 30), frein = 6 }, 18)
		eclair(pl, pl + Vector3.new(math.random() - 0.5, -1, math.random() - 0.5) * 3, Color3.new(1, 1, 1))
		FX.Etourdi(aChar, (Config.Esquive.Parfaite or {}).Etourdi or 1.4)
	end
end

-- étoiles qui tournent au-dessus de la tête d'un personnage désarmé
function FX.Etourdi(character, duree)
	local tete = character:FindFirstChild("Head")
	if not tete then return end
	sonA(Config.Sons.Etourdi, tete.Position, 0.5, 0.7)
	local etoiles = {}
	for i = 1, 3 do
		local e = Instance.new("Part")
		e.Anchored, e.CanCollide, e.CanQuery, e.CanTouch, e.CastShadow = true, false, false, false, false
		e.Material, e.Color = Enum.Material.Neon, (i == 2) and Color3.new(1, 1, 1) or OR
		e.Size = Vector3.new(0.35, 0.35, 0.35)
		e.Parent = workspace
		local att = Instance.new("Attachment", e)
		if not performance() then
			emetteur(att, { couleur = OR, taille = NS(0.18, 0), vie = NR(0.2, 0.3), vitesse = NR(0, 0.5), debit = 18, lumiere = 1 })
		end
		etoiles[i] = e
	end
	local fin = os.clock() + duree
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t > fin or not tete.Parent then
			conn:Disconnect()
			for _, e in ipairs(etoiles) do
				tween(e, 0.2, { Size = Vector3.zero, Transparency = 1 })
				Debris:AddItem(e, 0.25)
			end
			return
		end
		for i, e in ipairs(etoiles) do
			local a = t * 6 + i * (math.pi * 2 / 3)
			e.CFrame = CFrame.new(tete.Position + Vector3.new(math.cos(a) * 1.3, 1.1 + math.sin(t * 8 + i) * 0.15, math.sin(a) * 1.3))
				* CFrame.Angles(t * 5, t * 3, math.rad(45))
		end
	end)
end

-- « ralenti » sur l'écran du joueur : couleurs qui se figent, flou léger, zoom
function FX.Ralenti(duree)
	duree = duree or 0.7
	local Lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "EsquiveParfaite"
	cc.Saturation, cc.Contrast, cc.Brightness, cc.TintColor = -0.55, 0.25, 0.05, Color3.fromRGB(255, 240, 205)
	cc.Parent = Lighting
	tween(cc, duree, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, Enum.EasingStyle.Quint)
	Debris:AddItem(cc, duree + 0.1)
	if not performance() then
		local flou = Instance.new("BlurEffect")
		flou.Size = 10
		flou.Parent = Lighting
		tween(flou, duree * 0.8, { Size = 0 }, Enum.EasingStyle.Quint)
		Debris:AddItem(flou, duree)
	end
	local cam = workspace.CurrentCamera
	local fov = cam.FieldOfView
	tween(cam, 0.08, { FieldOfView = fov - 8 })
	task.delay(0.1, function() tween(cam, duree, { FieldOfView = fov }, Enum.EasingStyle.Quint) end)
end

return FX
