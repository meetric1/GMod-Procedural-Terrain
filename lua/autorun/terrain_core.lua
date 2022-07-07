AddCSLuaFile()

if game.GetMap() != "gm_flatgrass" then return end

if SERVER then resource.AddWorkshop("2830138108") end

Terrain = Terrain or {}
Terrain.ChunkSize = 256
Terrain.Resolution = 6
Terrain.ChunkResolution = 10
Terrain.LightmapRes = 1024
Terrain.ChunkResScale = Terrain.ChunkSize * Terrain.ChunkResolution
Terrain.Chunks = Terrain.Chunks or {}
Terrain.Simplex = include("simplex.lua")
Terrain.LODDistance = 5000^2
Terrain.ZOffset = -12770
Terrain.SunDir = Vector(0.414519, 0.279596, 0.866025)	//default flatgrass sun direction
Terrain.Variables = {	// variables that are networked
	height_1 = 50,	// height multiplier
	noiseScale_1 = 20,	
	height_2 = 5,	// height multiplier
	noiseScale_2 = 2,	

	offset = 0,		// z offset
	seed = 21,		
	treeHeight = 2,
	treeResolution = 5,
	treeThreshold = 0.5,
	cave = false,
	waterHeight = -12300,
	clampNoise = true,	// noise 0-1 or -1-1
	customFunction = nil,	// custom function to use, nil by default (not actually added to table, only here for visualization)
	spawnArea = true,	// give the flatgrass building space or not
	generateGrass = true,
	grassSize = 25,
	treeColor = Vector(1, 1, 1),

	material_1 = "gm_construct/grass1",	// terrain main material
	material_2 = "nature/rockfloor005a", // terrain secondary, rock material
	material_3 = "procedural_terrain/water/water_warp", // water material

	water_kill = false,
	water_ignite = false,
	water_viscosity = 1,
	water_buoyancy = 1,
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

// The main function that defines the height for a given point
function Terrain.BuildMathFunc(values)
	values = values or Terrain.Variables
	if values.customFunction then
		local generatedFunction = setfenv(CompileString("local x, y = ...\n" .. values.customFunction, "Terrain Function"), Terrain.AllowedLibraries)
		return function(x, y, flip) 
			local x = x * invMagicNumber
			local y = y * invMagicNumber

			local final = generatedFunction(x, y) or 0

			// finalize the value
			if values.spawnArea then final = ((math.abs(x) < 0.7 and math.abs(y) < 0.7) and 0.05 or final) end	//spawn region gets space
			final = math.Clamp(final, 0, 100)
			return flip and (100 - final) * 256 or final * 256
		end
	end

	local randomNum = 4980.57	// random num for seed
	return function(x, y, flip)
		local x = x * invMagicNumber
		local y = y * invMagicNumber

		x = x + (values.seed * randomNum)

		local final = Terrain.Simplex.Noise2D(x / values.noiseScale_1, y / values.noiseScale_1) * values.height_1
		if values.clampNoise then final = math.Max(final, 0) end
		final = final + Terrain.Simplex.Noise2D(-x / values.noiseScale_2, -y / values.noiseScale_2) * values.height_2
		
		x = x - (values.seed * randomNum)

		final = final + values.offset
	
		// finalize the value
		if values.spawnArea then final = ((math.abs(x) < 0.7 and math.abs(y) < 0.7) and 0.05 or final) end	//spawn region gets space
		final = math.Clamp(final, 0, 100)
		return flip and (100 - final) * 256 or final * 256
	end
end

Terrain.MathFunc = Terrain.BuildMathFunc()

if SERVER then return end

Terrain.Lightmap = GetRenderTarget("Terrain_Lightmap", Terrain.LightmapRes, Terrain.LightmapRes)
render.ClearRenderTarget(Terrain.Lightmap, Color(127, 127, 127, 255))

// stolen tri intersection function lol
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
	local surface_SetDrawColor = surface.SetDrawColor	// faster lookup
	local surface_DrawRect = surface.DrawRect
	local globalTerrainScale = Terrain.ChunkResScale * Terrain.Resolution
	local waterHeight = Terrain.Variables.waterHeight
	local util_TraceLine = util.TraceLine
	local lightmapMultiplier = Terrain.LightmapRes / res
	local math_floor = math.floor
	local math_ceil = math.ceil
	local math_Clamp = math.Clamp
	local function getHeight(x, y)
		return Vector(x, y, heightFunction(x, y) + Terrain.ZOffset)
	end
	local function traceFunc(e) return IsValid(e) and e:GetClass() == "terrain_chunk" end
	local res = res - 1

	local done = 0
	local sizex = ScrW() * 0.5
	local sizey = ScrH() * 0.02
	hook.Add("HUDPaint", "terrain_load", function()
		surface.SetDrawColor(Color(0, 0, 0, 255))
		surface.DrawRect(sizex - 200, sizey - 12.5, 400, 50)
		draw.DrawText("Baking lighting.. " .. math.Round(done / res * 100) .. "% done", "TargetID", sizex, sizey, color_white, TEXT_ALIGN_CENTER)
	end)

	for y = 0, res do
		render.PushRenderTarget(Terrain.Lightmap)
			cam.Start2D()
				done = y
				for x = 0, res do
					local worldx = (x / res) * globalTerrainScale
					local worldy = (y / res) * globalTerrainScale
					worldx = worldx * 2 - globalTerrainScale
					worldy = worldy * 2 - globalTerrainScale

					// for smooth shading
					local worldx2 = (x / (res + 1)) * globalTerrainScale
					local worldy2 = (y / (res + 1)) * globalTerrainScale
					worldx2 = worldx2 * 2 - globalTerrainScale
					worldy2 = worldy2 * 2 - globalTerrainScale
					local triNorm = (getHeight(worldx, worldy) - getHeight(worldx2, worldy)):Cross(getHeight(worldx, worldy) - getHeight(worldx2, worldy2)):GetNormalized()
					local dotShading = triNorm:Dot(Terrain.SunDir)	// smooth shading
					//local dotShading = (tri1[2] - tri1[1]):Cross(tri1[2] - tri1[3]):GetNormalized():Dot(sunDir)	// flat shading (disabled)

					local math = math
					local lerpXBottom = math_floor(worldx / Terrain.ChunkSize - 0.001) * Terrain.ChunkSize
					local lerpYBottom = math_floor(worldy / Terrain.ChunkSize - 0.001) * Terrain.ChunkSize
					local lerpXTop	  = math_ceil(worldx / Terrain.ChunkSize) * Terrain.ChunkSize
					local lerpYTop	  = math_ceil(worldy / Terrain.ChunkSize) * Terrain.ChunkSize

					local corner1 = getHeight(lerpXTop, lerpYTop)
					local corner2 = getHeight(lerpXTop, lerpYBottom)
					local corner3 = getHeight(lerpXBottom, lerpYBottom)
					local corner4 = getHeight(lerpXBottom, lerpYTop)

					local v = Vector(worldx, worldy, 25601)
					local shadowPos = intersectRayWithTriangle(v, Vector(0, 0, -1), corner2, corner3, corner4)	// 25601 = max height
					shadowPos = shadowPos or intersectRayWithTriangle(v, Vector(0, 0, -1), corner1, corner2, corner4)
					shadowPos = (shadowPos or Vector(0, 0, 0)) + Vector(0, 0, 1)// + triNorm * 10

					local shadowAmount = (dotShading + 1.5) * 64
					if dotShading > 0 then	// if it faces toward the sun
						// we have mathmatical terrain, however it is not perfectly smooth
						// the shadow ray may intersect with its own triangle, which is not what we want
						// we need to do intersections with 2 triangles and find the real height

						// (we subtract 0.001 incase lerpxbottom and lerpxtop end up to be the same)

						// find rounded point heights

						// find where to cast the shadow ray
						if !util_TraceLine({start = shadowPos, endpos = shadowPos + Terrain.SunDir * 99999, filter = traceFunc}).HitSky then	// if it hits rock
							shadowAmount = 50
						end
					else	// sunlight does not hit it because it is angled away from the sun
						shadowAmount = 50
					end

					if waterHeight then
						local waterAmount = math_Clamp( (-shadowPos.z + waterHeight) * 0.2, 0, 50 )
						if render.GetHDREnabled() then // quick fix for HDR, not sure why it brightens the scene by 80%
							shadowAmount = shadowAmount * 0.2
							waterAmount = waterAmount * 0.2 
						end	
						surface_SetDrawColor(shadowAmount - waterAmount * 0.5, shadowAmount - waterAmount*0.3, shadowAmount - waterAmount*0.1, 255)
						surface_DrawRect(x * lightmapMultiplier, y * lightmapMultiplier, lightmapMultiplier, lightmapMultiplier)
					else
						if render.GetHDREnabled() then shadowAmount = shadowAmount * 0.2 end

						surface_SetDrawColor(shadowAmount, shadowAmount, shadowAmount, 255)
						surface_DrawRect(x * lightmapMultiplier, y * lightmapMultiplier, lightmapMultiplier, lightmapMultiplier)
					end
				end
			cam.End2D()
		render.PopRenderTarget()
		coroutine.yield()
	end
	hook.Remove("HUDPaint", "terrain_load")
end

function Terrain.GenerateLightmap(res, heightFunction)
	local co = coroutine.create(function() generateLightmap(res, heightFunction or Terrain.MathFunc) end)

	// dont run it all at once, it destroys ur game
	hook.Add("Think", "terrain_lightmap_gen", function()
		if coroutine.status(co) != "dead" then
			coroutine.resume(co)
		else
			hook.Remove("Think", "terrain_lightmap_gen")
		end
	end)
end

-- initialize a menu option 
hook.Add("PopulateToolMenu", "terrain_menu", function()
	spawnmenu.AddToolMenuOption("Utilities", "Procedural Terrain", "Procedural_Terrain", "Terrain", "", "",function(panel)
		panel:ClearControls()
		panel:Button("Terrain Menu", "terrain_menu")
		panel:Help("\nfunny stuff")
		panel:Button("removes all textures", "pp_texturize", "0")
		panel:Button("puts them back", "pp_texturize", "")
	end)
end)

