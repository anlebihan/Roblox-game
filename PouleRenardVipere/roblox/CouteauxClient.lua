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
local pistes = {}
local function piste(humanoid, nom)
	local id = Config.Animations[nom]
	if not id or id == "" then return nil end
	pistes[humanoid] = pistes[humanoid] or {}
	if not pistes[humanoid][nom] then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local t = animator:LoadAnimation(anim)
		t.Priority = Enum.AnimationPriority.Action
		pistes[humanoid][nom] = t
	end
	return pistes[humanoid][nom]
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
	combo = (now - dernier < Config.Combat.FenetreCombo) and (combo % 3 + 1) or 1
	dernier = now
	local hum = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local t = hum and piste(hum, "Coup" .. combo)
	if t then t:Play(0.05) else animClassique(tool, combo) end
	FX.Coup(tool, combo)
	RAttaque:FireServer(combo)
end

local function brancherOutil(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("CouteauId") or tool:GetAttribute("_Branche") then return end
	tool:SetAttribute("_Branche", true)
	tool.Activated:Connect(function() attaquer(tool) end)
end

------------------------------------------------------------------ esquive
local derniereEsquive = 0
local function esquiver(_, etat)
	if etat ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if not Config.Esquive.Active or joueur:GetAttribute("EnPrison") then return Enum.ContextActionResult.Pass end
	local char = joueur.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return Enum.ContextActionResult.Pass end
	local now = os.clock()
	if now - derniereEsquive < Config.Esquive.Recharge then return Enum.ContextActionResult.Sink end
	derniereEsquive = now

	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local t = piste(hum, "Esquive")
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

if Config.Esquive.Active then
	ContextActionService:BindAction("CouteauxEsquive", esquiver, true, Config.Esquive.Touche, Config.Esquive.Manette)
	ContextActionService:SetTitle("CouteauxEsquive", "ESQUIVE")
	ContextActionService:SetPosition("CouteauxEsquive", UDim2.new(1, -170, 1, -150))
end

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
	end
end)
