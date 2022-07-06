if game.GetMap() != "gm_flatgrass" then return end

local gravity_convar = GetConVar("sv_gravity")


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
    
local trace_filter = function(e) return e:GetClass() == "terrain_chunk" end
local function getHeight(x, y)
    return Vector(x, y, Terrain.MathFunc(x, y) + Terrain.ZOffset)
end

local function intersectTerrain(pos)
    local worldx = pos[1]
    local worldy = pos[2]
    local math = math
    local lerpXBottom = math.floor(worldx / Terrain.ChunkSize - 0.001) * Terrain.ChunkSize
    local lerpYBottom = math.floor(worldy / Terrain.ChunkSize - 0.001) * Terrain.ChunkSize
    local lerpXTop	  = math.ceil(worldx / Terrain.ChunkSize) * Terrain.ChunkSize
    local lerpYTop	  = math.ceil(worldy / Terrain.ChunkSize) * Terrain.ChunkSize

    // find where to cast the shadow ray
    local v = Vector(worldx, worldy, 25601)
    local shadowPos = intersectRayWithTriangle(v, Vector(0, 0, -1), getHeight(lerpXTop, lerpYBottom), getHeight(lerpXBottom, lerpYBottom), getHeight(lerpXBottom, lerpYTop))	// 25601 = max height
    shadowPos = shadowPos or intersectRayWithTriangle(v, Vector(0, 0, -1), getHeight(lerpXTop, lerpYTop), getHeight(lerpXTop, lerpYBottom), getHeight(lerpXBottom, lerpYTop))
    
    return shadowPos[3] > pos[3]
end

local function inWater(pos)
    local waterHeight = Terrain.Variables.waterHeight
    if !waterHeight then return false end

    if intersectTerrain(pos) then return end
    return pos[3] < waterHeight
end

// water screenspace overlay
local changedWater = false
hook.Add("RenderScreenspaceEffects", "Terrain_PP", function()
	if inWater(EyePos()) then
        DrawMaterialOverlay(Terrain.Variables.material_3, 0.05)
        DrawMaterialOverlay("effects/water_warp01", 0.1)
        
        if !changedWater then
            changedWater = true
            LocalPlayer():EmitSound("Physics.WaterSplash")
            LocalPlayer():SetDSP(14, true)
        end
    elseif changedWater then
        changedWater = false
        LocalPlayer():EmitSound("Physics.WaterSplash")
        LocalPlayer():SetDSP(0, true)
    end
end)

// swim code yoinked from gwater, thanks again kodya
// player animations
hook.Add("CalcMainActivity", "Terrain_Swimming", function(ply)
	if !inWater(ply:GetPos()) or ply:IsOnGround() or ply:InVehicle() then return end
	return ACT_MP_SWIM, -1
end)

// main movement
hook.Add("Move", "Terrain_Swimming", function(ply, move)
    if !inWater(ply:GetPos()) then return end
    if SERVER then
        if Terrain.Variables.water_kill and ply:Alive() then 
            ply:Kill() 
            return 
        end
        local onfire = ply:IsOnFire()
        if ply:Alive() then
            if Terrain.Variables.water_ignite then 
                if !onfire then
                    ply:Ignite(1) 
                end
            elseif onfire then
                ply:Extinguish()
            end
        end
    end 

	local vel = move:GetVelocity()
	local ang = move:GetMoveAngles()

	local acel =
	(ang:Forward() * move:GetForwardSpeed()) +
	(ang:Right() * move:GetSideSpeed()) +
	(ang:Up() * move:GetUpSpeed())

	local aceldir = acel:GetNormalized()
	local acelspeed = math.min(acel:Length(), ply:GetMaxSpeed())
	acel = aceldir * acelspeed * 2

	if bit.band(move:GetButtons(), IN_JUMP) ~= 0 then
	    acel.z = acel.z + ply:GetMaxSpeed()
	end

	vel = vel + acel * FrameTime() * (1 / (Terrain.Variables.water_viscosity * 0.5 + 0.5))
	vel = vel * (1 - FrameTime() * 2) + Vector(0, 0, Terrain.Variables.water_buoyancy - 1)

	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5
	vel.z = vel.z + FrameTime() * gravity

	move:SetVelocity(vel * 0.99)
end)

// secondary, final movement
hook.Add("FinishMove", "Terrain_Swimming", function(ply, move)
	if !inWater(ply:GetPos()) then return end
	local vel = move:GetVelocity()
	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5

	vel.z = vel.z + FrameTime() * gravity
	move:SetVelocity(vel)
end)

// serverside stuff now
if CLIENT then
    Terrain.WaterMaterial = Material("procedural_terrain/water/water_warp")
    local waterMatrix = Matrix()
    waterMatrix:SetScale(Vector(Terrain.ChunkResScale * Terrain.Resolution, Terrain.ChunkResScale * Terrain.Resolution))

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

    hook.Add("PreDrawTranslucentRenderables", "Terrain_Water", function(_, sky)
        if sky or intersectTerrain(EyePos()) then return end
        local waterHeight = Terrain.Variables.temp_waterHeight or Terrain.Variables.waterHeight
        if waterHeight then
            waterMatrix:SetTranslation(Vector(0, 0, waterHeight))
            render.SetMaterial(Terrain.WaterMaterial)
            cam.PushModelMatrix(waterMatrix)
                waterMesh:Draw()
            cam.PopModelMatrix()
        end
    end)
    return 
end

hook.Add("PlayerFootstep", "Terrain_Water", function(ply, pos, foot, sound, volume, rf)
    if inWater(ply:GetPos()) then 
        ply:EmitSound(foot == 0 and "Water.StepLeft" or "Water.StepRight", nil, nil, volume, CHAN_BODY)     // volume doesnt work for some reason.. oh well
        return true
    end
end )

// no fall damage in fake water
hook.Add("GetFallDamage", "Terrain_Water", function(ply, speed)
    // for some reason player position isnt fully accurate when this is called
    local tr = util.TraceHull({
        start = ply:GetPos(),
        endpos = ply:GetPos() + ply:GetVelocity(),
        maxs = ply:OBBMaxs(),
        mins = ply:OBBMins(),
        filter = ply
    })
    if tr.Hit and inWater(tr.HitPos) then return 0 end
end)


if SERVER then
    local IsValid = IsValid
    local Clamp = math.Clamp
    local timer = timer
    local positions = {}
    local valid_materials = {
        ["floating_metal_barrel"] = true,
        ["wood"] = true,
        ["wood_crate"] = true,
        ["wood_furniture"] = true,
        ["rubbertire"] = true,
        ["wood_solid"] = true,
        ["plastic"] = true,
        ["watermelon"] = true,
        ["default"] = true,
        ["cardboard"] = true,
        ["paper"] = true,
        ["popcan"] = true,
    }
    hook.Add("Think", "terrain_buoyancy", function()
        local waterHeight = Terrain.Variables.waterHeight // add 5 so the objects dont stay all the way under water
        local entities = ents.FindByClass("prop_*")
        for _, prop in ipairs(entities) do
            local phys = prop:GetPhysicsObject()
            if !phys:IsValid() or phys:IsAsleep() then continue end

            local is_airboat = prop:GetClass() == "prop_vehicle_airboat"
            if valid_materials[phys:GetMaterial()] or is_airboat then 
                local mins = prop:OBBMins()
                local maxs = prop:OBBMaxs()

                // do not calculate object, we know it is too far and not near the water
                local p = prop:GetPos()[3] - 1
                if p - math.abs(mins[3]) > waterHeight and p - math.abs(maxs[3]) > waterHeight then
                    continue
                end

                // why is the airboat size fucked?
                if is_airboat then 
                    mins = mins * 0.5
                    maxs = maxs * 0.5
                    mins[3] = 0
                    maxs[3] = 0
                end

                // so many points
                positions[1] = Vector(mins[1], mins[2], mins[3])
                positions[2] = Vector(mins[1], mins[2], maxs[3])
                positions[3] = Vector(mins[1], maxs[2], mins[3])
                positions[4] = Vector(maxs[1], mins[2], mins[3])
                positions[5] = Vector(mins[1], maxs[2], maxs[3])
                positions[6] = Vector(maxs[1], maxs[2], mins[3])
                positions[7] = Vector(maxs[1], mins[2], maxs[3])
                positions[8] = Vector(maxs[1], maxs[2], maxs[3])

                local prop_inwater = false
                local should_sleep = (phys:GetVelocity() + phys:GetAngleVelocity()):Length() < 1 and !prop:IsPlayerHolding()
                local viscosity = Terrain.Variables.water_viscosity
                local buoyancy = Terrain.Variables.water_buoyancy
                for _, pos in ipairs(positions) do
                    local world_pos = prop:LocalToWorld(pos)
                    if inWater(world_pos) then
                        if is_airboat then
                            phys:ApplyForceOffset(Vector(0, 0, phys:GetMass() * math.min(((waterHeight - world_pos[3]) * 0.75 * buoyancy), 2 * buoyancy)), world_pos)
                            phys:ApplyForceCenter(phys:GetMass() * phys:GetVelocity() * viscosity * -0.001)   //dampen very small bit for airboats
                        else
                            phys:ApplyForceOffset(Vector(0, 0, phys:GetMass() * (math.min(((waterHeight - world_pos[3]) * 0.1 * buoyancy), 3 * buoyancy))), world_pos)
                            phys:ApplyForceCenter(phys:GetMass() * phys:GetVelocity() * viscosity * -0.003)   //dampen a bit
                        end
                        phys:AddAngleVelocity(phys:GetAngleVelocity() * viscosity * -0.01)
                        prop_inwater = true
                        //debugoverlay.Sphere(world_pos, 10, 0.1)
                    end
                end

                if prop_inwater and should_sleep then
                    phys:Sleep()
                end
            end
        end
    end)
end