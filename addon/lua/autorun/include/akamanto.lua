AddCSLuaFile()

pk_pills.packStart("Aka Manto","Aka Manto","icon/pill_akamanto.png")

pk_pills.register("pill_pakamanto",{

    printName="Aka Manto",
	
    model="models/astolfo_alter/chillasarts/akamanto/aka_mantov3.mdl",
	
	modelScale="1.3",

	muteSteps = true,
	
    anims={
        default={
            idle="idle",
			run="walkfast",
            walk="walk",
			attack="stab",
			jumpscare="stab",
            missattack="stab",
            crouch="idle",
            crouch_walk="walk",
        },
    },
	
    moveSpeed={
        walk=80,
        run=510,
        ducked=100,
    },
	
    sounds={
		melee="slender/aka_manto/kill.wav",
        sound1="slender/aka_manto/laugh.wav",
		sound2="slender/aka_manto/scream.wav",
		jumpscare="slender/aka_manto/kill.wav",
		loop_stare="slender/aka_manto/idle.wav",
        highlight="slender/aka_manto/detect.wav",
    },
	

    type="ply",

    camera={
        dist=120
    },
	
    jumpPower=200,
	
    health=4444,
	
	movePoseMode="xy",
		aim={
		xPose="aim_yaw",
		yPose="aim_pitch",
		nocrosshair = true
	},
	
	canAim=function(ply,ent)
		return ent.active
	end,
	
	init = function(ply, ent)
		-- Timer to check velocity and possibly play a sound every second
		timer.Create("CheckVelocityAndPlaySound" .. ply:EntIndex(), 1, 0, function()
			if not IsValid(ply) then
				timer.Remove("CheckVelocityAndPlaySound" .. ply:EntIndex())
				return
			end
			
			local velocity = ply:GetVelocity():Length()
	
			if velocity <= 300 then
				local rand = math.random(2, 20)
	
				if rand == 2 then
					ent:PillSound("loop_stare")	
				end
			end
		end)
	end,

    --Left Click Attack Function
attack = {
    mode = 'trigger',
    func = function(ply, ent)
        local center = ent:LocalToWorld(Vector(0, 0, 50))
        local entity

        if SherlockHNS then
            -- Sherlock: escolhe somente um alvo validado pela Kill API.
            entity = SherlockHNS.FindVictim(ply, center, 60)
        else
            -- Sandbox: preserva o comportamento original com players e NPCs.
            for _, v in ipairs(ents.FindInSphere(center, 60)) do
                if v ~= ent and v ~= ply
                    and ((v:IsPlayer() and v:Team() ~= TEAM_SPECTATOR)
                        or ((v:IsNPC() or v:IsNextBot()) and v:Health() > 0)) then
                    entity = v
                    break
                end
            end
        end

        if SherlockHNS and IsValid(entity) and entity:IsPlayer() then
            return pk_pills.playHNSJumpscare(ply, ent, entity, 0.7, {
                camera = "PILLSJUMPCAM",
                offset = 75,
                animation = "jumpscare",
                sound = "jumpscare",
            })
        end

        if IsValid(entity) then
            local pill = ent:GetPuppet()

            -- Handling players
            if entity:IsPlayer() then
                entity:Freeze(true)
                entity:AddFlags(FL_NOTARGET)
                entity:DrawViewModel(false)
                entity:SetActiveWeapon(nil)

                -- Start the jump scare camera effect
                net.Start('PILLSJUMPCAM')
                net.WriteEntity(pill)
                net.WriteBool(true)
                net.Send(entity)
            else
                -- Disable NPC's future thinking to simulate freezing them
                entity:NextThink(CurTime() + 1e9) 
            end

            -- Move the entity into position relative to the pill
            entity:SetPos(pill:GetPos() + pill:GetForward() * 75)

            ply:Freeze(true)

            -- Play the animation and sound for the entity performing the attack
            ent:PillAnim('jumpscare')
            ent:PillSound('jumpscare')
            timer.Simple(1.50, function()
                ent.killlineplaying = true
                ent:PillSound('killvoice')
            end)

            -- Timer to handle the next steps after the animation
            timer.Simple(0.7, function()
                if not IsValid(entity) or not IsValid(ent) then return end

                

                -- Handling NPCs
                if entity:IsNPC() or entity:IsNextBot() then
                    local headBone = entity:LookupBone("ValveBiped.Bip01_Head1")
                    if headBone then
                        entity:ManipulateBoneScale(headBone, Vector(0, 0, 0))
                    end
                end

                -- Handling Players
                if entity:IsPlayer() then
                    local finalRagdoll = ents.Create("prop_ragdoll")
                    finalRagdoll:SetModel(entity:GetModel())
                    finalRagdoll:SetPos(entity:GetPos())
                    finalRagdoll:SetAngles(entity:GetAngles())
                    finalRagdoll:Spawn()

                    -- Set ragdoll physics
                    for i = 0, entity:GetBoneCount() - 1 do
                        local phys = finalRagdoll:GetPhysicsObjectNum(i)
                        if IsValid(phys) then
                            local pos, ang = entity:GetBonePosition(i)
                            phys:SetPos(pos)
                            phys:SetAngles(ang)
                            phys:Wake()
                        end
                    end

                    -- Manipulate head bone
                    local headBone = finalRagdoll:LookupBone("ValveBiped.Bip01_Head1")
                    if headBone then
                        finalRagdoll:ManipulateBoneScale(headBone, Vector(0, 0, 0))
                    end
                end

                -- Freeze and reset player settings
                ply:Freeze(false)

                -- Kill the player or damage the NPC
                if entity:IsPlayer() then
                    entity:Kill(ply)
                    net.Start('PILLSJUMPCAM')
                    net.WriteEntity(pill)
                    net.WriteBool(false)
                    net.Send(entity)
                    entity:RemoveFlags(FL_NOTARGET)
                    entity:Freeze(false)
                    entity:DrawViewModel(true)
                else
                    entity:NextThink(CurTime()) 
                    entity:TakeDamage(1e9, ply)
                end
            end)
        else
            -- No valid target, perform normal attack animation
        end

        timer.Simple(3, function()
            ply.OnHold = false
        end)

        -- Timer to reset hold state
        timer.Simple(10, function()
            ent.killlineplaying = false
        end)
    end,
},





attack2 = {
    mode = "trigger",
    func = function(ply, ent)
        if not IsValid(ply) then return end

        ent.highlightlineplaying = true

        local cooldown = 40
        local lastUse = ply._lastWallUse or 0
        local now = CurTime()

        if now - lastUse < cooldown then
            local timeLeft = math.ceil(cooldown - (now - lastUse))
            ply:ChatPrint("Highlight on cooldown: " .. timeLeft .. "s left.")
            return
        end

        if ply.OnHold then return end

        ent:PillSound("highlight")
        ply:SetNWBool("AMwallhaks", true)
        ply.wallsdelay = true
        ply._lastWallUse = now
        timer.Simple(5, function()
            ent.highlightlineplaying = false
        end)

        timer.Simple(5, function()
            if IsValid(ply) then
                ply:SetNWBool("AMwallhaks", false)
            end
        end)

        timer.Simple(cooldown, function()
            if IsValid(ply) then
                ply.wallsdelay = false
            end
        end)
    end,
},
    

noragdoll=true,
	
	-- R click function
   	reload=function(ply,ent)
        ent.laughlineplaying = true
        ent:PillSound('sound1')
        ent.laughonhold = true
        timer.Simple(2.5, function()
            ent.laughonhold = false
        end)
        timer.Simple(4, function()
            ent.laughlineplaying = false
        end)
	end,
}, function(form)
    -- The legacy damage branches are for Sandbox and NPCs.
    form.hnsKillAPI = true
    form.hnsAbilities = {
        { id = "attack", name = "Ataque", key = IN_ATTACK, OnUse = form.attack.func },
        { id = "highlight", name = "Revelar jogadores", key = IN_ATTACK2, cooldown = 40, duration = 5,
            CanUse = function(ply) return not ply.OnHold end,
            OnUse = function(ply, ent)
                ent:PillSound("highlight")
                ply:SetNWBool("AMwallhaks", true)
            end,
            OnEnd = function(ply) if IsValid(ply) then ply:SetNWBool("AMwallhaks", false) end end },
        { id = "laugh", name = "Risada", key = IN_RELOAD, OnUse = form.reload },
    }
    form.attack, form.attack2, form.reload = nil, nil, nil
end)


