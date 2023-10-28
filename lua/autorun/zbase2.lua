-------------------------------------------------------------------------------------------------------------------------=#
if SERVER then
    print("-- ███████╗██████╗░░█████╗░░██████╗███████╗ --")
    print("-- ╚════██║██╔══██╗██╔══██╗██╔════╝██╔════╝ --")
    print("-- ░░███╔═╝██████╦╝███████║╚█████╗░█████╗░░ --")
    print("-- ██╔══╝░░██╔══██╗██╔══██║░╚═══██╗██╔══╝░░ --")
    print("-- ███████╗██████╦╝██║░░██║██████╔╝███████╗ --")
    print("-- ╚══════╝╚═════╝░╚═╝░░╚═╝╚═════╝░╚══════╝ --")
        
    print("                                     -- █▀▀▄ █──█ 　 ▀▀█ ─▀─ █▀▀█ █▀▀█ █──█ --")
    print("                                     -- █▀▀▄ █▄▄█ 　 ▄▀─ ▀█▀ █──█ █──█ █▄▄█ --")
    print("                                     -- ▀▀▀─ ▄▄▄█ 　 ▀▀▀ ▀▀▀ █▀▀▀ █▀▀▀ ▄▄▄█ --")
end   
-------------------------------------------------------------------------------------------------------------------------=#

        -- TODO --
    -- Fix shit inheritence
    -- Next?

        -- Ideas --
    -- Hearing system
    -- Ditch squads, use better system instead
    -- Hl2 weapons deal correct damage + secondary fire (as behaviour) + improve crossbow + other improvements maybe
    -- SNPCs
    -- COND_ for behaviours
    -- Custom NPCs, for example, Ministrider, crabless zombies (just called zombies, normal zombies will be called headcrab zombies)
    -- Custom blood system, white blood decals for hunters
    -- More sounds (hear enemy, lost enemy, hear danger, grenade, etc)
    -- Player factions
    -- Radio on/off sounds for CHAN_VOICE sounds
    -- Very basic weapon base
    -- Recreate some hl2 npcs

-------------------------------------------------------------------------------------------------------------------------=#



-- Includes --
include("zbase/sh_globals.lua")
include("zbase/sh_hooks.lua")
include("zbase/sh_replace_funcs.lua")
if SERVER then
    include("zbase/sv_behaviour.lua")
end


if CLIENT then
    -- spawnmenu.AddCreationTab( "ZBase", function(...)
    --     print(...)
    --     return vgui.Create("DCheckBox")
    -- end)

    spawnmenu.AddContentType( "ZBase", function( ... ) print(...) end)
end


 
-- Sounds --
sound.Add( {
	name = "ZBase.Ricochet",
	channel = CHAN_BODY,
	volume = 0.8,
	level = 75,
	pitch = {90, 110},
	sound = {
        "weapons/fx/rics/ric1.wav",
        "weapons/fx/rics/ric2.wav",
        "weapons/fx/rics/ric3.wav",
        "weapons/fx/rics/ric4.wav",
        "weapons/fx/rics/ric5.wav"
    }
} )


-------------------------------------------------------------------------------------------------------------------------=#
local function NPCsInherit()
    for cls, t in pairs(ZBaseNPCs) do
        local ZBase_Inherit = t.Inherit

        for k, v in pairs(ZBaseNPCs[ZBase_Inherit]) do
            if !t[k] then
                t[k] = v
            end
        end
    end
end
-------------------------------------------------------------------------------------------------------------------------=#
local function NPCReg( name, path )
    if string.StartsWith(name, "npc_") then

        local path = path or ("zbase_npcs/"..name)
        local sh = path.."/shared.lua"
        local cl = path.."/cl_init.lua"
        local sv = path.."/init.lua"

        local function inherit( t )

        end

        if file.Exists(sh, "LUA")
        && file.Exists(sv, "LUA")
        && file.Exists(cl, "LUA") then

            -- New NPC
            ZBaseNPCs[name] = {Behaviours={}}

            -- Files --
            include(sh)
            AddCSLuaFile(sh)
            AddCSLuaFile(cl)

            if SERVER then
                include(sv)

                local bh = path.."/behaviour.lua"
                if file.Exists(bh, "LUA") then
                    include(bh)
                end
            end

            if CLIENT then
                include(cl)
            end
            --------------------------------=#

            -- Inherit
            timer.Simple(1, function()
                inherit(ZBaseNPCs[name])
            end)
        end
    end
end
-------------------------------------------------------------------------------------------------------------------------=#
local function registerNPCs()
    local _, dirs = file.Find("zbase_npcs/*","LUA")

    NPCReg("npc_zbase", "npc_zbase") -- Register base

    -- Register all ZBase NPCs
    for _, v in ipairs(dirs) do
        NPCReg(v)
    end
end
-------------------------------------------------------------------------------------------------------------------------=#
local function AddNPCsToSpawnMenu()
    -- Add all NPCs to spawnmenu
    for cls, t in pairs( ZBaseNPCs ) do

        local spawnmenuTbl = table.Copy(t)
        spawnmenuTbl.KeyValues.parentname = "zbase_"..cls
        spawnmenuTbl.Category = "ZBase - "..t.Category
        list.Set( "NPC", cls, spawnmenuTbl )

    end
end
-------------------------------------------------------------------------------------------------------------------------=#
hook.Add("Initialize", "ZBASE", function()
    NPCsInherit()
    AddNPCsToSpawnMenu()
    PrintTable(ZBaseNPCs)
end)
-------------------------------------------------------------------------------------------------------------------------=#

registerNPCs()
