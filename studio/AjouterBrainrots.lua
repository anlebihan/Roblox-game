--[[
	💰 Cashout Chaos — Ajouter les nouveaux brainrots (tous d'un coup)

	AVANT :
	  1. Studio > Accueil > Importer 3D > importer les .glb du dossier assets/ (un par un,
	     options par défaut). Chaque modèle arrive dans Workspace avec le nom du fichier.
	  2. Coller TOUT ce script dans la Barre de commandes (Affichage > Barre de commandes) et Entrée.

	Le script traite seulement les modèles de la liste présents dans Workspace
	(tu peux donc en importer une partie seulement, puis relancer le script plus tard).
	Il ne supprime rien et ne remplace jamais un brainrot déjà présent.
]]

local NOMS = {
	"TungTungTungSahur",
	"BombardiroCrocodilo",
	"TralaleroTralala",
	"BobriniCocosini",
	"UdinDinDinDun",
	"DragonCannelloni",
	"CapuccinoAssassino",
	"KarkerkarKurkur",
}

-- Mets true pour un brainrot qui regarde dans le mauvais sens après l'import
local TOURNER_180 = {
	-- TralaleroTralala = true,
}

local RS = game:GetService("ReplicatedStorage")
local dossier = RS:WaitForChild("Assets"):WaitForChild("Brainrots")

-- Taille cible = moyenne de la plus grande dimension des brainrots déjà présents (sinon 8 studs)
local total, n = 0, 0
for _, autre in ipairs(dossier:GetChildren()) do
	if autre:IsA("Model") then
		local _, t = autre:GetBoundingBox()
		total += math.max(t.X, t.Y, t.Z)
		n += 1
	end
end
local TAILLE_CIBLE = n > 0 and total / n or 8

local function installer(nom)
	local modele = workspace:FindFirstChild(nom)
	if not modele then
		return false, "pas dans Workspace (pas encore importé ?)"
	end
	if dossier:FindFirstChild(nom) then
		return false, "existe déjà dans Assets.Brainrots, rien n'est remplacé"
	end

	-- L'importeur peut donner une MeshPart seule : on l'emballe dans un Model
	if not modele:IsA("Model") then
		local m = Instance.new("Model")
		m.Name = nom
		m.Parent = workspace
		modele.Parent = m
		modele = m
	end

	local pieces = {}
	for _, d in ipairs(modele:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true -- pour le ProximityPrompt
			d.Massless = true
			table.insert(pieces, d)
		end
	end
	if #pieces == 0 then
		return false, "aucune pièce 3D dans le modèle"
	end

	-- Taille : la plus grande dimension = celle des autres brainrots
	-- (ainsi Bombardiro, très large, n'est pas géant)
	local _, t = modele:GetBoundingBox()
	modele:ScaleTo(modele:GetScale() * TAILLE_CIBLE / math.max(t.X, t.Y, t.Z))

	if TOURNER_180[nom] then
		modele:PivotTo(modele:GetPivot() * CFrame.Angles(0, math.pi, 0))
	end

	-- Pivot en bas au centre, aligné sur le monde
	local cf, taille = modele:GetBoundingBox()
	local base = CFrame.new(cf.Position - Vector3.new(0, taille.Y / 2, 0))
	modele.PrimaryPart = pieces[1]
	pieces[1].PivotOffset = pieces[1].CFrame:ToObjectSpace(base)
	modele.WorldPivot = base

	modele:PivotTo(CFrame.new())
	modele.Parent = dossier
	return true, ("%d pièce(s), taille %.1f studs"):format(#pieces, TAILLE_CIBLE)
end

print("— Ajout des brainrots —")
for _, nom in ipairs(NOMS) do
	local ok, msg = installer(nom)
	print((ok and "✅ " or "⏭️ ") .. nom .. " : " .. msg)
end
print("👉 Dernière étape : ajouter leurs lignes dans Config (voir studio/LISEZMOI.md).")
