
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Deform Test"
ENT.PrintName		= "Terrain Chunk"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ChunkX")
    self:NetworkVar("Int", 1, "ChunkY")
    self:NetworkVar("Bool", 0, "Overhang")
end

Terrain = Terrain or {}

if CLIENT then
    --Terrain.Material = Material("nature/blendrocksgrass006a")
    Terrain.Material = CreateMaterial("NatureblendTerrain01", "WorldVertexTransition", {
        ["$basetexture"] = "nature/rockfloor005a",
	    ["$surfaceprop"] = "rock",
	    ["$basetexture2"] = "gm_construct/grass1",
	    ["$surfaceprop2"] = "dirt",
        ["$seamless_scale"] = 0.002,
        ["$nocull"] = 1,
    })

    -- todo: import these models instead of using them directly from EP2
    Terrain.TreeModels = {
        "models/props_foliage/tree_pine04.mdl",
        "models/props_foliage/tree_pine05.mdl",
        "models/props_foliage/tree_pine06.mdl",
        "models/props_foliage/tree_pine_large.mdl",
        "models/props_foliage/rock_coast02a.mdl",
    }
end

function ENT:GenerateTrees(heightFunction, values)
    local values = values or Terrain.MathFuncVariables
    local heightFunction = heightFunction or Terrain.MathFunc
    local treeResolution = values.treeResolution or Terrain.TreeResolution
    local treeHeight     = values.treeHeight     or Terrain.TreeHeight

    self.TreeMatrices = {}
    self.TreeModels = {}
    self.TreeShading = {}

    if self:GetOverhang() then return end
    local treeMultiplier = Terrain.ChunkResolution / treeResolution * Terrain.ChunkSize
    local randomIndex = 0
    local chunkIndex = tostring(self:GetChunkX()) .. tostring(self:GetChunkY())
    for y = 0, treeResolution - 1 do
        for x = 0, treeResolution - 1 do
            randomIndex = randomIndex + 1
            local m = Matrix()

            // generate seeded random position for tree
            local randseedx = util.SharedRandom("TerrainSeedX" .. chunkIndex, 0, 1, randomIndex)
            local randseedy = util.SharedRandom("TerrainSeedY" .. chunkIndex, 0, 1, randomIndex)
            local randPos = Vector(randseedx, randseedy) * treeMultiplier

            -- chunk offset in world space
            local chunkoffsetx = self:GetChunkX() * Terrain.ChunkResScale + randPos[1]
            local chunkoffsety = self:GetChunkY() * Terrain.ChunkResScale + randPos[2]

            -- vertex of the triangle in the chunks local space
            local worldx = x * treeMultiplier
            local worldy = y * treeMultiplier
            
            -- no trees in spawn area (1000x1000 hu square)
            if values.spawnArea and math.abs(worldx + chunkoffsetx) < 1500 and math.abs(worldy + chunkoffsety) < 1500 then continue end

            -- the height of the vertex using the math function
            local vertexHeight = heightFunction(worldx + chunkoffsetx, worldy + chunkoffsety, self)
            local middleHeight = Vector(0, 0, vertexHeight)
            
            -- calculate the smoothed normal, if it is extreme, do not place a tree
            local smoothedNormal = Vector()
            for cornery = 0, 1 do
                for cornerx = 0, 1 do
                    -- get 4 corners in a for loop ranging from -1 to 1
                    local cornerx = (cornerx - 0.5) * 2 * 0.01
                    local cornery = (cornery - 0.5) * 2 * 0.01

                    -- get the height of the 0x triangle
                    local cornerWorldx = worldx
                    local cornerWorldy = (y + cornery) * treeMultiplier
                    local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, cornerWorldy + chunkoffsety, self)
                    local middleXPosition = Vector(0, treeMultiplier * cornery, cornerHeight)

                    -- get the height of the 0y triangle
                    local cornerWorldx = (x + cornerx) * treeMultiplier
                    local cornerWorldy = worldy
                    local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, cornerWorldy + chunkoffsety, self)
                    local middleYPosition = Vector(treeMultiplier * cornerx, 0, cornerHeight)
                    
                    -- we now have 3 points, construct a triangle from this and add the normal to the average normal
                    local triNormal = (middleYPosition - middleHeight):Cross(middleXPosition - middleHeight) * cornerx * cornery
                    smoothedNormal = smoothedNormal + triNormal
                end
            end

            smoothedNormal = smoothedNormal:GetNormalized()

            if smoothedNormal[3] < Terrain.TreeThreshold then continue end    -- remove trees on extreme slopes

            local finalPos = Vector(worldx + chunkoffsetx, worldy + chunkoffsety, vertexHeight + Terrain.ZOffset - 25.6 * treeHeight) -- pushed down 25.6 units, (height of the base of the tree model)

            m:SetTranslation(finalPos)
            m:SetAngles(Angle(0, randseedx * 360000, 0))--smoothedNormal:Angle() + Angle(90, 0, 0)
            m:SetScale(Vector(1, 1, 1) * treeHeight)
            finalPos[3] = finalPos[3] + 256 * treeHeight  -- add tree height
            table.insert(self.TreeMatrices, m)
            table.insert(self.TreeModels, math.floor(util.SharedRandom("TerrainModel" .. chunkIndex, 0, 4.1, randomIndex)) + 1)  -- 4.1 means 1/50 chance for a rock to generate instead of a tree
            table.insert(self.TreeShading, util.TraceLine({start = finalPos, endpos = finalPos + Terrain.SunDir * 99999}).HitSky and 1.5 or 0.5)
        end
    end
end

function ENT:GenerateMesh(heightFunction)
    local heightFunction = heightFunction or Terrain.MathFunc
    -- generate a mesh for the chunk using the mesh library
    self.RenderMesh = Mesh(Terrain.Material)
    local mesh = mesh   -- local lookup is faster than global
    local err, msg
    local function smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos)
        local unwrappedPos = vertexPos / Terrain.ChunkSize
        local smoothedNormal = Vector()
        for cornery = 0, 1 do
            for cornerx = 0, 1 do
                -- get 4 corners in a for loop ranging from -1 to 1
                local cornerx = (cornerx - 0.5) * 2
                local cornery = (cornery - 0.5) * 2

                -- get the height of the 0x triangle
                local cornerWorldx = vertexPos[1]
                local cornerWorldy = (unwrappedPos[2] + cornery) * Terrain.ChunkSize
                local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, cornerWorldy + chunkoffsety, self)
                local middleXPosition = Vector(0, Terrain.ChunkSize * cornery, cornerHeight)

                -- get the height of the 0y triangle
                local cornerWorldx = (unwrappedPos[1] + cornerx) * Terrain.ChunkSize
                local cornerWorldy = vertexPos[2]
                local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, cornerWorldy + chunkoffsety, self)
                local middleYPosition = Vector(Terrain.ChunkSize * cornerx, 0, cornerHeight)

                -- we now have 3 points, construct a triangle from this and add the normal to the average normal
                local triNormal = (middleYPosition - vertexPos):Cross(middleXPosition - vertexPos) * cornerx * cornery
                smoothedNormal = smoothedNormal + triNormal
            end
        end

        return smoothedNormal:GetNormalized()
    end

    mesh.Begin(self.RenderMesh, MATERIAL_TRIANGLES, Terrain.ChunkResolution^2 * 2)
    err, msg = pcall(function()
        for y = 0, Terrain.ChunkResolution - 1 do
            for x = 0, Terrain.ChunkResolution - 1 do
                -- chunk offset in world space
                local chunkoffsetx = self:GetChunkX() * Terrain.ChunkResScale   -- Terrain.ChunkSize * Terrain.ChunkResolution
                local chunkoffsety = self:GetChunkY() * Terrain.ChunkResScale

                -- vertex of the triangle in the chunks local space
                local worldx1 = x * Terrain.ChunkSize
                local worldy1 = y * Terrain.ChunkSize
                local worldx2 = (x + 1) * Terrain.ChunkSize
                local worldy2 = (y + 1) * Terrain.ChunkSize

                -- the height of the vertex using the math function
                local vertexHeight1 = heightFunction(worldx1 + chunkoffsetx, worldy1 + chunkoffsety, self)
                local vertexHeight2 = heightFunction(worldx1 + chunkoffsetx, worldy2 + chunkoffsety, self)
                local vertexHeight3 = heightFunction(worldx2 + chunkoffsetx, worldy1 + chunkoffsety, self)
                local vertexHeight4 = heightFunction(worldx2 + chunkoffsetx, worldy2 + chunkoffsety, self)

                -- vertex positions in local space
                local vertexPos1 = Vector(worldx1, worldy1, vertexHeight1)
                local vertexPos2 = Vector(worldx1, worldy2, vertexHeight2)
                local vertexPos3 = Vector(worldx2, worldy1, vertexHeight3)
                local vertexPos4 = Vector(worldx2, worldy2, vertexHeight4)

                -- lightmap uv calculation, needs to spread over whole terrain or it looks weird
                -- since chunks range into negative numbers we need to adhere to that
                local uvx1 = ((self:GetChunkX() + Terrain.Resolution) / Terrain.Resolution + (x / Terrain.ChunkResolution / Terrain.Resolution)) * 0.5
                local uvy1 = ((self:GetChunkY() + Terrain.Resolution) / Terrain.Resolution + (y / Terrain.ChunkResolution / Terrain.Resolution)) * 0.5
                local uvx2 = ((self:GetChunkX() + Terrain.Resolution) / Terrain.Resolution + ((x + 1) / Terrain.ChunkResolution / Terrain.Resolution)) * 0.5
                local uvy2 = ((self:GetChunkY() + Terrain.Resolution) / Terrain.Resolution + ((y + 1) / Terrain.ChunkResolution / Terrain.Resolution)) * 0.5

                local normal1 = (vertexPos1 - vertexPos2):Cross(vertexPos1 - vertexPos3):GetNormalized()
                local normal2 = (vertexPos4 - vertexPos3):Cross(vertexPos4 - vertexPos2):GetNormalized()

                local smoothedNormal1 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos1)
                local smoothedNormal2 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos2)
                local smoothedNormal3 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos3)
                local smoothedNormal4 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos4)

                local color1 = math.Min(smoothedNormal1[3] * 512, 255)
                local color2 = math.Min(smoothedNormal2[3] * 512, 255)
                local color3 = math.Min(smoothedNormal3[3] * 512, 255)
                local color4 = math.Min(smoothedNormal4[3] * 512, 255)

                -- first tri
                mesh.Position(vertexPos1)
                mesh.TexCoord(0, 0, 0)        -- texture UV
                mesh.TexCoord(1, uvx1, uvy1)  -- lightmap UV
                mesh.Color(255, 255, 255, color1)
                mesh.Normal(-normal1)
                
                mesh.AdvanceVertex()
                mesh.Position(vertexPos2)
                mesh.TexCoord(0, 1, 0)
                mesh.TexCoord(1, uvx1, uvy2)  
                mesh.Color(255, 255, 255, color2)
                mesh.Normal(-normal1)
                mesh.AdvanceVertex()

                mesh.Position(vertexPos3)
                mesh.TexCoord(0, 0, 1)
                mesh.TexCoord(1, uvx2, uvy1)  
                mesh.Color(255, 255, 255, color3)
                mesh.Normal(-normal1)
                mesh.AdvanceVertex()

                -- second tri
                mesh.Position(vertexPos3)
                mesh.TexCoord(0, 0, 1)
                mesh.TexCoord(1, uvx2, uvy1)  
                mesh.Color(255, 255, 255, color3)
                mesh.Normal(-normal2)
                mesh.AdvanceVertex()

                mesh.Position(vertexPos2)
                mesh.TexCoord(0, 1, 0)
                mesh.TexCoord(1, uvx1, uvy2) 
                mesh.Color(255, 255, 255, color2)
                mesh.Normal(-normal2)
                mesh.AdvanceVertex()

                mesh.Position(vertexPos4)
                mesh.TexCoord(0, 1, 1)
                mesh.TexCoord(1, uvx2, uvy2) 
                mesh.Color(255, 255, 255, color4)
                mesh.Normal(-normal2)
                mesh.AdvanceVertex()
            end
        end
    end)
    mesh.End()

    if !err then print(msg) end  -- if there is an error, catch it and throw it outside of mesh.begin since you crash if mesh.end is not called
end

local grassAmount = 104
function ENT:GenerateGrass()
    self.GrassMesh = Mesh()
    if self:GetOverhang() or !Terrain.MathFuncVariables.generateGrass then return end
    local grassSize = Terrain.MathFuncVariables.grassSize

    local mesh = mesh
    local err, msg
    local chunkIndex = tostring(self:GetChunkX()) .. tostring(self:GetChunkY())
    local randomIndex = 0
    mesh.Begin(self.GrassMesh, MATERIAL_TRIANGLES, grassAmount^2)
    err, msg = pcall(function()
        for y = 0, grassAmount - 1 do
            for x = 0, grassAmount - 1 do
                randomIndex = randomIndex + 1
                local mult = Terrain.ChunkResolution / grassAmount
                local x = x * mult
                local y = y * mult
                local randoffsetx = util.SharedRandom("TerrainGrassX" .. chunkIndex, 0, 1, randomIndex) * mult
                local randoffsety = util.SharedRandom("TerrainGrassY" .. chunkIndex, 0, 1, randomIndex) * mult
                
                -- chunk offset in world space
                local chunkoffsetx = self:GetChunkX() * Terrain.ChunkResScale   -- Terrain.ChunkSize * Terrain.ChunkResolution
                local chunkoffsety = self:GetChunkY() * Terrain.ChunkResScale

                -- vertex of the triangle in the chunks local space
                local worldx = (x + randoffsetx) * Terrain.ChunkSize
                local worldy = (y + randoffsety) * Terrain.ChunkSize

                -- the height of the vertex using the math function
                local vertexHeight = Terrain.MathFunc(worldx + chunkoffsetx, worldy + chunkoffsety, self) 
                local mainPos = Vector(chunkoffsetx + worldx, chunkoffsety + worldy, vertexHeight + Terrain.ZOffset)

                local randbrushx = math.floor(((randoffsetx * 9999) % 1) * 3) * 0.3 
                local randbrushy = math.floor(((randoffsety * 9999) % 1) * 3) * 0.3 
                local offsetx = randbrushx - 0.1
                local offsety = 0.5 - randbrushy
                local randdir = Angle(0, randoffsetx * 9999, 0)

                mesh.TexCoord(0, offsetx, 0.3 + offsety)
                mesh.Position(mainPos - randdir:Right() * grassSize)
                mesh.Color(200, 255, 200, 200)
                mesh.AdvanceVertex()

                mesh.TexCoord(0, 0.3 + offsetx, 0.3 + offsety)
                mesh.Position(mainPos + randdir:Right() * grassSize)
                mesh.Color(200, 255, 200, 255)
                mesh.AdvanceVertex()

                mesh.TexCoord(0, 0.3 + offsetx, offsety)
                mesh.Position(mainPos + (randdir:Right() + randdir:Up() * 2) * grassSize)
                mesh.Color(200, 255, 200, 255)
                mesh.AdvanceVertex()
            end
        end
    end)
    mesh.End()

    if !err then print(msg) end
end

-- get the height of the terrain at a given point with given offset
local function getChunkOffset(x, y, offsetx, offsety, chunk, heightFunction)
	local cs = Terrain.ChunkSize
	local ox, oy = x * cs, y * cs
	return Vector(ox, oy, heightFunction(ox + offsetx, oy + offsety, chunk))
end

-- create the collision mesh for the chunk, runs on server & client
function ENT:BuildCollision(heightFunction)
    local heightFunction = heightFunction or Terrain.MathFunc

	local finalMesh = {}
	for y = 1, Terrain.ChunkResolution do 
		for x = 1, Terrain.ChunkResolution do
			local offsetx = self:GetChunkX() * Terrain.ChunkResScale
			local offsety = self:GetChunkY() * Terrain.ChunkResScale

			local p1 = getChunkOffset(x, y, offsetx, offsety, self, heightFunction)
			local p2 = getChunkOffset(x - 1, y, offsetx, offsety, self, heightFunction)
			local p3 = getChunkOffset(x, y - 1, offsetx, offsety, self, heightFunction)
			local p4 = getChunkOffset(x - 1, y - 1, offsetx, offsety, self, heightFunction)
			
			table.Add(finalMesh, {
				{pos = p1},
				{pos = p2},
				{pos = p3}
			})

			table.Add(finalMesh, {
				{pos = p2},
				{pos = p3},
				{pos = p4}
			})
		end 
	end
    self:PhysicsDestroy()
	self:PhysicsFromMesh(finalMesh)

    if CLIENT then 
        self:SetRenderBounds(self:OBBMins(), self:OBBMaxs() + Vector(0, 0, 1000)) -- add 1000 units for trees
    end 
end


function ENT:Initialize()
    self:SetModel("models/props_c17/FurnitureCouch002a.mdl")
    self:BuildCollision()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:PhysWake()
    self:GetPhysicsObject():EnableMotion(false)
    self:GetPhysicsObject():SetMass(50000)  -- max weight, should help a bit with the physics solver
    self:GetPhysicsObject():SetPos(self:GetPos())
    self:DrawShadow(false)

    if SERVER then return end

    self.OffsetMatrix = Matrix()
	self.OffsetMatrix:SetTranslation(self:GetPos())
	self.OffsetMatrix:SetScale(Vector(1, 1, 1))
    self:GenerateMesh()
    self:GenerateTrees()
    self:GenerateGrass()

    -- if its the last chunk, generate the lightmap
    if self:GetChunkX() == -Terrain.Resolution and self:GetChunkY() == -Terrain.Resolution then
        Terrain.GenerateLightmap(1024)
    end
end

-- it has to be transmitted to the client always because its like, the world
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:CanProperty(ply, property)
	return false
end

hook.Add("CanDrive", "terrain_stopdrive", function(ply, ent)
    if ent:GetClass() == "terrain_chunk" then return false end
end)

-- disable physgun pickup because that would be cancer
hook.Add("PhysgunPickup", "Terrain_DisablePhysgun", function(ply, ent)
	if ent and ent:GetClass() == "terrain_chunk" then
		return false
	end
end)

function ENT:OnRemove()
    if self.RenderMesh and self.RenderMesh:IsValid() then
        self.RenderMesh:Destroy()
    end

    if self.GrassMesh and self.GrassMesh:IsValid() then
        self.GrassMesh:Destroy()
    end
end

-- drawing, no server here
if SERVER then return end

local lm = Terrain.Lightmap
local treeMaterial = Material("models/props_foliage/arbre01")   --models/props_foliage/arbre01
local rockMaterial = Material("models/props_foliage/coastrock02")
local detailMaterial = Material("detail/detailsprites")  -- detail/detailsprites models/props_combine/combine_interface_disp
waterMaterial = Material("models/shadertest/shader3")
//waterMaterial:SetString("$reflecttexture", "_rt_waterreflection")
//waterMaterial:SetString("$refracttexture", "_rt_waterrefraction")

-- cache ALL of these for faster lookup
local renderTable = {Material = Terrain.Material}
local render_SetLightmapTexture = render.SetLightmapTexture
local render_SetMaterial = render.SetMaterial
local render_SetModelLighting = render.SetModelLighting
local render_SetLocalModelLights = render.SetLocalModelLights
local cam_PushModelMatrix = cam.PushModelMatrix
local cam_PopModelMatrix = cam.PopModelMatrix
local math_DistanceSqr = math.DistanceSqr
local math_Distance = math.Distance
local treeMeshes = {}
local low_treeMeshes = {}

-- build and cache tree models
for k, treeModel in ipairs(Terrain.TreeModels) do
    treeMeshes[k] = Mesh()
    treeMeshes[k]:BuildFromTriangles(util.GetModelMeshes(treeModel)[1].triangles)

    low_treeMeshes[k] = Mesh()
    low_treeMeshes[k]:BuildFromTriangles(util.GetModelMeshes(treeModel, 8)[1].triangles)
end

-- this MUST be optimized as much as possible, it is called multiple times every frame
function ENT:GetRenderMesh()
    -- set a lightmap texture to be used instead of the default one
    render_SetLightmapTexture(lm)
    local selfpos = (self:GetPos() + self:OBBCenter())
    local eyepos = EyePos()

    -- get local vars
    local lod = math_DistanceSqr(selfpos[1], selfpos[2], eyepos[1], eyepos[2]) < Terrain.LODDistance
    local models = self.TreeModels
    local lighting = self.TreeShading
    local flashlightOn = LocalPlayer():FlashlightIsOn()

    -- reset lighting
    render_SetLocalModelLights()
    render_SetModelLighting(1, 0.1, 0.1, 0.1)
    render_SetModelLighting(3, 0.1, 0.1, 0.1)
    render_SetModelLighting(5, 0.1, 0.1, 0.1)

    -- render foliage
    if lod then -- chunk is near us, render high quality foliage

        -- render grasses if chunks are near
        if self.GrassMesh then 
            render_SetMaterial(detailMaterial)
            self.GrassMesh:Draw()
        end

        local lastlight
        local lastmat
        for k, matrix in ipairs(self.TreeMatrices) do
            local modelID = models[k]
            if modelID != lastmat then
                render_SetMaterial(modelID < 5 and treeMaterial or rockMaterial)
                lastmat = modelID
            end

            -- give the tree its shading
            local light = lighting[k]
            if light != lastlight then
                render_SetModelLighting(0, light, light, light)
                render_SetModelLighting(2, light, light, light)
                render_SetModelLighting(4, light, light, light)
                lastlight = light
            end

            -- push custom matrix generated earlier and render the tree
            cam_PushModelMatrix(matrix)
                treeMeshes[modelID]:Draw()
                if flashlightOn then   -- flashlight compatability
                    render.PushFlashlightMode(true)
                    treeMeshes[modelID]:Draw()
                    render.PopFlashlightMode()
                end
            cam_PopModelMatrix()
        end
    else -- chunk is far, render low definition
        local lastlight
        local lastmat
        for k, matrix in ipairs(self.TreeMatrices) do
            local modelID = models[k]
            if modelID != lastmat then
                render_SetMaterial(modelID < 5 and treeMaterial or rockMaterial)
                lastmat = modelID
            end

            -- give the tree its shading
            local light = lighting[k]
            if light != lastLight then
                render_SetModelLighting(0, light, light, light)
                render_SetModelLighting(2, light, light, light)
                render_SetModelLighting(4, light, light, light)
                lastLight = light
            end

            -- push custom matrix generated earlier and render the tree
            cam_PushModelMatrix(matrix)
                low_treeMeshes[modelID]:Draw()
            cam_PopModelMatrix()
        end
    end

    render_SetMaterial(waterMaterial)
    local sc = Terrain.ChunkResScale * 0.5
    render.DrawQuadEasy(Vector(self:GetPos()[1] + sc, self:GetPos()[2] + sc, -12000), Vector(0, 0, 1), sc * 2, sc * 2)
    render.DrawQuadEasy(Vector(self:GetPos()[1] + sc, self:GetPos()[2] + sc, -12000), Vector(0, 0, -1), sc * 2, sc * 2)

    -- render the chunk mesh itself
    renderTable.Mesh = self.RenderMesh
    return renderTable
end



