if game.GetMap() != "gm_flatgrass" then return end

local gravity_convar = GetConVar("sv_gravity")

local maintrace_hit
local trace_filter = function(e) return e:GetClass() == "terrain_chunk" end
local function inWater(pos)
    local waterHeight = Terrain.Variables.waterHeight
    if !waterHeight then return false end

    if maintrace_hit then return false end
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
	if !inWater(ply:GetPos()) or ply:IsOnGround() then return end
	return ACT_MP_SWIM, -1
end)

// main movement
hook.Add("Move", "Terrain_Swimming", function(ply, move)
    maintrace_hit = !util.TraceLine({
        start = ply:GetPos(),
        endpos = ply:GetPos() - Vector(0, 0, 99999),
        filter = trace_filter,
        ignoreworld = true
    }).Hit
    if !inWater(ply:GetPos()) then return end
    if Terrain.Variables.waterKill then ply:Kill() return end

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

	vel = vel + acel * FrameTime()
	vel = vel * (1 - FrameTime() * 2)

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
    if game.SinglePlayer() then
        hook.Add("Think", "terrain_water_trace", function()
            maintrace_hit = !util.TraceLine({
                start = EyePos(),
                endpos = EyePos() - Vector(0, 0, 99999),
                filter = trace_filter,
                ignoreworld = true
            }).Hit
        end)
    end
        
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
        if sky or maintrace_hit then return end
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