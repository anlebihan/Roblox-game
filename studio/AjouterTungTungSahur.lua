--[[
	💰 Cashout Chaos — Ajouter le brainrot « Tung Tung Tung Sahur »

	AVANT :
	  1. Studio > onglet Accueil > Importer 3D > choisir assets/TungTungTungSahur.glb
	     (laisser les options par défaut, cliquer Importer).
	     Le modèle arrive dans Workspace sous le nom « TungTungTungSahur ».
	  2. Coller TOUT ce script dans la Barre de commandes (Affichage > Barre de commandes) et Entrée.

	Ce que fait le script (sans rien supprimer d'autre) :
	  - range le modèle dans ReplicatedStorage.Assets.Brainrots
	  - ancre les pièces, retire les collisions, pose le pivot en bas au centre (aligné monde)
	  - règle sa hauteur sur la moyenne des autres brainrots
]]

local NOM = "TungTungTungSahur"

local RS = game:GetService("ReplicatedStorage")
local dossier = RS:WaitForChild("Assets"):WaitForChild("Brainrots")

local modele = workspace:FindFirstChild(NOM)
if not modele then
	warn("❌ Modèle '" .. NOM .. "' introuvable dans Workspace : importe d'abord le .glb.")
	return
end
if dossier:FindFirstChild(NOM) then
	warn("⚠️ Un brainrot '" .. NOM .. "' existe déjà dans Assets.Brainrots : rien n'est remplacé.")
	return
end

-- L'importeur peut créer un Model dans un Model : on s'assure d'avoir un Model.
if not modele:IsA("Model") then
	local m = Instance.new("Model")
	m.Name = NOM
	modele.Parent = m
	m.Parent = workspace
	modele = m
end

-- Pièces : ancrées, sans collision, pas d'ombre bizarre
local pieces = {}
for _, d in ipairs(modele:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = true
		d.CanCollide = false
		d.CanTouch = false
		d.CanQuery = true -- pour que le ProximityPrompt fonctionne
		d.Massless = true
		table.insert(pieces, d)
	end
end
assert(#pieces > 0, "Aucune pièce 3D trouvée dans le modèle")

-- Hauteur cible = moyenne des autres brainrots (sinon 8 studs)
local total, n = 0, 0
for _, autre in ipairs(dossier:GetChildren()) do
	if autre:IsA("Model") then
		local _, taille = autre:GetBoundingBox()
		total += taille.Y
		n += 1
	end
end
local hauteurCible = n > 0 and total / n or 8

local _, taille = modele:GetBoundingBox()
modele:ScaleTo(modele:GetScale() * hauteurCible / taille.Y)

-- Pivot en bas au centre, aligné sur le monde (comme les autres brainrots)
local cf, t = modele:GetBoundingBox()
local base = CFrame.new(cf.Position - Vector3.new(0, t.Y / 2, 0))
local racine = pieces[1]
modele.PrimaryPart = racine
racine.PivotOffset = racine.CFrame:ToObjectSpace(base)
modele.WorldPivot = base

modele:PivotTo(CFrame.new(0, 0, 0))
modele.Parent = dossier

print(("✅ %s ajouté dans Assets.Brainrots (hauteur %.1f studs, %d pièces)."):format(NOM, hauteurCible, #pieces))
print("👉 Dernière étape : ajouter sa ligne dans Config (voir studio/LISEZMOI.md).")
