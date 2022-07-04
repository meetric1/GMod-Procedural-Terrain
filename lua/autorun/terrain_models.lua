if game.GetMap() != "gm_flatgrass" then return end

AddCSLuaFile()

hook.Add("InitPostEntity", "terrain_modelinit", function()
    Terrain.TreeModels = {
        "models/procedural_terrain/foliage/tree_pine04.mdl",
        "models/procedural_terrain/foliage/tree_pine05.mdl",
        "models/procedural_terrain/foliage/tree_pine06.mdl",
        "models/procedural_terrain/foliage/tree_pine_large.mdl",
        "models/procedural_terrain/foliage/rock_coast02a.mdl",
    }

    for k, v in ipairs(Terrain.TreeModels) do
        util.PrecacheModel(v)
    end

    // client = visual meshes, server = physics meshes
    if CLIENT then
        local tree_material = Material("procedural_terrain/foliage/arbre01.vmt")
        Terrain.TreeMaterials = {
            tree_material,
            tree_material,
            tree_material,
            tree_material,
            Material("procedural_terrain/foliage/coastrock02.vmt"),
        }

        Terrain.TreeMeshes = {}
        Terrain.TreeMeshes_Low = {}

        // build and cache tree models
        for k, treeModel in ipairs(Terrain.TreeModels) do
            Terrain.TreeMeshes[k] = Mesh()
            local mesh1 = util.GetModelMeshes(treeModel)    // model doesnt exist on client?! replace with a wood pole..
            if !mesh1 then treeModel = "models/props_docks/dock02_pole02a.mdl" end
            Terrain.TreeMeshes[k]:BuildFromTriangles(util.GetModelMeshes(treeModel)[1].triangles)

            Terrain.TreeMeshes_Low[k] = Mesh()
            Terrain.TreeMeshes_Low[k]:BuildFromTriangles(util.GetModelMeshes(treeModel, 8)[1].triangles)
        end
        
    end

    // physmesh generation
    // there is no way to get the physmesh data of a model without creating a prop??? wtf???
    Terrain.TreePhysMeshes = {}
    for k, v in ipairs(Terrain.TreeModels) do
        if SERVER then
            local tree = ents.Create("prop_physics")
            tree:SetModel(v)
            tree:Spawn()
            Terrain.TreePhysMeshes[k] = tree:GetPhysicsObject():GetMesh()
            SafeRemoveEntity(tree)
        end
        //else
        //    if !util.GetModelMeshes(v) then v = "models/props_docks/dock02_pole02a.mdl" end
        //    local tree = ents.CreateClientProp(v)
        //    Terrain.TreePhysMeshes[k] = tree:GetPhysicsObject():GetMesh()
        //    SafeRemoveEntity(tree)
        //end
    end
end)