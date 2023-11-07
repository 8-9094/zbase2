local NPC = ZBaseNPCs["npc_zbase"]


NPC.IsZBaseNPC = true


local VJ_Translation = {
    ["CLASS_COMBINE"] = "combine",
    ["CLASS_ZOMBIE"] = "zombie",
    ["CLASS_ANTLION"] = "antlion",
    ["CLASS_PLAYER_ALLY"] = "ally",
}

local VJ_Translation_Flipped = {
    ["combine"] = "CLASS_COMBINE",
    ["zombie"] = "CLASS_ZOMBIE",
    ["antlion"] = "CLASS_ANTLION",
    ["ally"] = "CLASS_PLAYER_ALLY",
}

local ReloadActs = {
    [ACT_RELOAD] = true,
    [ACT_RELOAD_SHOTGUN] = true,
    [ACT_RELOAD_SHOTGUN_LOW] = true,
    [ACT_RELOAD_SMG1] = true,
    [ACT_RELOAD_SMG1_LOW] = true,
    [ACT_RELOAD_PISTOL] = true,
    [ACT_RELOAD_PISTOL_LOW] = true,
}


---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseInit()
    -- Vars
    self.NextPainSound = CurTime()


    -- Some calls based on attributes
    self:SetMaxLookDistance(self.SightDistance)
    self:SetCurrentWeaponProficiency(self.WeaponProficiency)
    self:SetBloodColor(self.BloodColor)


    -- Extra capabilities given
    for _, v in ipairs(self.ExtraCapabilities) do
        self:CapabilitiesAdd(v)
    end


    -- Default capabilities for all zbase NPCs
    self:CapabilitiesAdd(bit.bor(
        CAP_SQUAD,
        CAP_TURN_HEAD,
        CAP_ANIMATEDFACE,
        CAP_SKIP_NAV_GROUND_CHECK,
        CAP_FRIENDLY_DMG_IMMUNE
    ))


    -- Set specified internal variables
    self:ZBaseSetSaveValues()
    

    -- Group in squads
    timer.Simple(1, function()
        if !IsValid(self) then return end
        self:ZBaseSquad()
    end)


    -- Makes behaviour system function
    ZBaseBehaviourInit( self )


    -- Custom init
    self:CustomInitialize()
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:OnEmitSound( data )
    local val = self:CustomOnEmitSound( data )
    local squad = self:GetKeyValues().squadname

    if isstring(val) then
        return val
    elseif val == false then
        return false
    elseif squad != "" && ZBase_DontSpeakOverThisSound then
        -- Make sure squad doesn't speak over each other
        ZBaseSpeakingSquads[squad] = true
        timer.Create("ZBaseUnmute_"..squad, SoundDuration(data.SoundName), 1, function()
            ZBaseSpeakingSquads[squad] = nil
        end) 
    end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:OnKilledEnt( ent )
    if ent == self:GetEnemy() then
        self:EmitSound_Uninterupted(self.KilledEnemySound)
    end
    
    self:CustomOnKilledEnt( ent )
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:OnHurt( dmg )
    if self.NextPainSound < CurTime() then
        self:EmitSound(self.PainSounds)
        self.NextPainSound = CurTime()+ZBaseRndTblRange( self.PainSoundCooldown )
    end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseSquad()
    if self.ZBaseFaction == "none" then return end


    local squadName = self.ZBaseFaction.."1"
    local i = 1
    while true do
        local squadMemberCount = 0

        for _, v in ipairs(ZBaseNPCInstances) do
            if IsValid(v) && v:GetKeyValues().squadname == squadName then
                squadMemberCount = squadMemberCount+1
            end
        end

        if squadMemberCount >= 4 then
            i = i+1
            squadName = self.ZBaseFaction..i
        else
            break
        end
    end


    self:SetKeyValue("squadname", squadName)
    --self.ZBaseSquadName = squadName
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseSetSaveValues()
    for k, v in pairs(self:GetTable()) do
        if string.StartWith(k, "m_") then
            -- print(k, v)
            self:SetSaveValue(k, v)
        end
    end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:NewActivityDetected( act )
    -- Reload ZBase weapon sound:
    local wep = self:GetActiveWeapon()
    if ReloadActs[act] && IsValid(wep) && wep.IsZBaseWeapon && wep.NPCReloadSound != "" then
        debugoverlay.Text(self:WorldSpaceCenter(), "RELOAD SOUND")
        wep:EmitSound(wep.NPCReloadSound)
    end

    self:CustomNewActivityDetected( act )
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseAlertSound()
    ZBaseDelayBehaviour(ZBaseRndTblRange(self.IdleSounds_HasEnemyCooldown), self, "DoIdleEnemySound")
    
    timer.Simple(math.Rand(0, 1), function()
        if !IsValid(self) then return end
        self:EmitSound_Uninterupted(self.AlertSounds)
    end)
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseThink()

    local ene = self:GetEnemy()

    if ene != self.Alert_LastEnemy then
        self.Alert_LastEnemy = ene

        if self.Alert_LastEnemy then
            self:StopSound(self.IdleSounds)
            self:ZBaseAlertSound()
        end
    end

    self:Relationships()

    -- Activity change detection
    local act = self:GetActivity()
    if act && act != self.ZBaseCurrentACT then
        self.ZBaseCurrentACT = act
        self:NewActivityDetected( self.ZBaseCurrentACT )
    end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:SetRelationship( ent, rel )
    self:AddEntityRelationship(ent, rel, 99)
    if ent:IsNPC() then
        ent:AddEntityRelationship(self, rel, 99)
    end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBase_VJFriendly( ent )
    if !ent.IsVJBaseSNPC then return false end

    for _, v in ipairs(ent.VJ_NPC_Class) do
        if VJ_Translation[v] == self.ZBaseFaction then return true end
    end

    return false
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:Relationship( ent )
    -- Me or the ent has faction neutral, like
    if self.ZBaseFaction == "neutral" or ent.ZBaseFaction=="neutral" then
        self:SetRelationship( ent, D_LI )
        return
    end

    -- My faction is none, hate everybody
    if self.ZBaseFaction == "none" then
        self:SetRelationship( ent, D_HT )
        return
    end

    -- Are their factions the same?
    if self.ZBaseFaction == ent.ZBaseFaction or self:ZBase_VJFriendly( ent ) then
        self:SetRelationship( ent, D_LI )
    else
        self:SetRelationship( ent, D_HT )
    end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:Relationships()

    if VJ_Translation_Flipped[self.ZBaseFaction] then
        self.VJ_NPC_Class = {VJ_Translation_Flipped[self.ZBaseFaction]}
    end

    for _, v in ipairs(ZBaseNPCInstances) do
        if !IsValid(v) then continue end
        if v != self then self:Relationship(v) end
    end

    for _, v in ipairs(ZBase_NonZBaseNPCs) do
        self:Relationship(v)
    end

    for _, v in ipairs(player.GetAll()) do
        self:Relationship(v)
    end

end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:HasCapability( cap )
    return bit.band(self:CapabilitiesGet(), cap)==cap
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:OnOwnedEntCreated( ent )
    self:CustomOnOwnedEntCreated( ent )
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:InternalSetAnimation( anim )
	if isstring(anim) then
        -- Sequence
        if self.IsZBase_SNPC then
            self:SetSequence(anim)
            self.ZBaseSNPCSequence = anim

        else
            -- Normal NPCs can't play sequences that well, try to play as activity instead
            local act = self:GetSequenceActivity(self:LookupSequence(anim))
            self:SetActivity(act)

        end

	elseif isnumber(anim) then
        -- Activity
		self:SetActivity(anim)

	end
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:InternalPlayAnimation( anim, duration, playbackRate, sched, forceFace, faceSpeed )
    if GetConVar("ai_disabled"):GetBool() then return end

    self.DoingPlayAnim = true

    -- Stop and shit
    self:ClearSchedule()
    self:ClearGoal()
    self:StopMoving()
    self:TaskComplete()


    self:InternalSetAnimation(anim)

    -- Duration stuff
    duration = duration or self:SequenceDuration() -- *0.75
    if playbackRate then
        duration = duration/playbackRate
    end


    -- Set schedule
    if sched then
        self:SetPlaybackRate(1) -- Am i hallucinating, or does this help?
        self:SetSchedule(sched)
        self:SetPlaybackRate(1) -- Am i hallucinating, or does this help?
    end


    self.TimeUntilStopAnimOverride = CurTime()+duration
    self.NextAnimTick = CurTime()+0.1


    if forceFace then
        self:Face(forceFace, duration, faceSpeed)
    end


    local timerName = "ZBaseMeleeAnimOverride"..self:EntIndex()
    timer.Create(timerName, 0, 0, function()
        if !IsValid(self)
        or self.TimeUntilStopAnimOverride < CurTime() then

            self.DoingPlayAnim = false
            self.ZBaseSNPCSequence = nil

            if sched && IsValid(self) then
                self:ClearSchedule()
            end

            timer.Remove(timerName)
            return
        end

        
        if self.NextAnimTick > CurTime() then return end


        self:InternalSetAnimation(anim)
        self:SetPlaybackRate(playbackRate or 1)

        self.NextAnimTick = CurTime()+0.1

    end)
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseStartTask(name, data)
    self:StartEngineTask(ZBaseTaskID(name), data or 0)
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:ZBaseRunTask(name, data)
    self:RunEngineTask(ZBaseTaskID(name), data or 0)
end
---------------------------------------------------------------------------------------------------------------------=#
    -- Depricated
function NPC:WithinDistance( ent, maxdist, mindist )
    if !IsValid(ent) then return false end

    local dSqr = self:GetPos():DistToSqr(ent:GetPos())
    if mindist && dSqr < mindist^2 then return false end
    if maxdist && dSqr > maxdist^2 then return false end

    return true
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:HandleAnimEvent(event, eventTime, cycle, type, options)       
    self:CustomHandleAnimEvent(event, eventTime, cycle, type, options)     
end
---------------------------------------------------------------------------------------------------------------------=#
function NPC:OnBulletHit(ent, tr, dmginfo, bulletData)
    -- Bullet reflection
    if self.ArmorReflectsBullets then
        ZBaseReflectedBullet = true

        local ent = ents.Create("base_gmodentity")
        ent:SetPos(tr.HitPos)
        ent:Spawn()

        local nrm = Vector()
        nrm:Set(tr.HitNormal)
        nrm:Rotate(AngleRand()*0.2)

        ent:FireBullets({
            Src = tr.HitPos,
            Dir = nrm,
            Damage = 0,
            IgnoreEntity = self,
        })

        ent:Remove()

        ZBaseReflectedBullet = false
    end
end
---------------------------------------------------------------------------------------------------------------------=#
