require "behaviours/wander"
require "behaviours/follow"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/findlight"
require "behaviours/panic"
require "behaviours/chattynode"
require "behaviours/leash"

-- The order in which we prioritize things to build
-- Stuff to be collected should follow the priority of the build order
-- Have things to build once, build many times, etc
-- Denote if we should always keep spare items (to build fire, etc)
local BUILD_ORDER =
{

}


local ArtificalBrain = Class(Brain, function(self, inst)
    Brain._ctor(self,inst)
end)

-- Go home stuff
-----------------------------------------------------------------------
local function HasValidHome(inst)
    return inst.components.homeseeker and 
       inst.components.homeseeker.home and 
       inst.components.homeseeker.home:IsValid()
end

local function GoHomeAction(inst)
    if  HasValidHome(inst) and
        not inst.components.combat.target then
            return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function GetHomePos(inst)
    return HasValidHome(inst) and inst.components.homeseeker:GetHomePos()
end

local function FindValidHome(inst)
	if not HasValidHome(inst) and inst.components.homeseeker then
		-- TODO: How to determine a good home. 
	end
end

---------------------------------------------------------------------------
-- Harvest Actions
local function FindTreeToChopAction(inst)
	-- Do we need logs? (always)
	-- Don't chop unless we need logs (this is hacky)
	if inst.components.inventory:Has("log",20) then
		return
	end
	
	-- TODO, this will target trees, mushtrees, etc
	local target = FindEntity(inst, 15, function(item) return item.components.workable and item.components.workable.action == ACTIONS.CHOP end)
	
	if target then
		-- Found a tree...should we chop it?
		-- Check to see if axe is already equipped. If not, equip one
		local equiped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		local alreadyEquipped = false
		local axe = nil
		if equiped and equiped.components.tool and equiped.components.tool:CanDoAction(ACTIONS.CHOP) then
			axe = equiped
			alreadyEquipped = true
		else 
			axe = inst.components.inventory:FindItem(function(item) return item.components.equippable and item.components.tool and item.components.tool:CanDoAction(ACTIONS.CHOP) end)
		end
		-- We are holding an axe or have one in inventory. Let's chop
		if axe then
			if not alreadyEquipped then
				inst.components.inventory:Equip(axe)
			end
			return BufferedAction(inst, target, ACTIONS.CHOP)
		end
	end
end

local function FindResourceToHarvest(inst)
	if not inst.components.inventory:IsFull() then
		local target = FindEntity(inst, 15, function(item)
					if item.components.pickable and item.components.pickable:CanBePicked() and item.components.pickable.caninteractwith then
						local theProductPrefab = item.components.pickable.product
						if theProductPrefab == nil then
							return false
						end
						-- Check to see if we have a full stack of this item
						local theProduct = inst.components.inventory:FindItem(function(item) return (item.prefab == theProductPrefab) end)
						if theProduct then
							-- If we don't have a full stack of this...then pick it up (if not stackable, we will hold 2 of them)
							return not inst.components.inventory:Has(theProductPrefab,theProduct.components.stackable and theProduct.components.stackable.maxsize or 2)
						else
							-- Don't have any of this...lets get some
							return true
						end
					end
					-- Default case...probably not harvest-able. Return false.
					return false
				end)

		if target then
			return BufferedAction(inst,target,ACTIONS.PICK)
		end
	end
end

local function FindResourceOnGround(inst)
	-- TODO: Check to see if it would stack
	if not inst.components.inventory:IsFull() then
		-- TODO: Only have up to 1 stack of the thing (modify the findentity fcn)
		local target = FindEntity(inst, 15, function(item) 
							if item.components.inventoryitem and 
								item.components.inventoryitem.canbepickedup and 
								not item.components.inventoryitem:IsHeld() and
								item:IsOnValidGround() and
								-- Ignore things we have a full stack of
								not inst.components.inventory:Has(item.prefab, item.components.stackable and item.components.stackable.maxsize or 2) and
								not item:HasTag("prey") and
								not item:HasTag("bird") then
									return true
							end
						end)
		if target then
			return BufferedAction(inst, target, ACTIONS.PICKUP)
		end
	end
end

-----------------------------------------------------------------------
-- Eating and stuff
local function HaveASnack(inst)

	if inst.components.hunger:GetPercent() > .5 then
		return
	end
	
	if inst.sg:HasStateTag("busy") then
		return
	end
		
	-- Check inventory for food. 
	-- If we have none, set the priority item to find to food (TODO)
	local allFoodInInventory = inst.components.inventory:FindItems(function(item) return inst.components.eater:CanEat(item) end)
	
	-- TODO: Find cookable food (can't eat some things raw)
	
	for k,v in pairs(allFoodInInventory) do
		-- Sort this list in some way. Currently just eating the first thing.
		-- TODO: Get the hunger value from the food and spoil rate. Prefer to eat things 
		--       closer to spoiling first
		if inst.components.hunger:GetPercent() <= .5 then
			return BufferedAction(inst,v,ACTIONS.EAT)
		end
	end
	
	-- TODO:
	-- We didn't find antying to eat and we're hungry. Set our priority to finding food!

end

--[[ 
Soo...how to survive. 
0) Pick a spot to call 'home'
1) Gather stuff (should prioritize things)
2) Eat
3) Stay near the light

--]]

function ArtificalBrain:OnStart()
	local clock = GetClock()
	
	-- Things to do during the day
	local day = WhileNode( function() return clock and clock:IsDay() end, "IsDay",
		PriorityNode{
			DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true ),
			IfNode( function() return not self.inst.sg:HasStateTag("busy") end, "notBusy_goPickup",
				DoAction(self.inst, function() return FindResourceOnGround(self.inst) end, "pickup_ground", true )),
			IfNode( function() return not self.inst.sg:HasStateTag("busy") end, "notBusy_goHarvest",
				DoAction(self.inst, function() return FindResourceToHarvest(self.inst) end, "harvest", true )),
			IfNode( function() return not self.inst.sg:HasStateTag("busy") end, "notBusy_goChop",
				DoAction(self.inst, function() return FindTreeToChopAction(self.inst) end, "chopTree", true)),

			-- No plan...just walking around
			--Wander(self.inst, nil, 20),
		},.5)
		

	local dusk = WhileNode( function() return clock and clock:IsDusk() end, "IsDusk",
        PriorityNode{
			DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true ),
            ChattyNode(self.inst, STRINGS.PIG_TALK_RUNAWAY_WILSON,
                RunAway(self.inst, "player", 3, 3)),
        },.5)
		
	-- Things to do during the night
	--[[
		1) Light a fire if there is none close by
		2) Stay near fire. Maybe cook?
	--]]
	local night = WhileNode( function() return clock and clock:IsNight() end, "IsNight",
        PriorityNode{
			DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true ),
            ChattyNode(self.inst, STRINGS.PIG_TALK_RUNAWAY_WILSON,
                RunAway(self.inst, "player", 3, 3)),
        },.5)
		
	-- Taken from wilsonbrain.lua
	local RUN_THRESH = 4.5
	local MAX_CHASE_TIME = 5
	local nonAIMode = PriorityNode(
    {
    	WhileNode(function() return TheInput:IsControlPressed(CONTROL_PRIMARY) end, "Hold LMB", ChaseAndAttack(self.inst, MAX_CHASE_TIME)),
    	ChaseAndAttack(self.inst, MAX_CHASE_TIME, nil, 1),
    },0)
		
	local root = 
        PriorityNode(
        {   
			-- Artifical Wilson Mode
			WhileNode(function() return self.inst:HasTag("ArtificalWilson") end, "AI Mode",
				-- Day or night, we have to eat				
			    day,
				dusk,
				night),
				
			-- Goes back to normal if this tag is removed
			WhileNode(function() return not self.inst:HasTag("ArtificalWilson") end, "Normal Mode",
			    nonAIMode)
        }, .5)
    
    self.bt = BT(self.inst, root)

end

return ArtificalBrain