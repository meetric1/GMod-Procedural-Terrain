AddCSLuaFile()

if game.GetMap() != "gm_flatgrass" then return end

Terrain = Terrain or {}
Terrain.ChunkSize = 256
Terrain.Resolution = 3
Terrain.ChunkResolution = 20
Terrain.TreeResolution = 10
Terrain.TreeHeight = 2
Terrain.TreeThreshold = 0.35
Terrain.LightmapRes = 1024
Terrain.ChunkResScale = Terrain.ChunkSize * Terrain.ChunkResolution
Terrain.Chunks = Terrain.Chunks or {}
Terrain.Simplex = include("perlin.lua")
Terrain.LODDistance = 5000^2
Terrain.ZOffset = -12770
Terrain.SunDir = Vector(0.414519, 0.279596, 0.866025)	--default flatgrass sun direction
Terrain.MathFuncVariables = {
	height = 50,	-- height multiplier
	noiseScale = 3,	
	offset = 0,		-- z offset
	seed = 0,		
	treeHeight = Terrain.TreeHeight,
	treeResolution = Terrain.TreeResolution,
	treeThreshold = Terrain.TreeThreshold,
	clampNoise = true,	-- noise 0-1 or -1-1
	customFunction = nil,	-- custom function to use, nil by default (not actually added to table, only here for visualization)
	spawnArea = true,	-- give the flatgrass building space or not
	generateGrass = true,
	grassSize = 25,
}

local invMagicNumber = 1 / 2048
Terrain.AllowedLibraries = {
	math = math,
	bit = bit, 
	Simplex = Terrain.Simplex,
}

for k, v in pairs(math) do
	Terrain.AllowedLibraries[k] = v
end

-- The main function that defines the height for a given point
function Terrain.BuildMathFunc(values)
	values = values or Terrain.MathFuncVariables
	if values.customFunction then
		local generatedFunction = setfenv(CompileString("local x, y, chunk = ...\n" .. values.customFunction, "Terrain Function"), Terrain.AllowedLibraries)
		return function(x, y, chunk) 
			local x = x * invMagicNumber
			local y = y * invMagicNumber

			local final = generatedFunction(x, y, chunk) or 0

			-- finalize the value
			if values.spawnArea then final = ((math.abs(x) < 0.7 and math.abs(y) < 0.7) and 0 or final) end	--spawn region gets space
			final = math.Clamp(final, 0, 100)
			return final * 256
		end
	end

	local randomNum = 498.570948	-- for seed
	return function(x, y, chunk)
		local x = x * invMagicNumber
		local y = y * invMagicNumber

		x = x + (values.seed * randomNum)
		local final = Terrain.Simplex.Noise2D(x / values.noiseScale, y / values.noiseScale)
		if values.clampNoise then final = math.Max(final, 0) end
		x = x - (values.seed * randomNum)

		final = final * values.height
		final = final + values.offset
	
		-- finalize the value
		if values.spawnArea then final = ((math.abs(x) < 0.7 and math.abs(y) < 0.7) and 0 or final) end	--spawn region gets space
		final = math.Clamp(final, 0, 100)
		return (chunk and chunk:GetOverhang()) and (100 - final) * 256 or final * 256	     -- cave support
	end
end

Terrain.MathFunc = Terrain.BuildMathFunc()

if SERVER then return end

Terrain.Lightmap = GetRenderTarget("Terrain_Lightmap", Terrain.LightmapRes, Terrain.LightmapRes)
render.ClearRenderTarget(Terrain.Lightmap, Color(127, 127, 127, 255))

local function intersectRayWithTriangle(rayOrigin, rayDir, tri1, tri2, tri3)
	local point1 = tri1
	local edge1 = tri2 - point1
	local edge2 = tri3 - point1
	local h = rayDir:Cross(edge2)
	local a = edge1:Dot(h)
	if a > 0 then
		return nil     // This ray is parallel to this triangle.
	end
	
	local f = 1 / a
	local s = rayOrigin - point1
	local u = f * s:Dot(h)

	if u < 0 || u > 1 then
		return nil
	end
	
	local q = s:Cross(edge1)
	local v = f * rayDir:Dot(q)
	if v < 0 || u + v > 1 then
		return nil
	end
	
	// At this stage we can compute t to find out where the intersection point is on the line.
	local t = f * edge2:Dot(q)
	if (t > 0) then // ray intersection
		return rayOrigin + rayDir * t;
	end
	
	return nil
end

local function generateLightmap(res, heightFunction)
	local surface_SetDrawColor = surface.SetDrawColor	-- faster lookup
	local surface_DrawRect = surface.DrawRect
	local globalTerrainScale = Terrain.ChunkResScale * Terrain.Resolution
	local util_TraceLine = util.TraceLine
	local lightmapMultiplier = Terrain.LightmapRes / res
	local function getHeight(x, y)
		return Vector(x, y, heightFunction(x, y) + Terrain.ZOffset)
	end
	local function traceFunc(e) return IsValid(e) and e:GetClass() == "terrain_chunk" end
	local res = res - 1
	for y = 0, res do
		render.PushRenderTarget(Terrain.Lightmap)
			cam.Start2D()
				for x = 0, res do
					local worldx = (x / res) * globalTerrainScale
					local worldy = (y / res) * globalTerrainScale
					worldx = worldx * 2 - globalTerrainScale
					worldy = worldy * 2 - globalTerrainScale

					-- for smooth shading
					local worldx2 = (x / (res + 1)) * globalTerrainScale
					local worldy2 = (y / (res + 1)) * globalTerrainScale
					worldx2 = worldx2 * 2 - globalTerrainScale
					worldy2 = worldy2 * 2 - globalTerrainScale
					local dotShading = (getHeight(worldx, worldy) - getHeight(worldx2, worldy)):Cross(getHeight(worldx, worldy) - getHeight(worldx2, worldy2)):GetNormalized():Dot(Terrain.SunDir)	-- smooth shading
					--local dotShading = (tri1[2] - tri1[1]):Cross(tri1[2] - tri1[3]):GetNormalized():Dot(sunDir)	-- flat shading (disabled)

					local shadowAmount = (dotShading + 1.5) * 64
					if dotShading > 0 then	-- if it faces toward the sun
						-- we have mathmatical terrain, however it is not perfectly smooth
						-- the shadow ray may intersect with its own triangle, which is not what we want
						-- we need to do intersections with 2 triangles and find the real height

						-- (we subtract 0.001 incase lerpxbottom and lerpxtop end up to be the same)

						-- find rounded point heights
						local math = math
						local lerpXBottom = math.floor(worldx / Terrain.ChunkSize - 0.001) * Terrain.ChunkSize
						local lerpYBottom = math.floor(worldy / Terrain.ChunkSize - 0.001) * Terrain.ChunkSize
						local lerpXTop	  = math.ceil(worldx / Terrain.ChunkSize) * Terrain.ChunkSize
						local lerpYTop	  = math.ceil(worldy / Terrain.ChunkSize) * Terrain.ChunkSize

						-- find where to cast the shadow ray
						local v = Vector(worldx, worldy, 25601)
						local shadowPos = intersectRayWithTriangle(v, Vector(0, 0, -1), getHeight(lerpXTop, lerpYBottom), getHeight(lerpXBottom, lerpYBottom), getHeight(lerpXBottom, lerpYTop))	-- 25601 = max height
						shadowPos = shadowPos or intersectRayWithTriangle(v, Vector(0, 0, -1), getHeight(lerpXTop, lerpYTop), getHeight(lerpXTop, lerpYBottom), getHeight(lerpXBottom, lerpYTop))
						shadowPos = (shadowPos or Vector(0, 0, 0)) + Vector(0, 0, 1)
						if !util_TraceLine({start = shadowPos, endpos = shadowPos + Terrain.SunDir * 99999, filter = traceFunc}).HitSky then	-- if it hits rock
							shadowAmount = 50
						end
					else	-- sunlight does not hit it because it is angled away from the sun
						shadowAmount = 50
					end

					surface_SetDrawColor(shadowAmount, shadowAmount, shadowAmount, 255)
					surface_DrawRect(x * lightmapMultiplier, y * lightmapMultiplier, lightmapMultiplier, lightmapMultiplier)
				end
			cam.End2D()
		render.PopRenderTarget()
		coroutine.yield()
	end
end

function Terrain.GenerateLightmap(res, heightFunction)
	local co = coroutine.create(function() generateLightmap(res, heightFunction or Terrain.MathFunc) end)

	-- dont run it all at once, it destroys ur game
	hook.Add("Think", "terrain_lightmap_gen", function()
		if coroutine.status(co) != "dead" then
			coroutine.resume(co)
		else
			hook.Remove("Think", "terrain_lightmap_gen")
		end
	end)
end

