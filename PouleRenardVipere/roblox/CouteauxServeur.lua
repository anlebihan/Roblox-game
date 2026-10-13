--[[ Script : ServerScriptService.CouteauxServeur
     - Donne le couteau de l'équipe à l'apparition (si Config.Combat.DonnerCouteau = true).
       Pour choisir un autre couteau : player:SetAttribute("Couteau", "PouleRoyal") puis respawn.
     - Vérifie chaque coup côté serveur (distance, angle, recharge, bonne équipe, invincibilité).
     - Esquive : rend le joueur invincible quelques instants.
     - Prévient le reste du jeu quand quelqu'un est touché :
         ServerStorage.CouteauxEvents.Touche:Fire(attaquant, victime, idCouteau)
       -> brancher ici la mise en PRISON du jeu (voir LISEZMOI).
     Attributs respectés : Character "Invincible" (true = intouchable),
                           Player "EnPrison" (true = ne peut ni attaquer ni être touché).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Dossier = ReplicatedStorage:WaitForChild("Couteaux")
local Config = require(Dossier:WaitForChild("Config"))
local Outils = Dossier:WaitForChild("Outils")

-- Remotes
local Remotes = Dossier:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = Dossier
local function remote(nom)
	local r = Remotes:FindFirstChild(nom) or Instance.new("RemoteEvent")
	r.Name = nom
	r.Parent = Remotes
	return r
end
local RAttaque, REsquive, RFX = remote("Attaque"), remote("Esquive"), remote("FX")

-- Événement pour le reste du jeu
local Events = ServerStorage:FindFirstChild("CouteauxEvents") or Instance.new("Folder")
Events.Name = "CouteauxEvents"
Events.Parent = ServerStorage
local Touche = Events:FindFirstChild("Touche") or Instance.new("BindableEvent")
Touche.Name = "Touche"
Touche.Parent = Events

------------------------------------------------------------------ couteau en main
local function couteauEnMain(player)
	local char = player.Character
	if not char then return end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("CouteauId") then return t, t:GetAttribute("CouteauId") end
	end
end

local function vivant(char)
	local h = char and char:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

------------------------------------------------------------------ donner le couteau
local function donnerCouteau(player)
	if not Config.Combat.DonnerCouteau then return end
	local equipe = Config.EquipeDe(player)
	if not equipe then return end
	local voulu = player:GetAttribute("Couteau")
	local def = voulu and Config.Couteaux[voulu]
	local id = (def and def.Equipe == equipe) and voulu or Config.Equipes[equipe].Base
	local modele = Outils:FindFirstChild(id)
	if not modele then
		warn("[Couteaux] Outil introuvable : ReplicatedStorage.Couteaux.Outils." .. id)
		return
	end
	local sac = player:WaitForChild("Backpack")
	for _, t in ipairs(sac:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("CouteauId") then t:Destroy() end -- ancien couteau donné par ce script
	end
	modele:Clone().Parent = sac
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		donnerCouteau(player)
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then task.spawn(donnerCouteau, p) end
	p.CharacterAdded:Connect(function() task.wait(0.2) donnerCouteau(p) end)
end

------------------------------------------------------------------ attaque
local dernierCoup = {}

RAttaque.OnServerEvent:Connect(function(player, combo)
	combo = (typeof(combo) == "number" and combo >= 1 and combo <= 3) and math.floor(combo) or 1
	local now = os.clock()
	if dernierCoup[player] and now - dernierCoup[player] < Config.Combat.Recharge * 0.8 then return end
	dernierCoup[player] = now

	local tool, id = couteauEnMain(player)
	local char = player.Character
	if not tool or not vivant(char) or player:GetAttribute("EnPrison") then return end
	local equipe = Config.EquipeDe(player)
	local root = char.HumanoidRootPart

	-- les autres joueurs voient le coup (traînée + son)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then RFX:FireClient(p, "Coup", tool, combo) end
	end

	-- cherche la meilleure cible devant
	local portee = Config.Combat.Portee * (combo == 3 and 1.15 or 1)
	local cosMax = math.cos(math.rad(Config.Combat.AngleMax))
	local cible, distMin = nil, math.huge
	for _, autre in ipairs(Players:GetPlayers()) do
		local c = autre.Character
		if autre ~= player and vivant(c) and not autre:GetAttribute("EnPrison") and not c:GetAttribute("Invincible")
			and Config.PeutAttaquer(equipe, Config.EquipeDe(autre)) then
			local delta = c.HumanoidRootPart.Position - root.Position
			local d = delta.Magnitude
			local plat = Vector3.new(delta.X, 0, delta.Z)
			local devant = plat.Magnitude < 1 or root.CFrame.LookVector:Dot(plat.Unit) >= cosMax
			if d <= portee and devant and d < distMin then cible, distMin = autre, d end
		end
	end
	if not cible then return end

	local vChar = cible.Character
	local vRoot = vChar.HumanoidRootPart
	local pos = vRoot.Position:Lerp(root.Position, 0.35) + Vector3.new(0, 0.8, 0)
	RFX:FireAllClients("Impact", pos, id, vChar, player, cible, (vRoot.Position - root.Position).Unit, combo)
	if Config.Combat.Degats > 0 then vChar.Humanoid:TakeDamage(Config.Combat.Degats) end
	Touche:Fire(player, cible, id)
end)

------------------------------------------------------------------ esquive
local derniereEsquive = {}
REsquive.OnServerEvent:Connect(function(player)
	if not Config.Esquive.Active then return end
	local now = os.clock()
	if derniereEsquive[player] and now - derniereEsquive[player] < Config.Esquive.Recharge * 0.85 then return end
	derniereEsquive[player] = now
	local char = player.Character
	if not vivant(char) or player:GetAttribute("EnPrison") then return end
	char:SetAttribute("Invincible", true)
	task.delay(Config.Esquive.Invincible, function()
		if char.Parent then char:SetAttribute("Invincible", nil) end
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then RFX:FireClient(p, "Esquive", char, Config.EquipeDe(player)) end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	dernierCoup[p], derniereEsquive[p] = nil, nil
end)
