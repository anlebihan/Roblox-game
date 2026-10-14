--[[ À COLLER DANS LA BARRE DE COMMANDES de Studio, puis Entrée.        — TRIPLE HUNT —
     Avant : importer toutes les images du dossier interface/images (Gestionnaire de ressources >
     « Importation groupée »), puis dans le Gestionnaire de ressources : sélectionner toutes ces images >
     clic droit > « Insérer » (Studio crée un Decal par image dans le Workspace, avec son ID).
     Ce script lit ces Decals et crée / met à jour le ModuleScript ReplicatedFirst.ImagesInterface
     (nom du fichier -> rbxassetid). Les Decals sont ensuite rangés dans ServerStorage.ImagesImportees
     (rien n'est supprimé).
]]
local RF = game:GetService("ReplicatedFirst")
local SS = game:GetService("ServerStorage")
local ids = {}
local decals = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Decal") and d.Texture ~= "" then
		local nom = d.Name:gsub("%.png$", "")
		if nom:match("^chargement_") or nom:match("^fx_") or nom:match("^logo") or nom:match("^caisse_")
			or nom:match("^pieces_") or nom:match("^icone_") or nom:match("^menu_") then
			ids[nom] = d.Texture
			table.insert(decals, d)
		end
	end
end
local lignes = { "-- Généré par InstallerImages.lua : nom de l'image -> ID Roblox", "return {" }
local noms = {}
for nom in pairs(ids) do table.insert(noms, nom) end
table.sort(noms)
for _, nom in ipairs(noms) do
	table.insert(lignes, ('\t["%s"] = "%s",'):format(nom, ids[nom]))
end
table.insert(lignes, "}")
local module = RF:FindFirstChild("ImagesInterface") or Instance.new("ModuleScript")
module.Name = "ImagesInterface"
module.Source = table.concat(lignes, "\n")
module.Parent = RF
local rangement = SS:FindFirstChild("ImagesImportees") or Instance.new("Folder")
rangement.Name = "ImagesImportees"
rangement.Parent = SS
for _, d in ipairs(decals) do
	local porteur = d.Parent
	d.Parent = rangement
	if porteur and porteur:IsA("BasePart") and #porteur:GetChildren() == 0 and porteur.Name == "Part" then
		porteur.Parent = rangement -- la pièce vide créée par l'insertion
	end
end
print(("[Interface] %d image(s) enregistrée(s) dans ReplicatedFirst.ImagesInterface"):format(#noms))
