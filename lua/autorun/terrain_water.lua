if game.GetMap() != "gm_flatgrass" then return end

local gravity_convar = GetConVar("sv_gravity")
local function inWater(ply)
    local waterHeight = Terrain.Variables.waterHeight
    if !waterHeight then return false end

    if isentity(ply) then return ply:GetPos()[3] < waterHeight end
    return ply[3] < waterHeight
end

// water screenspace overlay
local changedWater = false
hook.Add("RenderScreenspaceEffects", "Terrain_PP", function()
	if inWater(EyePos()) then
        DrawMaterialOverlay("effects/water_warp01", 0.1)
        DrawMaterialOverlay("effects/water_warp", 0.05)
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
	if !inWater(ply) or ply:IsOnGround() then return end
	return ACT_MP_SWIM, -1
end)

// main movement
hook.Add("Move", "Terrain_Swimming", function(ply, move)
    if !inWater(ply) or CLIENT then return end
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
	if !inWater(ply) then return end
	local vel = move:GetVelocity()
	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5

	vel.z = vel.z + FrameTime() * gravity
	move:SetVelocity(vel)
end)

// serverside stuff now
if CLIENT then return end

hook.Add("PlayerFootstep", "Terrain_Water", function(ply, pos, foot, sound, volume, rf)
    if inWater(ply) then 
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