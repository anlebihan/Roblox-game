--[[ À COLLER DANS LA BARRE DE COMMANDES de Studio (Affichage > Barre de commandes), puis Entrée.
     Avant : 1) ReplicatedStorage.Couteaux.Config existe (ModuleScript)
             2) les 15 fichiers .glb du dossier « modeles » sont importés (Accueil > Importer 3D).
     Chaque couteau importé contient 2 MeshParts :
        <Id>_Body_tex        le couteau texturé (texture tirée de l'image de référence)
        <Id>_Outline_outline le contour noir cartoon
     Ce script en fait un Tool prêt à l'emploi dans ReplicatedStorage.Couteaux.Outils :
     soudures, « Handle », prise en main au milieu du manche, points de traînée, zone de la lame (effets).
     Il ne supprime rien : un couteau déjà installé est sauté.
]]
local RS = game:GetService("ReplicatedStorage")
local dossier = RS:FindFirstChild("Couteaux")
assert(dossier and dossier:FindFirstChild("Config"), "Crée d'abord ReplicatedStorage.Couteaux.Config (voir LISEZMOI)")
local Config = require(dossier.Config)
local outils = dossier:FindFirstChild("Outils") or Instance.new("Folder")
outils.Name = "Outils"
outils.Parent = dossier

-- Mesures faites à la création (studs, depuis le bas du manche) :
--   long = longueur totale, garde = hauteur de la garde (début de la lame)
local MESURES = {
	PouleBase = { long = 2.80, garde = 1.12 },
	PouleRoyal = { long = 2.85, garde = 1.05 },
	PoulePlume = { long = 2.90, garde = 0.87 },
	PouleElectrique = { long = 2.85, garde = 0.97 },
	PouleGeant = { long = 3.10, garde = 1.12 },
	RenardBase = { long = 2.80, garde = 1.20 },
	RenardFurtif = { long = 2.80, garde = 1.20 },
	RenardSpectre = { long = 2.80, garde = 1.12 },
	RenardLegendaire = { long = 2.85, garde = 1.14 },
	RenardOrigami = { long = 2.80, garde = 1.20 },
	ViperBase = { long = 2.80, garde = 1.26 },
	ViperToxique = { long = 2.80, garde = 1.18 },
	ViperSerpent = { long = 2.90, garde = 1.10 },
	ViperVenin = { long = 2.80, garde = 1.18 },
	ViperRoyal = { long = 2.85, garde = 1.43 },
}
local TAILLE = Config.Taille or 1 -- Config.Taille = 1.3 pour des couteaux 30 % plus grands

-- toutes les pièces importées : <Id>_<Partie>_<cle>
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

local function boite(p)
	return p.Position.Y - p.Size.Y / 2, p.Position.Y + p.Size.Y / 2
end

local installes, manquants = 0, {}
for id, def in pairs(Config.Couteaux) do
	local pieces = parId[id]
	local mes = MESURES[id] or { long = 2.8, garde = 1.1 }
	if outils:FindFirstChild(id) then
		print("[Couteaux] déjà installé, ignoré :", id)
	elseif not pieces then
		table.insert(manquants, id)
	else
		local corps, contour
		for _, p in ipairs(pieces) do
			if string.find(p.Name, "_outline$") then contour = p else corps = corps or p end
		end
		local ancienParent = corps.Parent

		-- taille : remet à la bonne échelle si Studio a importé dans une autre unité
		local bas, haut = boite(corps)
		local f = mes.long * TAILLE / math.max(haut - bas, 0.01)
		if math.abs(f - 1) > 0.03 then
			local c = corps.Position
			for _, p in ipairs(pieces) do
				local pos = c + (p.Position - c) * f
				p.Size = p.Size * f
				p.CFrame = p.CFrame - p.Position + pos
			end
			print(("[Couteaux] %s remis à l'échelle (x%.2f)"):format(id, f))
			bas, haut = boite(corps)
		end
		local k = (haut - bas) / mes.long             -- studs réels / studs mesurés

		local tool = Instance.new("Tool")
		tool.Name = id
		tool.ToolTip = def.Nom
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool:SetAttribute("CouteauId", id)
		tool:SetAttribute("Equipe", def.Equipe)

		for _, p in ipairs(pieces) do
			local cle = string.match(p.Name, "_([%w]+)$")
			local pal = cle and Config.Palette[cle]
			if pal then -- pièce unie (le contour) : couleur de la palette
				p.Color, p.Material, p.Reflectance = pal[1], pal[2], pal[3] or 0
			end
			p.Anchored = false
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.Massless = true
			p.CastShadow = (p ~= contour)
			p.Parent = tool
			if p ~= corps then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = corps, p
				w.Parent = p
			end
		end
		corps.Name = "Handle"

		local yGarde = bas + mes.garde * k
		local function attache(nom, y)
			local a = Instance.new("Attachment")
			a.Name = nom
			a.Parent = corps
			a.WorldPosition = Vector3.new(corps.Position.X, y, corps.Position.Z)
			return a
		end
		attache("LameBase", yGarde + 0.12 * k)
		attache("LamePointe", haut - 0.08 * k)
		attache("Main", (bas + yGarde) / 2)

		-- zone invisible couvrant la lame : sert d'émetteur pour les auras
		local zone = Instance.new("Part")
		zone.Name = "ZoneLame"
		zone.Transparency = 1
		zone.CanCollide, zone.CanTouch, zone.CanQuery, zone.Anchored = false, false, false, false
		zone.Massless = true
		zone.Size = Vector3.new(corps.Size.X * 0.6, haut - yGarde, math.max(corps.Size.Z * 0.5, 0.1))
		zone.CFrame = CFrame.new(corps.Position.X, (haut + yGarde) / 2, corps.Position.Z)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = corps, zone
		w.Parent = zone
		zone.Parent = tool

		-- la main tient le milieu du manche
		local main = corps.CFrame:PointToObjectSpace(Vector3.new(corps.Position.X, (bas + yGarde) / 2, corps.Position.Z))
		tool.Grip = CFrame.new(main) * Config.Grip
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
