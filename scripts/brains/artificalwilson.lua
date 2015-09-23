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

local MIN_SEARCH_DISTANCE = 15
local MAX_SEARCH_DISTANCE = 40
local SEARCH_SIZE_STEP = 5

-- The order in which we prioritize things to build
-- Stuff to be collected should follow the priority of the build order
-- Have things to build once, build many times, etc
-- Denote if we should always keep spare items (to build fire, etc)
local BUILD_PRIORITY = {}

-- What to gather. This is a simple FIFO. Highest priority will be first in the list.
local GATHER_LIST = {}
local function addToGatherList(_name, _prefab, _number)
	-- Group by name only. If we get a request to add something to the table with the same name and prefab type,
	-- ignore it
	for k,v in pairs(GATHER_LIST) do
		if v.prefab == _prefab and v.name == "name" then
			return
		end
	end
	
	-- New request for this thing. Add it. 
	local value = {name = _name, prefab = _prefab, number = _number}
	table.insert(GATHER_LIST,value)
end

-- Decrement from the FIRST prefab that matches this amount regardless of name
local function decrementFromGatherList(_prefab,_number)
	for k,v in pairs(GATHER_LIST) do
		if v.prefab == _prefab then
			v.number = v.number - _number
			if v.number <= 0 then
				GATHER_LIST[k] = nil
			end
			return
		end
	end
end

local function addRecipeToGatherList(thingToBuild, addFullRecipe)
	local recipe = GetRecipe(thingToBuild)
    if recipe then
		local player = GetPlayer()
        for ik, iv in pairs(recipe.ingredients) do
			-- TODO: This will add the entire recipe. Should modify based on current inventory
			if addFullRecipe then
				print("Adding " .. iv.amount .. " " .. iv.type .. " to GATHER_LIST")
				addToGatherList(iv.type,iv.amount)
			else
				-- Subtract what we already have
				-- TODO subtract what we can make as well... (man, this is complicated)
				local hasEnough = false
				local numHas = 0
				hasEnough, numHas = player.components.inventory:Has(iv.type,iv.amount)
				if not hasEnough then
					print("Adding " .. tostring(iv.amount-numHas) .. " " .. iv.type .. " to GATHER_LIST")
					addToGatherList(iv.type,iv.amount-numHas)
				end
			end
		end
    end
end
------------------------------------------------------------------------------------------------

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

local function ListenForScienceMachine(inst,data)
	if data and data.item.prefab == "researchlab" then
		print("The Science Machine has been built!!!")
		inst.components.homeseeker:SetHome(data.item)
		--if type(data.item.prefab) == "table" then
		--	for k,v in pairs(data.item.prefab) do
		--		print(k,v)
		--	end
		--else
		--	print(data.item.prefab)
		--end
	end
end

local function FindValidHome(inst)
	print("Find Valid Home")
	if not HasValidHome(inst) and inst.components.homeseeker then
		print("FindValidHome2")
		-- TODO: How to determine a good home. 
		-- For now, it's going to be the first place we build a science machine
		if inst.components.builder:CanBuild("researchlab") then
			-- Find some valid ground near us
			local pos = Vector3(inst.Transform:GetWorldPosition())
			local machinePos = nil
			if pos then
			    local theta = math.random() * 2 * PI
				local radius = 3
				local offset = FindWalkableOffset(pos, theta, radius, 12, true)
				if offset then
					machinePos = pos+offset
				end
			end
			
			if machinePos ~= nil then
				print("Found a valid place to build a science machine")
				inst.components.builder:DoBuild("researchlab",machinePos)
				-- This will push an event to set our home location
			else
				print("Could not find a place for a science machine")
			end
			
		end
		
	end
end

---------------------------------------------------------------------------
-- Gather stuff
local CurrentSearchDistance = MIN_SEARCH_DISTANCE
local function IncreaseSearchDistance()
	CurrentSearchDistance = math.min(MAX_SEARCH_DISTANCE,CurrentSearchDistance + SEARCH_SIZE_STEP)
end

local function ResetSearchDistance()
	CurrentSearchDistance = MIN_SEARCH_DISTANCE
end


local currentTreeOrRock = nil
local function OnFinishedWork(inst,target,action)
	currentTreeOrRock = nil
	inst:RemoveTag("DoingLongAction")
end

-- Some actions don't have a 'busy' stategraph. "DoingAction" is set whenever a BufferedAction
-- is scheduled and this callback will be triggered on both success and failure to denote 
-- we are done with that action
local function ActionDone(self, state)
	self:RemoveTag("DoingAction")
end

-- Adds our custom success and fail callback to a buffered action
local function SetupBufferedAction(inst, action)
	inst:AddTag("DoingAction")
	action:AddSuccessAction(function() inst:PushEvent("actionDone",{state="success"}) end)
	action:AddFailAction(function() inst:PushEvent("actionDone",{state="failed"}) end)
	return action	
end

-- Harvest Actions
--local CurrentActionSearchDistance = MIN_SEARCH_DISTANCE

local function FindTreeOrRockAction(inst, action, continue)

	if inst.sg:HasStateTag("busy") then
		return
	end
	
	-- Probably entered in the LoopNode. Don't swing mid swing.
	if inst:HasTag("DoingAction") then return end
	
	--print("FindTreeOrRock")
	
	-- We are currently chopping down a tree (or mining a rock). If it's still there...don't stop
	if currentTreeOrRock ~= nil and inst:HasTag("DoingLongAction") then
		-- Assume the tool in our hand is still the correct one. If we aren't holding anything, we're done
		local tool = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if not tool or not tool.components.tool:CanDoAction(currentTreeOrRock.components.workable.action) then
			currentTreeOrRock = nil
			inst:RemoveTag("DoingLongAction")
		else 
			inst:AddTag("DoingLongAction")
			return SetupBufferedAction(inst,BufferedAction(inst, currentTreeOrRock, currentTreeOrRock.components.workable.action))
		end
		
	else
		inst:RemoveTag("DoingLongAction")
		currentTreeOrRock = nil
	end
	
	-- Do we need logs? (always)
	-- Don't chop unless we need logs (this is hacky)
	if action == ACTIONS.CHOP and inst.components.inventory:Has("log",20) then
		return
	end
	
	-- This is super hacky too
	if action == ACTIONS.MINE and inst.components.inventory:Has("goldnugget",10) then
		return
	end
	
	-- TODO, this will find all mineable structures (ice, rocks, sinkhole)
	local target = FindEntity(inst, CurrentSearchDistance, function(item) return item.components.workable and item.components.workable.action == action end)
	
	if target then
		-- Found a tree...should we chop it?
		-- Check to see if axe is already equipped. If not, equip one
		local equiped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		local alreadyEquipped = false
		local axe = nil
		if equiped and equiped.components.tool and equiped.components.tool:CanDoAction(action) then
			axe = equiped
			alreadyEquipped = true
		else 
			axe = inst.components.inventory:FindItem(function(item) return item.components.equippable and item.components.tool and item.components.tool:CanDoAction(action) end)
		end
		-- We are holding an axe or have one in inventory. Let's chop
		if axe then
			if not alreadyEquipped then
				inst.components.inventory:Equip(axe)
			end
			ResetSearchDistance()
			currentTreeOrRock = target
			inst:AddTag("DoingLongAction")
			return SetupBufferedAction(inst,BufferedAction(inst, target, action))
			-- Craft one if we can
		else
			local thingToBuild = nil
			if action == ACTIONS.CHOP then
				thingToBuild = "axe"
			elseif action == ACTIONS.MINE then
				thingToBuild = "pickaxe"
			end
			
			if thingToBuild and inst.components.builder and inst.components.builder:CanBuild(thingToBuild) then
				inst.components.builder:DoBuild(thingToBuild)
				
			else
				--addRecipeToGatherList(thingToBuild,false)
			end
		end
	end
end


local function FindResourceToHarvest(inst)
	--print("FindResourceToHarvest")
	if inst.sg:HasStateTag("busy") then
		return
	end
	
	if not inst.components.inventory:IsFull() then
		local target = FindEntity(inst, CurrentSearchDistance, function(item)
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
			ResetSearchDistance()
			return SetupBufferedAction(inst,BufferedAction(inst,target,ACTIONS.PICK))
		end
	end
end

-- Do an expanding search. Look for things close first.

local function FindResourceOnGround(inst)

	--print("FindResourceOnGround")
	if inst.sg:HasStateTag("busy") then
		return
	end
	
	
	-- TODO: Check to see if it would stack
	if not inst.components.inventory:IsFull() then
		-- TODO: Only have up to 1 stack of the thing (modify the findentity fcn)
		local target = FindEntity(inst, CurrentSearchDistance, function(item) 
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
			ResetSearchDistance()
			return SetupBufferedAction(inst,BufferedAction(inst, target, ACTIONS.PICKUP))
		end
	end
end

-----------------------------------------------------------------------
-- Eating and stuff
local function HaveASnack(inst)
	--print("HaveASnack")
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
---------------------------------------------------------------------------------
-- COMBAT

-- Under these conditions, fight back. Else, run away
local function FightBack(inst)
	if inst.components.combat.target ~= nil then
		--print("Fight Back called with target " .. tostring(inst.components.combat.target.prefab))
		inst.components.combat.target:AddTag("TryingToKillUs")
	else
		inst:RemoveTag("FightBack")
		return
	end
	
	--print("FightBack")
	
	if inst.sg:HasStateTag("busy") then
		return
	end
	-- Do we want to fight this target? 
	-- What conditions would we fight under? Armor? Weapons? Hounds? etc
	
	-- Right now, the answer will be "YES, IT MUST DIE"
	
	-- First, check the distance to the target. This could be an old target that we've run away from. If so,
	-- clear the combat target fcn.

	-- Do we have a weapon
	local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	local allWeaponsInInventory = inst.components.inventory:FindItems(function(item) return item.components.weapon and item.components.equippable end)
	
	-- Sort by highest damage and equip that one. Replace the one in hands if higher
	local highestDamageWeapon = nil
	
	if equipped and equipped.components.weapon then
		highestDamageWeapon = equipped
	end
	for k,v in pairs(allWeaponsInInventory) do
		if highestDamageWeapon == nil then
			highestDamageWeapon = v
		else
			if v.components.weapon.damage > highestDamageWeapon.components.weapon.damage then
				highestDamageWeapon = v
			end
		end
	end
	
	-- We don't have any weapons!!!
	if highestDamageWeapon == nil then
		--print("Shit shit shit, no weapons")
		
		-- Can we make a spear? We'll equip it on the next visit to this function
		if inst.components.builder and inst.components.builder:CanBuild("spear") then
			inst.components.builder:DoBuild("spear")
		else
			-- Can't even build a spear! Abort abort!
			--addRecipeToGatherList("spear",false)
			inst:RemoveTag("FightBack")
			inst.components.combat:GiveUp()
		end
		
		-- Do not engage! 
		--inst:RemoveTag("FightBack")
		-- Also, set the target to nil? 
		
		return
	end
	
	-- Equip our best weapon
	if equipped ~= highestDamageWeapon and highestDamageWeapon ~= nil then
		inst.components.inventory:Equip(highestDamageWeapon)
	end
	
	inst:AddTag("FightBack")
	
end

function ArtificalBrain:OnStart()
	local clock = GetClock()
	
	self.inst:ListenForEvent("actionDone",function(inst,data) local state = nil if data then state = data.state end ActionDone(inst,state) end)
	self.inst:ListenForEvent("finishedwork", function(inst, data) OnFinishedWork(inst,data.target, data.action) end)
	self.inst:ListenForEvent("buildstructure", function(inst, data) ListenForScienceMachine(inst,data) end)  
	
	-- Things to do during the day
	local day = WhileNode( function() return clock and clock:IsDay() end, "IsDay",
		PriorityNode{
			RunAway(self.inst, "hostile", 15, 30),
			-- We've been attacked. Equip a weapon and fight back.
			IfNode( function() return self.inst.components.combat.target ~= nil end, "hastarget", 
				DoAction(self.inst,function() return FightBack(self.inst) end,"fighting",true)),
			WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst:HasTag("FightBack") end, "Fight Mode",
				ChaseAndAttack(self.inst,20)),
			-- This is if we don't want to fight what is attaking us. We'll run from it instead.
			RunAway(self.inst,"TryingToKillUs",10,20),
			
			-- If we started doing a long action, keep doing that action
			WhileNode(function() return self.inst:HasTag("DoingLongAction") end, "continueLongAction",
				LoopNode{
					DoAction(self.inst, function() return FindTreeOrRockAction(self.inst,nil,true) end, "continueAction", true)}),
			
			-- Make sure we eat
			DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true ),
			
			-- Find a good place to call home
			IfNode( function() return not HasValidHome(self.inst) end, "no home",
				DoAction(self.inst, function() return FindValidHome(self.inst) end, "looking for home", true)),

			-- Harvest stuff
			IfNode( function() return not self.inst.sg:HasStateTag("busy") and not self.inst:HasTag("DoingAction") end, "notBusy_goPickup",
				DoAction(self.inst, function() return FindResourceOnGround(self.inst) end, "pickup_ground", true )),			
			IfNode( function() return not self.inst.sg:HasStateTag("busy") and not self.inst:HasTag("DoingAction") end, "notBusy_goHarvest",
				DoAction(self.inst, function() return FindResourceToHarvest(self.inst) end, "harvest", true )),
			IfNode( function() return not self.inst.sg:HasStateTag("busy") and not self.inst:HasTag("DoingAction") end, "notBusy_goChop",
				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst, ACTIONS.CHOP) end, "chopTree", true)),
			IfNode( function() return not self.inst.sg:HasStateTag("busy") and not self.inst:HasTag("DoingAction") end, "notBusy_goMine",
				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst, ACTIONS.MINE) end, "mineRock", true)),
				
			-- Can't find anything to do...increase search distance
			DoAction(self.inst, function() return IncreaseSearchDistance() end,"lookingForStuffToDo", true),

			-- No plan...just walking around
			--Wander(self.inst, nil, 20),
		},.25)
		

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