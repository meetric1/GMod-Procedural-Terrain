// guess why this file is named !terrain_detour instead of terrain_detour
// its because all the addon files initialize in alphabetical order!
// we need the traceline detour to run before any other addon
// its extremely important that the detour runs first to avoid addon conflictions

if game.GetMap() != "gm_flatgrass" then return end

AddCSLuaFile()

Terrain = Terrain or {}

Terrain.TraceLine = Terrain.TraceLine or util.TraceLine
local lookup = Terrain.TraceLine    // faster lookup, dont wanna bog frames
function util.TraceLine(t)
    local tr = lookup(t)
    local e = tr.Entity
    if e and e:IsValid() and e:GetClass() == "terrain_chunk" then 
        tr.Entity = game.GetWorld() 
    end
    return tr
end