AddCSLuaFile()

if game.GetMap() != "gm_flatgrass" then return end

if SERVER then 
    util.AddNetworkString("TERRAIN_SEND_DATA")  // superadmin only!
    Terrain = Terrain or {}
    
    local function genChunks()
        for y = Terrain.Resolution - 1, -Terrain.Resolution, -1 do
            for x = Terrain.Resolution - 1, -Terrain.Resolution, -1 do
                // caves test
                //local chunk = ents.Create("terrain_chunk")
                //chunk:SetPos(Vector(x * Terrain.ChunkResScale, y * Terrain.ChunkResScale, Terrain.ZOffset))
                //chunk:SetChunkX(x)
                //chunk:SetChunkY(y)
                //chunk:SetOverhang(true)
                //chunk:Spawn()
                //table.insert(Terrain.Chunks, chunk)
    
                local chunk = ents.Create("terrain_chunk")
                chunk:SetPos(Vector(x * Terrain.ChunkResScale, y * Terrain.ChunkResScale, Terrain.ZOffset))
                chunk:SetChunkX(x)
                chunk:SetChunkY(y)
                chunk:Spawn()
                table.insert(Terrain.Chunks, chunk)
    
                coroutine.wait(0.1)
            end
        end
    end

    function Terrain.GenerateAll()
        for k, v in ipairs(Terrain.Chunks or {}) do
            SafeRemoveEntity(v)
        end
        
        local co = coroutine.create(genChunks)
        hook.Add("Think", "terrain_init", function()
            if coroutine.status(co) != "dead" then
                coroutine.resume(co)
            else
                hook.Remove("Think", "terrain_init")
            end
        end)
    end
    
    timer.Simple(1, Terrain.GenerateAll)    //generate all chunks

    net.Receive("TERRAIN_SEND_DATA", function(len, ply)
        if !ply or !ply:IsValid() or !ply:IsSuperAdmin() then return end    // only superadmins can edit terrain

        local t = net.ReadTable()
        Terrain.MathFunc = Terrain.BuildMathFunc(t)
        net.Start("TERRAIN_SEND_DATA")
        net.WriteTable(t)
        net.Broadcast()

        Terrain.Variables = t
        timer.Simple(1, Terrain.GenerateAll)    // give clients a second to receive the data
    end)
else
    // clients can randomly forget chunk data during a lagspike, we rebuild it if that happens
    local co = coroutine.create(function()
        while true do 
            for k, v in ipairs(ents.FindByClass("terrain_chunk")) do
                if v:IsValid() and (!v:GetPhysicsObject() or !v:GetPhysicsObject():IsValid()) then
                    print("Rebuilding Physics for Chunk " .. v:GetChunkX() .. "," .. v:GetChunkY())
                    v:OnRemove()
                    v:Initialize()
                end
                coroutine.yield()
            end
            coroutine.wait(10)
        end
    end)

    // request server to reload chunks
    hook.Add("Tick", "terrain_init", function()
        coroutine.resume(co)
    end)

    net.Receive("TERRAIN_SEND_DATA", function(len)
        local t = net.ReadTable()
        Terrain.Variables = t
        Terrain.MathFunc = Terrain.BuildMathFunc()
    end)
end