--[[ LocalScript : StarterPlayer.StarterPlayerScripts.CouteauxClient
     - Clic / tap / R2 avec le couteau en main : combo 1-2-3 (animation + traînée + son).
     - Q / bouton B / bouton tactile : esquive (dash + invincibilité courte).
     - Affiche les effets de tous les joueurs (auras, coups, impacts, esquives).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Dossier = ReplicatedStorage:WaitForChild("Couteaux")
local Config = require(Dossier:WaitForChild("Config"))
local FX = require(Dossier:WaitForChild("FX"))
local Remotes = Dossier:WaitForChild("Remotes")
local RAttaque, REsquive, RFX = Remotes:WaitForChild("Attaque"), Remotes:WaitForChild("Esquive"), Remotes:WaitForChild("FX")

local joueur = Players.LocalPlayer

------------------------------------------------------------------ animations
-- ID publié (Config.Animations) ; sinon, dans Studio seulement, l'animation brute
-- de ReplicatedStorage.Couteaux.Animations (créée par InstallerAnimations.lua) : on peut tester en Play
-- avant même de publier.
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local idsTemp = {}
local function idAnimation(nom)
	local id = Config.Animations[nom]
	if id and id ~= "" then return id end
	if not RunService:IsStudio() then return nil end
	if idsTemp[nom] == nil then
		local brutes = Dossier:FindFirstChild("Animations")
		local kfs = brutes and brutes:FindFirstChild(nom)
		local ok, temp = false, nil
		if kfs then ok, temp = pcall(function() return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs) end) end
		idsTemp[nom] = ok and temp or false
	end
	return idsTemp[nom] or nil
end

local pistes = {}
local function piste(humanoid, nom)
	local id = idAnimation(nom)
	if not id then return nil end
	pistes[humanoid] = pistes[humanoid] or {}
	if not pistes[humanoid][nom] then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		pistes[humanoid][nom] = animator:LoadAnimation(anim) -- la priorité vient de l'animation
	end
	return pistes[humanoid][nom]
end

-- course : remplace l'animation « run » du script Animate de Roblox
local function brancherCourse(char)
	local id = idAnimation("Course")
	if not id then return end
	local animate = char:WaitForChild("Animate", 10)
	local run = animate and animate:FindFirstChild("run")
	local anim = run and run:FindFirstChildOfClass("Animation")
	if anim then anim.AnimationId = id end
end

-- animation classique de Roblox (tant que les animations perso ne sont pas publiées)
local function animClassique(tool, combo)
	local v = Instance.new("StringValue")
	v.Name = "toolanim"
	v.Value = combo == 3 and "Lunge" or "Slash"
	v.Parent = tool
	task.delay(0.3, function() v:Destroy() end)
end

------------------------------------------------------------------ attaque
local combo, dernier = 0, 0

local function attaquer(tool)
	local now = os.clock()
	if now - dernier < Config.Combat.Recharge then return end
	if joueur:GetAttribute("EnPrison") then return end
	if joueur.Character and joueur.Character:GetAttribute("Etourdi") then return end   -- désarmé par une esquive parfaite
	combo = (now - dernier < Config.Combat.FenetreCombo) and (combo % 3 + 1) or 1
	dernier = now
	joueur:SetAttribute("CouteauxCombo", combo)          -- lu par l'interface (« COMBO x2 »)
	local hum = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local t = hum and piste(hum, "Coup" .. combo)
	if t then t:Play(0.05) else animClassique(tool, combo) end
	FX.Coup(tool, combo)
	RAttaque:FireServer(combo)
end

local function garde(actif)
	local hum = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local t = hum and piste(hum, "Garde")
	if not t then return end
	if actif and not t.IsPlaying then t:Play(0.2) elseif not actif then t:Stop(0.2) end
end

local function brancherOutil(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("CouteauId") then return end
	garde(true)
	if tool:GetAttribute("_Branche") then return end
	tool:SetAttribute("_Branche", true)
	tool.Activated:Connect(function() attaquer(tool) end)
	tool.Unequipped:Connect(function() garde(false) end)
end

------------------------------------------------------------------ esquive
local derniereEsquive = 0
local rechargeEsquive = Config.Esquive.Recharge
local function esquiver(_, etat)
	if etat ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if not Config.Esquive.Active or joueur:GetAttribute("EnPrison") then return Enum.ContextActionResult.Pass end
	local char = joueur.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return Enum.ContextActionResult.Pass end
	local now = os.clock()
	if now - derniereEsquive < rechargeEsquive then return Enum.ContextActionResult.Sink end
	derniereEsquive = now
	rechargeEsquive = Config.Esquive.Recharge
	joueur:SetAttribute("EsquiveDebut", now)             -- lu par l'interface (recharge sur le bouton ESQUIVE)
	joueur:SetAttribute("EsquiveRecharge", Config.Esquive.Recharge)

	-- direction choisie par rapport à la CAMÉRA : gauche / droite = saut de côté,
	-- arrière ou aucune touche = saut en arrière, avant = saut de côté (on n'esquive pas vers l'avant).
	-- Le perso se tourne face à la caméra pendant l'esquive pour que le saut parte bien sur le côté.
	local cam = workspace.CurrentCamera
	local avant = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	avant = avant.Magnitude > 0.01 and avant.Unit or root.CFrame.LookVector
	local droite = avant:Cross(Vector3.yAxis)
	local md = hum.MoveDirection
	local x, z = md:Dot(droite), md:Dot(avant)
	local nom, dir
	if md.Magnitude < 0.1 or (z < -0.5 and math.abs(x) < 0.7) then
		nom, dir = "EsquiveArriere", -avant
	elseif x >= 0 then
		nom, dir = "EsquiveDroite", droite
	else
		nom, dir = "EsquiveGauche", -droite
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + avant)
	hum.AutoRotate = false
	task.delay(Config.Esquive.Duree + 0.25, function() if hum.Parent then hum.AutoRotate = true end end)
	local t = piste(hum, nom)
	if t then t:Play(0.05) end
	REsquive:FireServer()
	FX.Esquive(char, Config.EquipeDe(joueur))
	local fin = os.clock() + Config.Esquive.Duree
	task.spawn(function()
		while os.clock() < fin and root.Parent do
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * Config.Esquive.Vitesse, math.min(v.Y, 8), dir.Z * Config.Esquive.Vitesse)
			task.wait()
		end
	end)
	return Enum.ContextActionResult.Sink
end

-- touche choisie dans les Paramètres de l'interface (attribut « Param_ToucheEsquive » = nom du KeyCode)
-- quand l'interface de jeu est là (attribut « InterfaceActive »), c'est elle qui affiche le bouton tactile
local function lierEsquive()
	if not Config.Esquive.Active then return end
	local nom = joueur:GetAttribute("Param_ToucheEsquive")
	local ok, touche = pcall(function() return nom and Enum.KeyCode[nom] end)
	touche = (ok and touche) or Config.Esquive.Touche
	ContextActionService:UnbindAction("CouteauxEsquive")
	local boutonTactile = not joueur:GetAttribute("InterfaceActive")
	ContextActionService:BindAction("CouteauxEsquive", esquiver, boutonTactile, touche, Config.Esquive.Manette)
	if boutonTactile then
		ContextActionService:SetTitle("CouteauxEsquive", "ESQUIVE")
		ContextActionService:SetPosition("CouteauxEsquive", UDim2.new(1, -170, 1, -150))
	end
end
lierEsquive()
joueur:GetAttributeChangedSignal("Param_ToucheEsquive"):Connect(lierEsquive)
joueur:GetAttributeChangedSignal("InterfaceActive"):Connect(lierEsquive)

-- l'interface (bouton ESQUIVE tactile) demande une esquive
local demande = Dossier:FindFirstChild("EsquiveDemande")
if not demande then
	demande = Instance.new("BindableEvent")
	demande.Name = "EsquiveDemande"
	demande.Parent = Dossier
end
demande.Event:Connect(function() esquiver(nil, Enum.UserInputState.Begin) end)

------------------------------------------------------------------ effets de TOUS les joueurs
local function surveillerPerso(char, estMoi)
	local function ajout(obj)
		if obj:IsA("Tool") and obj:GetAttribute("CouteauId") then
			FX.Degainer(obj)
			if estMoi then brancherOutil(obj) end
		end
	end
	for _, c in ipairs(char:GetChildren()) do ajout(c) end
	char.ChildAdded:Connect(ajout)
end

local function surveillerJoueur(p)
	if p.Character then surveillerPerso(p.Character, p == joueur) end
	p.CharacterAdded:Connect(function(c) surveillerPerso(c, p == joueur) end)
end
if joueur.Character then task.spawn(brancherCourse, joueur.Character) end
joueur.CharacterAdded:Connect(brancherCourse)
for _, p in ipairs(Players:GetPlayers()) do surveillerJoueur(p) end
Players.PlayerAdded:Connect(surveillerJoueur)

------------------------------------------------------------------ messages du serveur
RFX.OnClientEvent:Connect(function(type_, ...)
	if type_ == "Coup" then
		local tool, c = ...
		if tool and tool.Parent then FX.Coup(tool, c) end
	elseif type_ == "Impact" then
		local pos, id, vChar, attaquant, victime, dir, c = ...
		FX.Impact(pos, id, vChar)
		local def = Config.Couteaux[id] or {}
		if attaquant == joueur then
			FX.Secousse((def.Secousse or 0.3) * (c == 3 and 1.4 or 1), 0.18)
		elseif victime == joueur then
			FX.Secousse((def.Secousse or 0.3) * 1.6, 0.3)
			local root = vChar and vChar:FindFirstChild("HumanoidRootPart")
			if root and dir then
				root.AssemblyLinearVelocity = Vector3.new(dir.X, 0, dir.Z) * Config.Combat.Recul + Vector3.new(0, 16, 0)
			end
		end
	elseif type_ == "Esquive" then
		local char, equipe = ...
		FX.Esquive(char, equipe)
	elseif type_ == "EsquiveParfaite" then
		local vChar, aChar, equipe, victime, attaquant = ...
		FX.EsquiveParfaite(vChar, aChar, equipe)
		if victime == joueur then
			-- la vrille remplace le saut d'esquive en cours
			local hum = vChar and vChar:FindFirstChildOfClass("Humanoid")
			if hum then
				for _, nom in ipairs({ "EsquiveDroite", "EsquiveGauche", "EsquiveArriere" }) do
					local t = pistes[hum] and pistes[hum][nom]
					if t and t.IsPlaying then t:Stop(0.08) end
				end
				local t = piste(hum, "EsquiveParfaite")
				if t then t:Play(0.06) end
				hum.AutoRotate = false
				task.delay(0.6, function() if hum.Parent then hum.AutoRotate = true end end)
			end
			FX.Ralenti(0.7)
			FX.Secousse(0.25, 0.15)
			-- esquive rechargée (presque) tout de suite
			rechargeEsquive = Config.Esquive.Parfaite.Recharge or 0.3
			derniereEsquive = os.clock()
			joueur:SetAttribute("EsquiveDebut", derniereEsquive)
			joueur:SetAttribute("EsquiveRecharge", rechargeEsquive)
			joueur:SetAttribute("EsquiveParfaite", os.clock())     -- l'interface affiche « ESQUIVE PARFAITE ! »
		elseif attaquant == joueur then
			FX.Secousse(0.5, 0.25)
			joueur:SetAttribute("Desarme", os.clock())             -- l'interface affiche « DÉSARMÉ ! »
		end
	end
end)
