
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
    //Terrain.Material = Material("nature/blendrocksgrass006a")
    Terrain.Material = CreateMaterial("NatureblendTerrain01", "WorldVertexTransition", {
        ["$basetexture"] = "nature/rockfloor005a",
	    ["$surfaceprop"] = "rock",
	    ["$basetexture2"] = "gm_construct/grass1",
	    ["$surfaceprop2"] = "dirt",
        ["$seamless_scale"] = 0.002,
        ["$nocull"] = 1,
    })
end

function ENT:GetTreeData(pos, data, heightFunction)
    local heightFunction = heightFunction or Terrain.MathFunc

    // pos is local to chunk
    local x = pos[1]
    local y = pos[2]

    // chunk offset in world space
    local chunkoffsetx = self:GetChunkX() * Terrain.ChunkResScale
    local chunkoffsety = self:GetChunkY() * Terrain.ChunkResScale

    // no trees in spawn area (1000x1000 hu square)
    if data.spawnArea and math.abs(x + chunkoffsetx) < 1500 and math.abs(y + chunkoffsety) < 1500 then return nil end

    // the height of the vertex using the math function
    local vertexHeight = heightFunction(x + chunkoffsetx, y + chunkoffsety, self)
    local middleHeight = Vector(0, 0, vertexHeight)

    local finalPos = Vector(x + chunkoffsetx, y + chunkoffsety, vertexHeight + Terrain.ZOffset - 25.6 * data.treeHeight) // pushed down 25.6 units, (height of the base of the tree model)
    if data.waterHeight and finalPos[3] < data.waterHeight then return nil end

    // calculate the smoothed normal, if it is extreme, do not place a tree
    local smoothedNormal = Vector()
    for cornery = 0, 1 do
        for cornerx = 0, 1 do
            // get 4 corners in a for loop ranging from -1 to 1
            local cornerx = (cornerx - 0.5) * 2
            local cornery = (cornery - 0.5) * 2

            // get the height of the 0x triangle
            local cornerWorldy = (y + cornery)
            local cornerHeight = heightFunction(x + chunkoffsetx, cornerWorldy + chunkoffsety, self)
            local middleXPosition = Vector(0, cornery, cornerHeight)

            // get the height of the 0y triangle
            local cornerWorldx = (x + cornerx)
            local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, y + chunkoffsety, self)
            local middleYPosition = Vector(cornerx, 0, cornerHeight)
            
            // we now have 3 points, construct a triangle from this and add the normal to the average normal
            local triNormal = (middleYPosition - middleHeight):Cross(middleXPosition - middleHeight) * cornerx * cornery
            smoothedNormal = smoothedNormal + triNormal
        end
    end

    smoothedNormal = smoothedNormal:GetNormalized()
    if smoothedNormal[3] < data.treeThreshold then return nil end    // remove trees on extreme slopes

    return finalPos, smoothedNormal
end

function ENT:GenerateTrees(heightFunction, data)
    local data = data or Terrain.Variables
    local heightFunction = heightFunction or Terrain.MathFunc
    local treeResolution = data.treeResolution or Terrain.Variables.treeResolution

    self.TreeMatrices = {}
    self.TreeModels = {}
    self.TreeShading = {}

    if self:GetOverhang() then return end
    local treeMultiplier = Terrain.ChunkResolution / data.treeResolution * Terrain.ChunkSize
    local randomIndex = 0
    local chunkIndex = tostring(self:GetChunkX()) .. tostring(self:GetChunkY())
    for y = 0, data.treeResolution - 1 do
        for x = 0, data.treeResolution - 1 do
            randomIndex = randomIndex + 1
            local m = Matrix()

            // generate seeded random position for tree
            local randseedx = util.SharedRandom("TerrainSeedX" .. chunkIndex, 0, 1, randomIndex)
            local randseedy = util.SharedRandom("TerrainSeedY" .. chunkIndex, 0, 1, randomIndex)
            local randPos = Vector(randseedx, randseedy) * data.treeResolution * treeMultiplier

            local finalPos, smoothedNormal = self:GetTreeData(randPos, data, heightFunction)
            if !finalPos then continue end

            m:SetTranslation(finalPos)
            m:SetAngles(Angle(0, randseedx * 3600, 0))//smoothedNormal:Angle() + Angle(90, 0, 0) Angle(0, randseedx * 3600, 0)
            m:SetScale(Vector(1, 1, 1) * data.treeHeight)
            finalPos[3] = finalPos[3] + 256 * data.treeHeight  // add tree height
            table.insert(self.TreeMatrices, m)
            table.insert(self.TreeModels, math.floor(util.SharedRandom("TerrainModel" .. chunkIndex, 0, #Terrain.TreeModels - 0.9, randomIndex)) + 1)  // 4.1 means 1/50 chance for a rock to generate instead of a tree
            table.insert(self.TreeShading, util.TraceLine({start = finalPos, endpos = finalPos + Terrain.SunDir * 99999}).HitSky and 1.5 or 0.5)
        end
    end
end

function ENT:GenerateMesh(heightFunction)
    local heightFunction = heightFunction or Terrain.MathFunc
    // generate a mesh for the chunk using the mesh library
    self.RenderMesh = Mesh(Terrain.Material)
    local mesh = mesh   // local lookup is faster than global
    local err, msg
    local function smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos)
        local unwrappedPos = vertexPos / Terrain.ChunkSize
        local smoothedNormal = Vector()
        for cornery = 0, 1 do
            for cornerx = 0, 1 do
                // get 4 corners in a for loop ranging from -1 to 1
                local cornerx = (cornerx - 0.5) * 2
                local cornery = (cornery - 0.5) * 2

                // get the height of the 0x triangle
                local cornerWorldx = vertexPos[1]
                local cornerWorldy = (unwrappedPos[2] + cornery) * Terrain.ChunkSize
                local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, cornerWorldy + chunkoffsety, self)
                local middleXPosition = Vector(0, Terrain.ChunkSize * cornery, cornerHeight)

                // get the height of the 0y triangle
                local cornerWorldx = (unwrappedPos[1] + cornerx) * Terrain.ChunkSize
                local cornerWorldy = vertexPos[2]
                local cornerHeight = heightFunction(cornerWorldx + chunkoffsetx, cornerWorldy + chunkoffsety, self)
                local middleYPosition = Vector(Terrain.ChunkSize * cornerx, 0, cornerHeight)

                // we now have 3 points, construct a triangle from this and add the normal to the average normal
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
                // chunk offset in world space
                local chunkoffsetx = self:GetChunkX() * Terrain.ChunkResScale   // Terrain.ChunkSize * Terrain.ChunkResolution
                local chunkoffsety = self:GetChunkY() * Terrain.ChunkResScale

                // vertex of the triangle in the chunks local space
                local worldx1 = x * Terrain.ChunkSize
                local worldy1 = y * Terrain.ChunkSize
                local worldx2 = (x + 1) * Terrain.ChunkSize
                local worldy2 = (y + 1) * Terrain.ChunkSize

                // the height of the vertex using the math function
                local vertexHeight1 = heightFunction(worldx1 + chunkoffsetx, worldy1 + chunkoffsety, self)
                local vertexHeight2 = heightFunction(worldx1 + chunkoffsetx, worldy2 + chunkoffsety, self)
                local vertexHeight3 = heightFunction(worldx2 + chunkoffsetx, worldy1 + chunkoffsety, self)
                local vertexHeight4 = heightFunction(worldx2 + chunkoffsetx, worldy2 + chunkoffsety, self)

                // vertex positions in local space
                local vertexPos1 = Vector(worldx1, worldy1, vertexHeight1)
                local vertexPos2 = Vector(worldx1, worldy2, vertexHeight2)
                local vertexPos3 = Vector(worldx2, worldy1, vertexHeight3)
                local vertexPos4 = Vector(worldx2, worldy2, vertexHeight4)

                // lightmap uv calculation, needs to spread over whole terrain or it looks weird
                // since chunks range into negative numbers we need to adhere to that
                local r = Terrain.Resolution
                local uvx1 = ((self:GetChunkX() + r) / r + (x / Terrain.ChunkResolution / r)) * 0.5
                local uvy1 = ((self:GetChunkY() + r) / r + (y / Terrain.ChunkResolution / r)) * 0.5
                local uvx2 = ((self:GetChunkX() + r) / r + ((x + 1) / Terrain.ChunkResolution / r)) * 0.5
                local uvy2 = ((self:GetChunkY() + r) / r + ((y + 1) / Terrain.ChunkResolution / r)) * 0.5

                
                local normal1 = (vertexPos1 - vertexPos2):Cross(vertexPos1 - vertexPos3):GetNormalized()
                local normal2 = (vertexPos4 - vertexPos3):Cross(vertexPos4 - vertexPos2):GetNormalized()

                local smoothedNormal1 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos1)
                local smoothedNormal2 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos2)
                local smoothedNormal3 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos3)
                local smoothedNormal4 = smoothedNormal(chunkoffsetx, chunkoffsety, vertexPos4)

                local waterHeight = Terrain.Variables.waterHeight or -math.huge
                local rock1 = (vertexHeight1 + Terrain.ZOffset < waterHeight) and 0.3 or smoothedNormal1[3]
                local rock2 = (vertexHeight2 + Terrain.ZOffset < waterHeight) and 0.3 or smoothedNormal2[3]
                local rock3 = (vertexHeight3 + Terrain.ZOffset < waterHeight) and 0.3 or smoothedNormal3[3]
                local rock4 = (vertexHeight4 + Terrain.ZOffset < waterHeight) and 0.3 or smoothedNormal4[3]

                local color1 = math.Min(rock1 * 512, 255)
                local color2 = math.Min(rock2 * 512, 255)
                local color3 = math.Min(rock3 * 512, 255)
                local color4 = math.Min(rock4 * 512, 255)

                // first tri
                mesh.Position(vertexPos1)
                mesh.TexCoord(0, 0, 0)        // texture UV
                mesh.TexCoord(1, uvx1, uvy1)  // lightmap UV
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

                // second tri
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

    if !err then print(msg) end  // if there is an error, catch it and throw it outside of mesh.begin since you crash if mesh.end is not called
end

local grassAmount = 104
function ENT:GenerateGrass()
    self.GrassMesh = Mesh()
    if self:GetOverhang() or !Terrain.Variables.generateGrass then return end
    local grassSize = Terrain.Variables.grassSize

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
                
                // chunk offset in world space
                local chunkoffsetx = self:GetChunkX() * Terrain.ChunkResScale   // Terrain.ChunkSize * Terrain.ChunkResolution
                local chunkoffsety = self:GetChunkY() * Terrain.ChunkResScale

                // vertex of the triangle in the chunks local space
                local worldx = (x + randoffsetx) * Terrain.ChunkSize
                local worldy = (y + randoffsety) * Terrain.ChunkSize

                // the height of the vertex using the math function
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

// get the height of the terrain at a given point with given offset
local function getChunkOffset(x, y, offsetx, offsety, chunk, heightFunction)
	local cs = Terrain.ChunkSize
	local ox, oy = x * cs, y * cs
	return Vector(ox, oy, heightFunction(ox + offsetx, oy + offsety, chunk))
end

// create the collision mesh for the chunk, runs on server & client
function ENT:BuildCollision(heightFunction)
    local heightFunction = heightFunction or Terrain.MathFunc

    // main base terrain
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

    // tree collision
    if !self:GetOverhang() then 
        local data = Terrain.Variables
        data.treeMultiplier = Terrain.ChunkResolution / data.treeResolution * Terrain.ChunkSize
        local randomIndex = 0
        local chunkIndex = tostring(self:GetChunkX()) .. tostring(self:GetChunkY())
        for y = 0, data.treeResolution - 1 do
            for x = 0, data.treeResolution - 1 do
                randomIndex = randomIndex + 1

                // generate seeded random position for tree
                local randseedx = util.SharedRandom("TerrainSeedX" .. chunkIndex, 0, 1, randomIndex)
                local randseedy = util.SharedRandom("TerrainSeedY" .. chunkIndex, 0, 1, randomIndex)
                local randPos = Vector(randseedx, randseedy) * data.treeResolution * data.treeMultiplier

                local finalPos = self:GetTreeData(randPos, data, heightFunction)
                if !finalPos then continue end

                local treeIndex = math.floor(util.SharedRandom("TerrainModel" .. chunkIndex, 0, #Terrain.TreeModels - 0.9, randomIndex)) + 1
                local treeMesh = {}
                for k, v in ipairs(Terrain.TreePhysMeshes[treeIndex]) do
                    local rotatedPos = Vector(v.pos[1], v.pos[2], v.pos[3])
                    rotatedPos:Rotate(Angle(0, randseedx * 3600, 0))
                    treeMesh[k] = {pos = (rotatedPos * data.treeHeight + finalPos) - self:GetPos()}
                end

                table.Add(finalMesh, treeMesh)
            end
        end
    end

    self:PhysicsDestroy()
	self:PhysicsFromMesh(finalMesh)

    if CLIENT then 
        self:SetRenderBounds(self:OBBMins(), self:OBBMaxs() + Vector(0, 0, 1000)) // add 1000 units for trees
    end 
end


function ENT:Initialize()
    if CLIENT then
        self.OffsetMatrix = Matrix()
        self.OffsetMatrix:SetTranslation(self:GetPos())
        self.OffsetMatrix:SetScale(Vector(1, 1, 1))
        self:GenerateMesh()
        self:GenerateTrees()
        self:GenerateGrass()

        // if its the last chunk, generate the lightmap
        if self:GetChunkX() == -Terrain.Resolution and self:GetChunkY() == -Terrain.Resolution then
            Terrain.GenerateLightmap(1024)
        end
    end

    self:SetModel("models/props_c17/FurnitureCouch002a.mdl")
    self:BuildCollision()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:PhysWake()
    self:GetPhysicsObject():EnableMotion(false)
    self:GetPhysicsObject():SetMass(50000)  // max weight, should help a bit with the physics solver
    self:GetPhysicsObject():SetPos(self:GetPos())
    self:DrawShadow(false)
end

// it has to be transmitted to the client always because its like, the world
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:CanProperty(ply, property)
	return false
end

hook.Add("CanDrive", "terrain_stopdrive", function(ply, ent)
    if ent:GetClass() == "terrain_chunk" then return false end
end)

// disable physgun pickup because that would be cancer
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

// drawing, no server here
if SERVER then return end

local lm = Terrain.Lightmap
local treeMaterial = Material("models/props_foliage/arbre01")   //models/props_foliage/arbre01
local rockMaterial = Material("models/props_foliage/coastrock02")
local detailMaterial = Material("detail/detailsprites")  // detail/detailsprites models/props_combine/combine_interface_disp
//local waterMaterial = Material("effects/water_warp")
local waterMaterial = CreateMaterial("Terrain_Water01", "Refract", {
    ["$alpha"]                  	=	1,
    ["$bumpframe"]              	=	55,
    ["$bumpmap"]	                =	"dev/water_dudv",
    ["$color"]                     	=	"[1 1 1]",
    ["$color2"]                 	=	"[1 1 1]",
    ["$envmapsaturation"]	        =	1,
    ["$envmaptint"]             	=	"[1 1 1]",
    ["$fresnelreflection"]      	=   1,
    ["$localrefractdepth"]         	=   0.05,
    //["$normalmap"]              	=   Texture [water/tfwater001_normal]
    ["$refractamount"]          	=   0.05,
    ["$refractblur"]            	=   1,
    ["$refracttint"]            	=   "[0.618686 0.7593 1]",
    ["$scale"]                  	=   "[1 1 0]",
    ["$srgbtint"]	                =   "[1 1 1]",
    ["$model"]                      =   1,  

    ["$treesway"]                   =   1,
    ["$treeswayheight"]             =   1000,
    ["$treeswaystartheight"]        =   0,
    ["$treeswayradius"]             =   1000,
    ["$treeswaystartradius"]        =   0,
    ["$treeswayscrumblespeed"]      =   200,
    ["$treeswayscrumblestrength"]   =   200,
    ["$treeswayscrumblefrequency"]  =   400,
    ["$treeswayfalloffexp"]         =   1000,
    ["$treeswayspeed"]              =   1000,
    ["$treeswayscrumblefalloffexp"] =   1,

})

// cache ALL of these for faster lookup
local renderTable = {Material = Terrain.Material}
local render_SetLightmapTexture = render.SetLightmapTexture
local render_SetMaterial = render.SetMaterial
local render_SetModelLighting = render.SetModelLighting
local render_SetLocalModelLights = render.SetLocalModelLights
local cam_PushModelMatrix = cam.PushModelMatrix
local cam_PopModelMatrix = cam.PopModelMatrix
local math_DistanceSqr = math.DistanceSqr
local math_Distance = math.Distance

// this MUST be optimized as much as possible, it is called multiple times every frame
function ENT:GetRenderMesh()
    // set a lightmap texture to be used instead of the default one
    render_SetLightmapTexture(lm)
    local selfpos = (self:GetPos() + self:OBBCenter())
    local eyepos = EyePos()

    // get local vars
    local lod = math_DistanceSqr(selfpos[1], selfpos[2], eyepos[1], eyepos[2]) < Terrain.LODDistance
    local models = self.TreeModels
    local lighting = self.TreeShading
    local materials = Terrain.TreeMaterials
    local flashlightOn = LocalPlayer():FlashlightIsOn()

    // reset lighting
    render_SetLocalModelLights()
    render_SetModelLighting(1, 0.1, 0.1, 0.1)
    render_SetModelLighting(3, 0.1, 0.1, 0.1)
    render_SetModelLighting(5, 0.1, 0.1, 0.1)

    // render foliage
    if lod then // chunk is near us, render high quality foliage
        // render grasses if chunks are near
        if self.GrassMesh then 
            render_SetMaterial(detailMaterial)
            self.GrassMesh:Draw()
        end

        local lastlight
        local lastmat
        for k, matrix in ipairs(self.TreeMatrices) do
            local modelID = models[k]
            if lastmat != modelID then
                if k == 1 or lastmat == 5 or modelID == 5 then
                    render_SetMaterial(materials[modelID])
                end
                lastmat = modelID
            end

            // give the tree its shading
            local light = lighting[k]
            if light != lastlight then
                render_SetModelLighting(0, light, light, light)
                render_SetModelLighting(2, light, light, light)
                render_SetModelLighting(4, light, light, light)
                lastlight = light
            end

            // push custom matrix generated earlier and render the tree
            cam_PushModelMatrix(matrix)
                Terrain.TreeMeshes[modelID]:Draw()
                if flashlightOn then   // flashlight compatability
                    render.PushFlashlightMode(true)
                    Terrain.TreeMeshes[modelID]:Draw()
                    render.PopFlashlightMode()
                end
            cam_PopModelMatrix()
        end
    else // chunk is far, render low definition
        local lastlight
        local lastmat
        for k, matrix in ipairs(self.TreeMatrices) do
            local modelID = models[k]
            if lastmat != modelID then
                if k == 1 or lastmat == 5 or modelID == 5 then
                    render_SetMaterial(materials[modelID])
                end
                lastmat = modelID
            end

            // give the tree its shading
            local light = lighting[k]
            if light != lastlight then
                render_SetModelLighting(0, light, light, light)
                render_SetModelLighting(2, light, light, light)
                render_SetModelLighting(4, light, light, light)
                lastlight = light
            end

            // push custom matrix generated earlier and render the tree
            cam_PushModelMatrix(matrix)
                Terrain.TreeMeshes_Low[modelID]:Draw()
            cam_PopModelMatrix()
        end
    end

    // render the chunk mesh itself
    renderTable.Mesh = self.RenderMesh
    return renderTable
end

local uvscale = 100
local waterMesh = Mesh()
waterMesh:BuildFromTriangles({
    {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
    {pos = Vector(1, 1, 0), u = uvscale, v = 0},
    {pos = Vector(1, -1, 0), u = uvscale, v = uvscale},

    {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
    {pos = Vector(-1, 1, 0), u = 0, v = 0},
    {pos = Vector(1, 1, 0), u = uvscale, v = 0},

    {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
    {pos = Vector(1, -1, 0), u = uvscale, v = uvscale},
    {pos = Vector(1, 1, 0), u = uvscale, v = 0},

    {pos = Vector(-1, -1, 0), u = 0, v = uvscale},
    {pos = Vector(1, 1, 0), u = uvscale, v = 0},
    {pos = Vector(-1, 1, 0), u = 0, v = 0},
})

// todo: optimize water & use imported material instead of relying on TF2
local waterMatrix = Matrix()
waterMatrix:SetScale(Vector(Terrain.ChunkResScale * Terrain.Resolution, Terrain.ChunkResScale * Terrain.Resolution))

hook.Add("PreDrawTranslucentRenderables", "Terrain_Water", function(_, sky)
    if sky then return end
    local waterHeight = Terrain.Variables.temp_waterHeight or Terrain.Variables.waterHeight
    if waterHeight then
        waterMaterial:SetTexture("$normalmap", "water/tfwater001_normal")
        waterMatrix:SetTranslation(Vector(0, 0, waterHeight))
        render_SetMaterial(waterMaterial)
        cam_PushModelMatrix(waterMatrix)
            waterMesh:Draw()
        cam_PopModelMatrix()
    end
end)
hook.Remove("PostDrawTranslucentRenderables", "Terrain_Water")
