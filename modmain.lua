local Vector3 = GLOBAL.Vector3
local dlcEnabled = GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS)
local SEASONS = GLOBAL.SEASONS
local GetPlayer = GLOBAL.GetPlayer

AddBrainPostInit("artificalwilson",ArtificalWilson)

local function setSelfAI()
	local player = GetPlayer()
	--player:RemoveComponent("playercontroller")
	player:AddComponent("follower")
	player:AddComponent("homeseeker")
	player:AddTag("ArtificalWilson")
	local brain = GLOBAL.require "brains/artificalwilson"
	player:SetBrain(brain)
	--player:ListenForEvent("attacked", OnAttacked)
end

local function setSelfNormal()
	local player = GetPlayer()
	local brain = GLOBAL.require "brains/wilson"
	player:SetBrain(brain)
	player:RemoveTag("ArtificalWilson")
	player:RemoveComponent("follower")
	player:RemoveComponent("homeseeker")
end

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
	
	
	
	sim.SetSelfAI = setSelfAI
	sim.SetSelfNormal = setSelfNormal

end

AddComponentPostInit("clock",spawnAI)

GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_P, function()
	local TheInput = GLOBAL.TheInput
	if not GLOBAL.IsPaused() and TheInput:IsKeyDown(GLOBAL.KEY_CTRL) and not TheInput:IsKeyDown(GLOBAL.KEY_ALT) then
		setSelfAI()
	elseif not GLOBAL.IsPaused() and TheInput:IsKeyDown(GLOBAL.KEY_CTRL) and TheInput:IsKeyDown(GLOBAL.KEY_ALT) then
		setSelfNormal()
	end
	
end)

