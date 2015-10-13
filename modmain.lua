local Vector3 = GLOBAL.Vector3
local dlcEnabled = GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS)
local SEASONS = GLOBAL.SEASONS
local GetPlayer = GLOBAL.GetPlayer

local ArtificalWilsonEnabled = false

AddBrainPostInit("artificalwilson",ArtificalWilson)

local function setSelfAI()
	print("Enabling Artifical Wilson")
	local player = GetPlayer()
	--player:RemoveComponent("playercontroller")
	player:AddComponent("follower")
	player:AddComponent("homeseeker")
	player:AddTag("ArtificalWilson")
	local brain = GLOBAL.require "brains/artificalwilson"
	player:SetBrain(brain)
	ArtificalWilsonEnabled = true
	--player:ListenForEvent("attacked", OnAttacked)
end

local function setSelfNormal()
	print("Disabling Artifical Wilson")
	local player = GetPlayer()
	local brain = GLOBAL.require "brains/wilsonbrain"
	player:SetBrain(brain)
	player:RemoveTag("ArtificalWilson")
	player:RemoveComponent("follower")
	player:RemoveComponent("homeseeker")
	ArtificalWilsonEnabled = false
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


local function MakeClickableBrain()

	local player = GLOBAL.GetPlayer()
	local controls = player.HUD.controls
	local status = controls.status
	
	status.brain:SetClickable(true)
	
	local x = 0
	local darker = true
	local function BrainPulse(self)
		if not darker then
			x = x+.1
			if x >=1 then
				darker = true
				x = 1
			end
		else 
			x = x-.1
			if x <=.5 then
				darker = false
				x = .5
			end
		end

		status.brain.anim:GetAnimState():SetMultColour(x,x,x,1)
		self.brainPulse = self:DoTaskInTime(.15,BrainPulse)
	end
	
	status.brain.OnMouseButton = function(self,button,down,x,y)	
		if down == true then
			if ArtificalWilsonEnabled then
				self.owner.brainPulse:Cancel()
				status.brain.anim:GetAnimState():SetMultColour(1,1,1,1)
				setSelfNormal()
			else
				BrainPulse(self.owner)
				setSelfAI()
			end
		end
	end
	
end

AddSimPostInit(MakeClickableBrain)
