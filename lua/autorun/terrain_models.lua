
AddCSLuaFile()

hook.Add("InitPostEntity", "terrain_modelinit", function()
    // todo: import these models instead of using them directly from EP2
    Terrain.TreeModels = {
        "models/props_foliage/tree_pine04.mdl",
        "models/props_foliage/tree_pine05.mdl",
        "models/props_foliage/tree_pine06.mdl",
        "models/props_foliage/tree_pine_large.mdl",
        "models/props_foliage/rock_coast02a.mdl",
    }

    for k, v in ipairs(Terrain.TreeModels) do
        util.PrecacheModel(v)
    end

    // client = visual meshes, server = physics meshes
    if CLIENT then
        Terrain.TreeMeshes = {}
        Terrain.TreeMeshes_Low = {}

        // build and cache tree models
        for k, treeModel in ipairs(Terrain.TreeModels) do
            Terrain.TreeMeshes[k] = Mesh()
            Terrain.TreeMeshes[k]:BuildFromTriangles(util.GetModelMeshes(treeModel)[1].triangles)

            Terrain.TreeMeshes_Low[k] = Mesh()
            Terrain.TreeMeshes_Low[k]:BuildFromTriangles(util.GetModelMeshes(treeModel, 8)[1].triangles)
        end
    end

    // physmesh generation
    // unfortunately I saw no way to get the physmesh data of a model without creating a prop
    Terrain.TreePhysMeshes = {}
    Terrain.TreeMaterials = {}
    for k, v in ipairs(Terrain.TreeModels) do
        if SERVER then
            local tree = ents.Create("prop_physics")
            tree:SetModel(v)
            tree:Spawn()
            Terrain.TreePhysMeshes[k] = tree:GetPhysicsObject():GetMesh()
            SafeRemoveEntity(tree)
        else
            local tree = ents.CreateClientProp(v)
            Terrain.TreePhysMeshes[k] = tree:GetPhysicsObject():GetMesh()
            Terrain.TreeMaterials[k] = Material(tree:GetMaterials()[1])
            SafeRemoveEntity(tree)
        end
    end
end)