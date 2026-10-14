--[[ Script : ServerScriptService.CouteauxServeur
     - Donne le couteau de l'équipe à l'apparition (si Config.Combat.DonnerCouteau = true).
       Pour choisir un autre couteau : player:SetAttribute("Couteau", "PouleRoyal") puis respawn.
     - Vérifie chaque coup côté serveur (distance, angle, recharge, bonne équipe, invincibilité).
     - Esquive : rend le joueur invincible quelques instants.
     - ESQUIVE PARFAITE : si on esquive juste avant / pendant le coup d'un ennemi, on devient intouchable 1 s
       et l'attaquant est DÉSARMÉ (ne peut plus attaquer, ralenti) 1,4 s. Le reste du jeu est prévenu par
         ServerStorage.CouteauxEvents.EsquiveParfaite:Fire(joueurQuiEsquive, attaquant)   (attaquant = Player ou modèle de bot)
       Pour les BOTS : avant qu'un bot attrape un joueur, appeler
         ServerStorage.CouteauxEvents.TesterEsquive:Invoke(joueurVise, modeleDuBot)  -> true = coup esquivé, ne pas attraper
       et ne pas faire attaquer un bot qui a l'attribut « Etourdi ».
     - Prévient le reste du jeu quand quelqu'un est touché :
         ServerStorage.CouteauxEvents.Touche:Fire(attaquant, victime, idCouteau)
       -> brancher ici la mise en PRISON du jeu (voir LISEZMOI).
     Attributs respectés : Character "Invincible" (true = intouchable), Character "Etourdi" (true = ne peut pas attaquer),
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
local EvParfaite = Events:FindFirstChild("EsquiveParfaite") or Instance.new("BindableEvent")
EvParfaite.Name = "EsquiveParfaite"
EvParfaite.Parent = Events
local TesterEsquive = Events:FindFirstChild("TesterEsquive") or Instance.new("BindableFunction")
TesterEsquive.Name = "TesterEsquive"
TesterEsquive.Parent = Events

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

------------------------------------------------------------------ invincibilité / étourdissement (sans se marcher dessus)
local derniereEsquive = {}
local esquiveParfaite
local function pendant(char, attribut, duree)
	local fin = os.clock() + duree
	if (char:GetAttribute(attribut .. "_Fin") or 0) > fin then return end   -- un effet plus long est déjà en cours
	char:SetAttribute(attribut, true)
	char:SetAttribute(attribut .. "_Fin", fin)
	task.delay(duree, function()
		if char.Parent and (char:GetAttribute(attribut .. "_Fin") or 0) <= os.clock() + 0.01 then
			char:SetAttribute(attribut, nil)
			char:SetAttribute(attribut .. "_Fin", nil)
		end
	end)
end

------------------------------------------------------------------ ESQUIVE PARFAITE
-- victime = Player qui esquive ; attaquant = Player ou modèle de bot ; heureCoup = os.clock() du coup
esquiveParfaite = function(victime, attaquant, heureCoup)
	local P = Config.Esquive.Parfaite
	if not P or not P.Active then return false end
	local debut = derniereEsquive[victime]
	heureCoup = heureCoup or os.clock()
	if not debut or debut < heureCoup - P.Fenetre or debut > heureCoup + (Config.Combat.DelaiImpact or 0) + 0.05 then
		return false
	end
	derniereEsquive[victime] = -math.huge                  -- une seule esquive parfaite par esquive
	local vChar = victime.Character
	local aChar = (typeof(attaquant) == "Instance" and attaquant:IsA("Player")) and attaquant.Character or attaquant
	if not vChar or not aChar then return false end
	pendant(vChar, "Invincible", P.Invincible)
	pendant(aChar, "Etourdi", P.Etourdi)
	victime:SetAttribute("EsquiveRechargeBonus", os.clock())  -- lu par le client : esquive rechargée tout de suite
	-- l'attaquant est ralenti
	local hum = aChar:FindFirstChildOfClass("Humanoid")
	if hum and not aChar:GetAttribute("_VitesseAvantEtourdi") then
		aChar:SetAttribute("_VitesseAvantEtourdi", hum.WalkSpeed)
		hum.WalkSpeed = hum.WalkSpeed * P.Ralenti
		task.delay(P.Etourdi, function()
			local v = aChar:GetAttribute("_VitesseAvantEtourdi")
			if hum.Parent and v then hum.WalkSpeed = v end
			aChar:SetAttribute("_VitesseAvantEtourdi", nil)
		end)
	end
	local aJoueur = Players:GetPlayerFromCharacter(aChar)
	RFX:FireAllClients("EsquiveParfaite", vChar, aChar, Config.EquipeDe(victime), victime, aJoueur)
	EvParfaite:Fire(victime, attaquant)
	return true
end

-- pour les bots (GameManager / Bots) : true = le joueur visé esquive, le bot ne doit pas l'attraper
TesterEsquive.OnInvoke = function(victime, botModele)
	local c = victime and victime.Character
	if not c or not c:GetAttribute("Invincible") then return false end
	esquiveParfaite(victime, botModele, os.clock())
	return true
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
	if not tool or not vivant(char) or player:GetAttribute("EnPrison") or char:GetAttribute("Etourdi") then return end
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
		if autre ~= player and vivant(c) and not autre:GetAttribute("EnPrison")
			and Config.PeutAttaquer(equipe, Config.EquipeDe(autre)) then
			local delta = c.HumanoidRootPart.Position - root.Position
			local d = delta.Magnitude
			local plat = Vector3.new(delta.X, 0, delta.Z)
			local devant = plat.Magnitude < 1 or root.CFrame.LookVector:Dot(plat.Unit) >= cosMax
			if d <= portee and devant and d < distMin then cible, distMin = autre, d end
		end
	end
	if not cible then return end

	-- le coup touche quand la lame passe (DelaiImpact) : la cible peut encore esquiver jusque-là
	task.delay(Config.Combat.DelaiImpact or 0, function()
		local vChar = cible.Character
		if not vivant(vChar) or not vivant(char) or cible:GetAttribute("EnPrison") or player:GetAttribute("EnPrison") then return end
		local vRoot = vChar.HumanoidRootPart
		if (vRoot.Position - root.Position).Magnitude > portee * 1.35 then return end   -- elle s'est éloignée à temps
		if vChar:GetAttribute("Invincible") then
			-- esquive : parfaite si elle a commencé juste avant ou pendant le coup
			if esquiveParfaite(cible, player, now) then return end
			return
		end
		local pos = vRoot.Position:Lerp(root.Position, 0.35) + Vector3.new(0, 0.8, 0)
		RFX:FireAllClients("Impact", pos, id, vChar, player, cible, (vRoot.Position - root.Position).Unit, combo)
		if Config.Combat.Degats > 0 then vChar.Humanoid:TakeDamage(Config.Combat.Degats) end
		Touche:Fire(player, cible, id)
	end)
end)

------------------------------------------------------------------ esquive
local derniereDemande = {}
REsquive.OnServerEvent:Connect(function(player)
	if not Config.Esquive.Active then return end
	local now = os.clock()
	local bonus = player:GetAttribute("EsquiveRechargeBonus")
	local recharge = (bonus and now - bonus < 2) and (Config.Esquive.Parfaite.Recharge or 0.3) or Config.Esquive.Recharge
	if derniereDemande[player] and now - derniereDemande[player] < recharge * 0.85 then return end
	derniereDemande[player] = now
	derniereEsquive[player] = now
	player:SetAttribute("EsquiveRechargeBonus", nil)
	local char = player.Character
	if not vivant(char) or player:GetAttribute("EnPrison") then return end
	pendant(char, "Invincible", Config.Esquive.Invincible)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then RFX:FireClient(p, "Esquive", char, Config.EquipeDe(player)) end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	dernierCoup[p], derniereEsquive[p], derniereDemande[p] = nil, nil, nil
end)
