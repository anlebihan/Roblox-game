--[[ À COLLER DANS LA BARRE DE COMMANDES de Studio (Affichage > Barre de commandes), puis Entrée.
     Avant : 1) ReplicatedStorage.Couteaux.Config existe (ModuleScript)
             2) les 15 fichiers .glb du dossier « modeles » sont importés (Accueil > Importer 3D).
     Ce script transforme chaque modèle importé en Tool prêt à l'emploi, rangé dans
     ReplicatedStorage.Couteaux.Outils : couleurs + Neon, soudures, « Handle », points de traînée.
     Il ne supprime rien : s'il trouve un couteau déjà installé, il le saute.
]]
local RS = game:GetService("ReplicatedStorage")
local dossier = RS:FindFirstChild("Couteaux")
assert(dossier and dossier:FindFirstChild("Config"), "Crée d'abord ReplicatedStorage.Couteaux.Config (voir LISEZMOI)")
local Config = require(dossier.Config)
local outils = dossier:FindFirstChild("Outils") or Instance.new("Folder")
outils.Name = "Outils"
outils.Parent = dossier

-- toutes les pièces importées : <Id>_<Partie>_<couleur>
local parId = {}
for _, p in ipairs(workspace:GetDescendants()) do
	if p:IsA("MeshPart") then
		for id in pairs(Config.Couteaux) do
			if string.sub(p.Name, 1, #id + 1) == id .. "_" and not p:FindFirstAncestorOfClass("Tool") then
				parId[id] = parId[id] or {}
				table.insert(parId[id], p)
			end
		end
	end
end

-- longueur totale de chaque couteau (studs), mesurée dans Blender
local LONGUEUR = {
	PouleBase = 2.72, PouleRoyal = 2.85, PoulePlume = 3.01, PouleElectrique = 2.8, PouleGeant = 2.96,
	RenardBase = 2.7, RenardFurtif = 2.81, RenardSpectre = 2.69, RenardLegendaire = 2.85, RenardOrigami = 2.7,
	ViperBase = 2.81, ViperToxique = 2.8, ViperSerpent = 2.91, ViperVenin = 2.8, ViperRoyal = 2.85,
}
local TAILLE = Config.Taille or 1 -- Config.Taille = 1.3 pour des couteaux 30 % plus grands

-- remet le couteau à la bonne taille si Studio l'a importé dans une autre unité
local function mettreAEchelle(id, pieces)
	local yMin, yMax, centre = math.huge, -math.huge, Vector3.zero
	for _, p in ipairs(pieces) do
		if not string.find(p.Name, "_outline$") then
			yMin = math.min(yMin, p.Position.Y - p.Size.Y / 2)
			yMax = math.max(yMax, p.Position.Y + p.Size.Y / 2)
		end
		centre += p.Position
	end
	centre /= #pieces
	local f = (LONGUEUR[id] or 2.8) * TAILLE / math.max(yMax - yMin, 0.01)
	if math.abs(f - 1) < 0.03 then return end
	for _, p in ipairs(pieces) do
		local pos = centre + (p.Position - centre) * f
		p.Size = p.Size * f
		p.CFrame = p.CFrame - p.Position + pos
	end
	print(("[Couteaux] %s remis à l'échelle (x%.2f)"):format(id, f))
end

local installes, manquants = 0, {}
for id, def in pairs(Config.Couteaux) do
	local pieces = parId[id]
	if outils:FindFirstChild(id) then
		print("[Couteaux] déjà installé, ignoré :", id)
	elseif not pieces then
		table.insert(manquants, id)
	else
		local tool = Instance.new("Tool")
		tool.Name = id
		tool.ToolTip = def.Nom
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool:SetAttribute("CouteauId", id)
		tool:SetAttribute("Equipe", def.Equipe)

		mettreAEchelle(id, pieces)
		local handle, volMax = nil, 0
		local yMin, yMax, centreLame = math.huge, -math.huge, Vector3.zero
		local nLame = 0
		local ancienParent = pieces[1].Parent
		for _, p in ipairs(pieces) do
			local reste = string.sub(p.Name, #id + 2)
			local partie, cle = string.match(reste, "^([^_]+)_(.+)$")
			local pal = cle and Config.Palette[cle]
			for _, sa in ipairs(p:GetChildren()) do
				if sa:IsA("SurfaceAppearance") then sa:Destroy() end -- import brut : on garde nos couleurs
			end
			if pal then
				p.Color = pal[1]
				p.Material = pal[2]
				p.Reflectance = pal[3] or 0
			end
			p.Anchored = false
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.Massless = true
			p.CastShadow = (cle ~= "outline")
			p.DoubleSided = false
			if partie == "Handle" then
				local v = p.Size.X * p.Size.Y * p.Size.Z
				if v > volMax then handle, volMax = p, v end
			elseif partie == "Blade" then
				yMin = math.min(yMin, p.Position.Y - p.Size.Y / 2)
				yMax = math.max(yMax, p.Position.Y + p.Size.Y / 2)
				centreLame += p.Position
				nLame += 1
			end
		end
		handle = handle or pieces[1]
		for _, p in ipairs(pieces) do
			p.Parent = tool
			if p ~= handle then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = handle, p
				w.Parent = p
			end
		end
		handle.Name = "Handle"

		-- points de la traînée (base et pointe de la lame)
		if nLame > 0 then
			centreLame /= nLame
			local base = Instance.new("Attachment")
			base.Name = "LameBase"
			base.Parent = handle
			base.WorldPosition = Vector3.new(centreLame.X, yMin + 0.15, centreLame.Z)
			local pointe = Instance.new("Attachment")
			pointe.Name = "LamePointe"
			pointe.Parent = handle
			pointe.WorldPosition = Vector3.new(centreLame.X, yMax - 0.05, centreLame.Z)
		end
		tool.Grip = Config.Grip
		tool.Parent = outils
		installes += 1
		if ancienParent and ancienParent ~= workspace and #ancienParent:GetDescendants() == 0 then
			print("[Couteaux] le modèle importé « " .. ancienParent:GetFullName() .. " » est vide, tu peux le supprimer")
		end
	end
end
print(("[Couteaux] %d couteau(x) installé(s) dans ReplicatedStorage.Couteaux.Outils"):format(installes))
if #manquants > 0 then
	warn("[Couteaux] pas trouvés dans le Workspace (importe leur .glb) : " .. table.concat(manquants, ", "))
end
