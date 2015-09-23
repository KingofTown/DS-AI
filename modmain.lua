local Vector3 = GLOBAL.Vector3
local dlcEnabled = GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS)
local SEASONS = GLOBAL.SEASONS
local GetPlayer = GLOBAL.GetPlayer

AddBrainPostInit("artificalwilson",ArtificalWilson)


local function spawnAI(sim)

	sim.SpawnWilson = function(inst)
		wilson = GLOBAL.SpawnPrefab("wilson")
		pos = Vector3(GetPlayer().Transform:GetWorldPosition())
		if wilson and pos then
			wilson:AddComponent("follower")
			wilson:AddComponent("homeseeker")
			wilson:AddComponent("inventory")
			wilson:AddTag("ArtificalWilson")
			
			local brain = GLOBAL.require "brains/artificalwilson"
			wilson:SetBrain(brain)
			wilson.Transform:SetPosition(pos:Get())
		end
	end
	
	local function OnAttacked(inst, data)
		inst.components.combat:SetTarget(data.attacker)
	end
	
	
	
	sim.SetSelfAI = function(inst)
		local player = GetPlayer()
		--player:RemoveComponent("playercontroller")
		player:AddComponent("follower")
		player:AddComponent("homeseeker")
		player:AddTag("ArtificalWilson")
		local brain = GLOBAL.require "brains/artificalwilson"
		player:SetBrain(brain)
		player:ListenForEvent("attacked", OnAttacked)
	end
	
	sim.SetSelfNormal = function(inst)
		local player = GetPlayer()
		player:RemoveTag("ArtificalWilson")
	end
end

AddComponentPostInit("clock",spawnAI)

