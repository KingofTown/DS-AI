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
local MAX_SEARCH_DISTANCE = 100
local SEARCH_SIZE_STEP = 10
local RUN_AWAY_SEE_DIST = 6
local RUN_AWAY_STOP_DIST = 12
local CurrentSearchDistance = MIN_SEARCH_DISTANCE

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
---------------------------------------------------------------------------------
-- We will never gather stuff as long as its in this list.
-- Can add/remove from list whenever
local IGNORE_LIST = {}
local function OnIgnoreList(prefab)
	return IGNORE_LIST[prefab] ~= nil
end

local function AddToIgnoreList(prefab)
	IGNORE_LIST[prefab] = 1
end

local function RemoveFromIgnoreList(prefab)
	if OnIgnoreList(prefab) then
		IGNORE_LIST[prefab] = nil
	end
end

--------------------------------------------------------------------------------

-- Makes sure we have the right tech level.
-- If we don't have a resource, checks to see if we can craft it/them
-- If we can craft all necessary resources to build something, returns true
-- else, returns false
-- Do not set recursive variable, it will be set on recursive calls
local itemsNeeded = {}
local function CanIBuildThis(player, thingToBuild, numToBuild, recursive)

	-- Reset the table
	if recursive == nil then 
		for k,v in pairs(itemsNeeded) do itemsNeeded[k]=nil end
		recursive = 0
	end
	
	if numToBuild == nil then numToBuild = 1 end
	
	local recipe = GetRecipe(thingToBuild)
	
	-- Not a real thing so we can't possibly build this
	if not recipe then 
		print(thingToBuild .. " is not buildable :(")
		return false 
	end
	
	-- Quick check, do we know how to build this thing?
	if not player.components.builder:KnowsRecipe(thingToBuild) then 
		print("We don't know how to build " .. thingToBuild .. " :(")
		return false 
	end

	-- For each ingredient, check to see if we have it. If not, see if it's creatable
	for ik,iv in pairs(recipe.ingredients) do
		local hasEnough = false
		local numHas = 0
		local totalAmountNeeded = math.ceil(iv.amount*numToBuild)
		hasEnough, numHas = player.components.inventory:Has(iv.type,totalAmountNeeded)
		
		-- Subtract things already reserved from numHas
		for i,j in pairs(itemsNeeded) do
			if j.prefab == iv.type then
				numHas = math.max(0,numHas - 1)
			end
		end
		
		-- If we don't have or don't have enough for this ingredient, see if we can craft some more
		if numHas < totalAmountNeeded then
			local needed = totalAmountNeeded - numHas
			-- Before checking, add the current numHas to the table so the recursive
			-- call doesn't consider them valid.
			-- Make it level 0 as we already have this good.
			if numHas > 0 then
				table.insert(itemsNeeded,1,{prefab=iv.type,amount=numHas,level=0})
			end
			-- Recursive check...can we make this ingredient
			local canCraft = CanIBuildThis(player,iv.type,needed,recursive+1)
			if not canCraft then
				print("Need " .. tostring(needed) .. " " .. iv.type .. "s but can't make them")
				return false
			else
				-- We know the recipe to build this and have the goods. Add it to the list
				-- This should get added in the recursive case
				--table.insert(itemsNeeded,1,{prefab=iv.type, amount=needed, level=recursive, toMake=thingToBuild})
			end
		else
			-- We already have enough to build this resource. Add these to the list
			print("Adding " .. tostring(totalAmountNeeded) .. " of " .. iv.type .. " at level " .. tostring(recursive) .. " to the itemsNeeded list")
			table.insert(itemsNeeded,1,{prefab=iv.type, amount=totalAmountNeeded, level=recursive, toMake=thingToBuild, toMakeNum=numToBuild})
		end
	end
	
	-- We made it here, we can make this thingy
	return true
end

-- Should only be called after the above call to ensure we can build it.
local function BuildThis(player, thingToBuild, pos)
	local recipe = GetRecipe(thingToBuild)
	-- not a real thing
	if not recipe then return end
	
	for k,v in pairs(itemsNeeded) do print(k,v) end
	
	-- TODO: Make sure we have the inventory space! 
	for k,v in pairs(itemsNeeded) do
		-- Just go down the list. If level > 0, we need to build it
		if v.level > 0 and v.toMake then
			-- We should be able to build this...
			print("Trying to build " .. v.toMake)
			while v.toMakeNum > 0 do 
				if player.components.builder:CanBuild(v.toMake) then
					--player.components.builder:DoBuild(v.toMake)
					local action = BufferedAction(player,player,ACTIONS.BUILD,nil,pos,v.toMake,nil)
					player:PushBufferedAction(action)
					v.toMakeNum = v.toMakeNum - 1
				else
					print("Uhh...we can't make " .. v.toMake .. "!!!")
					return
				end
			end
		end
	end
	
	-- We should have everything we need
	if player.components.builder:CanBuild(thingToBuild) then
		--player.components.builder:DoBuild(thingToBuild,pos)
		local action = BufferedAction(player,player,ACTIONS.BUILD,nil,pos,thingToBuild,nil)
		player:PushBufferedAction(action)
	else
		print("Something is messed up. We can't make " .. thingToBuild .. "!!!")
	end
end

-- Finds things we can prototype and does it.
-- TODO, should probably get a prototype order list somewhere...
local function PrototypeStuff(inst)


end

-- Returns a point somewhere near thing at a distance dist
local function GetPointNearThing(thing, dist)
	local pos = Vector3(thing.Transform:GetWorldPosition())

	if pos then
		local theta = math.random() * 2 * PI
		local radius = dist
		local offset = FindWalkableOffset(pos, theta, radius, 12, true)
		if offset then
			return pos+offset
		end
	end
end

------------------------------------------------------------------------------------------------

local ArtificalBrain = Class(Brain, function(self, inst)
    Brain._ctor(self,inst)
end)

-- Some actions don't have a 'busy' stategraph. "DoingAction" is set whenever a BufferedAction
-- is scheduled and this callback will be triggered on both success and failure to denote 
-- we are done with that action
local function ActionDone(self, data)
	local state = data.state
	local theAction = data.theAction

	if theAction and state then 
		print("Action: " .. theAction:__tostring() .. " [" .. state .. "]")
	else
		print("Action Done")
	end

	-- Cancel the DoTaskInTime for this event
	if self.currentAction ~= nil then
		self.currentAction:Cancel()
		self.currentAction=nil
	end

	if state and state == "watchdog" then
		print("Watchdog triggered on action " .. self.currentBufferedAction:__tostring())
		self:RemoveTag("DoingLongAction")
		self:AddTag("IsStuck")
		-- Really should remove this entity from being selected again. It will just live on forever
	end
	
	self:RemoveTag("DoingAction")
end

-- Make him execute a 'RunAway' action to try to fix his angle?
local function FixStuckWilson(inst)
	-- Just reset the whole behaviour tree...that will get us unstuck
	inst.brain.bt:Reset()
	inst:RemoveTag("IsStuck")
end

-- Adds our custom success and fail callback to a buffered action
-- actionNumber is for a watchdog node

local MAX_TIME_FOR_ACTION_SECONDS = 10
local function SetupBufferedAction(inst, action)
	inst:AddTag("DoingAction")
	inst.currentAction = inst:DoTaskInTime((CurrentSearchDistance/2)+3,function() ActionDone(inst, {theAction = action, state="watchdog"}) end)
	inst.currentBufferedAction = action
	action:AddSuccessAction(function() inst:PushEvent("actionDone",{theAction = action, state="success"}) end)
	action:AddFailAction(function() inst:PushEvent("actionDone",{theAction = action, state="failed"}) end)
	print(action:__tostring())
	return action	
end

--------------------------------------------------------------------------------
-- MISC one time stuff (activate things)

local function FindAndActivateTouchstone(inst)
	
	local target = FindEntity(inst, 25, function(item) return item.components.resurrector and 
									item.components.activatable and item.components.activatable.inactive end)
	if target then
		return SetupBufferedAction(inst,BufferedAction(inst,target,ACTIONS.ACTIVATE))
	end

end

-----------------------------------------------------------------------
-- Inventory Management

-- Stuff to do when our inventory is full
-- Eat more stuff
-- Drop useless stuff
-- Craft stuff?
-- Make a chest? 
-- etc
local function ManageInventory(inst)

end

-- Eat health restoring food
-- Put health items on top of priority list when health is low
local function ManageHealth(inst)
	if inst.sg:HasStateTag("busy") then
		return
	end
	-- Don't waste time if over 75% health
	if inst.components.health:GetPercent() > .75 then return end
	
	-- Do not try to do this while in combat
	if inst:HasTag("FightBack") or inst.components.combat.target ~= nil then return end
	
	-- Do not try to do this while running away
	-- TODO
	
	local healthMissing = inst.components.health:GetMaxHealth() - inst.components.health.currenthealth
	
	-- Do we have edible food? 
	local bestFood = nil
	-- If we have food that restores health, eat it
	local healthFood = inst.components.inventory:FindItems(function(item) return inst.components.eater:CanEat(item) and item.components.edible:GetHealth(inst) > 0 end)
	
	-- Find the best food that doesn't go over and eat that.
	-- TODO: Sort by staleness
	for k,v in pairs(healthFood) do
		local h = v.components.edible:GetHealth(inst)
		-- Only consider foods that heal for less than hunger if we are REALLY hurting
		local z = v.components.edible:GetHunger(inst)
		
		-- h > z, this item is better used as healing
		-- or heals for more than 5 and we are really hurting
		if h > z or (h <= z and  h >= 5 and inst.components.health:GetPercent() < .2) then
			if h <= healthMissing then
				if not bestFood or (bestFood and bestFood.components.edible:GetHealth(inst) < h) then
					bestFood = v
				end
			end
		end
	end
	
	if bestFood then
		return SetupBufferedAction(inst,BufferedAction(inst,bestFood,ACTIONS.EAT))
	end
	
	-- Out of food. Do we have any other healing items?
	local healthItems = inst.components.inventory:FindItems(function(item) return item.components.healer end)
	
	local bestHealthItem = nil
	for k,v in pairs(healthItems) do 
		local h = v.components.healer.health
		if h <= healthMissing then
			if not bestHealthItem or (bestHealthItem and bestHealthItem.components.healer.health < h) then
				bestHealthItem = v
			end
		end
	end
	
	if bestHealthItem then
		print("Healing with " .. bestHealthItem.prefab)
		return SetupBufferedAction(inst,BufferedAction(inst,inst,ACTIONS.HEAL,bestHealthItem))
	end
	
	-- Got this far...we're out of stuff. Add stuff to the priority list!
	-- TODO!!!
end

-- Eat sanity restoring food
-- Put sanity things on top of list when sanity is low
local function ManageSanity(inst)

end


-----------------------------------------------------------------------
-- Go home stuff
local function HasValidHome(inst)
    return inst.components.homeseeker and 
       inst.components.homeseeker.home and 
       inst.components.homeseeker.home:IsValid()
end

local function GoHomeAction(inst)
    if  HasValidHome(inst) and
        not inst.components.combat.target then
			inst.components.homeseeker:GoHome(true)
    end
end

local function GetHomePos(inst)
    return HasValidHome(inst) and inst.components.homeseeker:GetHomePos()
end

local function AtHome(inst)
	-- Am I close enough to my home position?
	if not HasValidHome(inst) then return false end
	local dist = inst:GetDistanceSqToPoint(GetHomePos(inst))
	return dist < 10
end

-- Should keep track of what we build so we don't have to keep checking. 
local function ListenForScienceMachine(inst,data)
	if data and data.item.prefab == "researchlab" then
		inst.components.homeseeker:SetHome(data.item)
	end
end

local function FindValidHome(inst)

	if not HasValidHome(inst) and inst.components.homeseeker then

		-- TODO: How to determine a good home. 
		-- For now, it's going to be the first place we build a science machine
		if inst.components.builder:CanBuild("researchlab") then
			-- Find some valid ground near us
			local machinePos = GetPointNearThing(inst,3)		
			if machinePos ~= nil then
				print("Found a valid place to build a science machine")
				--return SetupBufferedAction(inst, BufferedAction(inst,inst,ACTIONS.BUILD,nil,machinePos,"researchlab",nil))
				local action = BufferedAction(inst,inst,ACTIONS.BUILD,nil,machinePos,"researchlab",nil)
				inst:PushBufferedAction(action)
				
				-- Can we also make a backpack while we are here?
				if CanIBuildThis(inst,"backpack") then
					BuildThis(inst,"backpack")
				end
			
			--	inst.components.builder:DoBuild("researchlab",machinePos)
			--	-- This will push an event to set our home location
			--	-- If we can, make a firepit too
			--	if inst.components.builder:CanBuild("firepit") then
			--		local pitPos = GetPointNearThing(inst,6)
			--		inst.components.builder:DoBuild("firepit",pitPos)
			--	end
			else
				print("Could not find a place for a science machine")
			end
		end
		
	end
end

---------------------------------------------------------------------------
-- Gather stuff

local function IncreaseSearchDistance()
	print("IncreaseSearchDistance")
	CurrentSearchDistance = math.min(MAX_SEARCH_DISTANCE,CurrentSearchDistance + SEARCH_SIZE_STEP)
end

local function ResetSearchDistance()
	CurrentSearchDistance = MIN_SEARCH_DISTANCE
end


local currentTreeOrRock = nil
local function OnFinishedWork(inst,data)
	print("Work finished on " .. data.target.prefab)
	currentTreeOrRock = nil
	inst:RemoveTag("DoingLongAction")
end


-- Harvest Actions
-- TODO: Implement this 
local function FindHighPriorityThings(inst)
    --local ents = TheSim:FindEntities(x,y,z, radius, musttags, canttags, mustoneoftags)
	local p = Vector3(inst.Transform:GetWorldPosition())
	if not p then return end
	-- Get ALL things around us
	local things = FindEntities(p.x,p.y,p.z, CurrentSearchDistance/2, nil, {"player"})
	
	local priorityItems = {}
	for k,v in pairs(things) do
		if v ~= inst and v.entity:IsValid() and v.entity:IsVisible() then
			if IsInPriorityTable(v) then
				table.insert(priorityItems,v)
			end
		end
	end
	
	-- Filter out stuff
end



local function FindTreeOrRockAction(inst, action, continue)

	if inst.sg:HasStateTag("busy") then
		return
	end

	-- We are currently chopping down a tree (or mining a rock). If it's still there...don't stop
	if continue and currentTreeOrRock ~= nil and inst:HasTag("DoingLongAction") then
		-- Assume the tool in our hand is still the correct one. If we aren't holding anything, we're done
		local tool = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if not tool or not tool.components.tool:CanDoAction(currentTreeOrRock.components.workable.action) then
			print("We can't continue this action!")
			currentTreeOrRock = nil
			inst:RemoveTag("DoingLongAction")
		else 
			inst:AddTag("DoingLongAction")
			print("Continue long action")
			return SetupBufferedAction(inst,BufferedAction(inst, currentTreeOrRock, currentTreeOrRock.components.workable.action))
		end
		
	else
		--print("Not doing long action")
		inst:RemoveTag("DoingLongAction")
		currentTreeOrRock = nil
	end
	
	-- Do we need logs? (always)
	-- Don't chop unless we need logs (this is hacky)
	if action == ACTIONS.CHOP and inst.components.inventory:Has("log",20) then
		return
	end

	
	-- TODO, this will find all mineable structures (ice, rocks, sinkhole)
	local target = FindEntity(inst, CurrentSearchDistance, function(item)
			if not item.components.workable then return false end
			if not item.components.workable:IsActionValid(action) then return false end
			
			-- TODO: Put ignored prefabs
			if OnIgnoreList(item.prefab) then return false end
			
			-- Skip this if it only drops stuff we are full of
			-- TODO, get the lootdroper rather than knowing what prefab it is...
			if item.prefab and item.prefab == "rock1" then
				return not inst.components.inventory:Has("flint",20)
			elseif item.prefab and item.prefab == "rock2" then
				return not inst.components.inventory:Has("goldnugget",20)
			elseif item.prefab and item.prefab == "rock_flintless" then
				return not inst.components.inventory:Has("rocks",40)
			end

			-- TODO: Determine if this is across water or something...
			--local dist = inst:GetDistanceSqToInst(item)
			--if dist > (CurrentSearchDistance) then 
			--	return false
			--end
			
			-- Found one
			return true
	
		end)
	
	if target then
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
				--inst.components.builder:DoBuild(thingToBuild)
				local action = BufferedAction(inst,inst,ACTIONS.BUILD,nil,nil,thingToBuild,nil)
				inst:PushBufferedAction(action)
				inst:AddTag("DoingLongAction")
				currentTreeOrRock = target
			else
				--addRecipeToGatherList(thingToBuild,false)
			end
		end
	end
end


local function FindResourceToHarvest(inst)
	--print("FindResourceToHarvest")
	--if not inst.components.inventory:IsFull() then
		local target = FindEntity(inst, CurrentSearchDistance, function(item)
					
					if item.components.pickable and item.components.pickable:CanBePicked() and item.components.pickable.caninteractwith then
						local theProductPrefab = item.components.pickable.product
						if theProductPrefab == nil then
							return false
						end
						
						-- If we have some of this product, it will override the isFull check
						local haveItem = inst.components.inventory:FindItem(function(invItem) return theProductPrefab == invItem.prefab end)
						
						if OnIgnoreList(item.components.pickable.product) or item:HasTag("TempTagForStuck") then
							return false
						end
						-- Check to see if we have a full stack of this item
						local theProduct = inst.components.inventory:FindItem(function(item) return (item.prefab == theProductPrefab) end)
						if theProduct then
							-- If we don't have a full stack of this...then pick it up (if not stackable, we will hold 2 of them)
							return not inst.components.inventory:Has(theProductPrefab,theProduct.components.stackable and theProduct.components.stackable.maxsize or 2)
						else
							-- Don't have any of this...lets get some (only if we have room)						
							return not inst.components.inventory:IsFull()
						end
					end
					-- Default case...probably not harvest-able. Return false.
					return false
				end)

		if target then
			ResetSearchDistance()
			return SetupBufferedAction(inst,BufferedAction(inst,target,ACTIONS.PICK))
		end
	--end
end

-- Do an expanding search. Look for things close first.

local function FindResourceOnGround(inst)
	--print("FindResourceOnGround")

	-- TODO: Only have up to 1 stack of the thing (modify the findentity fcn)
	local target = FindEntity(inst, CurrentSearchDistance, function(item)
						-- Do we have a slot for this already
						local haveItem = inst.components.inventory:FindItem(function(invItem) return item.prefab == invItem.prefab end)
											
						-- TODO: Need to find out if this is across a river or something...
						--local dist = inst:GetDistanceSqToInst(item)
						--if dist > (CurrentSearchDistance*CurrentSearchDistance) then
						--	print("Skipping " .. item.prefab .. " as it's too far: [" .. dist .. ", " .. CurrentSearchDistance .. "]")
						--	return false
						--end
						
						-- Ignore these dang trinkets
						if item.prefab and string.find(item.prefab, "trinket") then return false end
						-- We won't need these thing either.
						if item.prefab and string.find(item.prefab, "teleportato") then return false end
			
						if item.components.inventoryitem and 
							item.components.inventoryitem.canbepickedup and 
							not item.components.inventoryitem:IsHeld() and
							item:IsOnValidGround() and
							-- Ignore things we have a full stack of
							not inst.components.inventory:Has(item.prefab, item.components.stackable and item.components.stackable.maxsize or 2) and
							-- Ignore this unless it fits in a stack
							not (inst.components.inventory:IsFull() and haveItem == nil) and
							not OnIgnoreList(item.prefab) and
							not item:HasTag("prey") and
							not item:HasTag("bird") and
							not item:HasTag("TempTagForStuck") then
								return true
						end
					end)
	if target then
		ResetSearchDistance()
		return SetupBufferedAction(inst,BufferedAction(inst, target, ACTIONS.PICKUP))
	end

end

-----------------------------------------------------------------------
-- Eating and stuff
local function HaveASnack(inst)
		
	-- Check inventory for food. 
	-- If we have none, set the priority item to find to food (TODO)
	local allFoodInInventory = inst.components.inventory:FindItems(function(item) return 
									inst.components.eater:CanEat(item) and 
									item.components.edible:GetHunger(inst) > 0 and
									item.components.edible:GetHealth(inst) >= 0 and
									item.components.edible:GetSanity(inst) >= 0 end)
	
	
	
	local bestFoodToEat = nil
	for k,v in pairs(allFoodInInventory) do
		if bestFoodToEat == nil then
			bestFoodToEat = v
		else
			print("Comparing " .. v.prefab .. " to " .. bestFoodToEat.prefab)
			if v.components.edible:GetHunger(inst) >= bestFoodToEat.components.edible:GetHunger(inst) then
				print(v.prefab .. " gives more hunger!")
				-- If it's tied, order by perishable percentage
				local newWillPerish = v.components.perishable
				local curWillPerish = bestFoodToEat.components.perishable
				if newWillPerish and not curWillPerish then
					print("...and will perish")
					bestFoodToEat = v
				elseif newWillPerish and curWillPerish and newWillPerish:GetPercent() < curWillPerish:GetPercent() then
					print("...and will perish sooner")
					bestFoodToEat = v
				else
					print("...but " .. bestFoodToEat.prefab .. " will spoil sooner so not changing")
					-- Keep the original...it will go stale before this one. 
				end
			else
				-- The new food will provide less hunger. Only consider this if it is close to going stale or going
				-- really bad
				if v.components.perishable then
					-- Stale happens at .5, so we'll get things between .5 and .6
					if v.components.perishable:IsFresh() and v.components.perishable:GetPercent() < .6 then
						print(v.prefab .. " isn't better...but is close to going stale")
						bestFoodToEat = v
					-- Likewise, next phase is at .2, so get things between .2 and .3
					elseif v.components.perishable:IsStale() and v.components.perishable:GetPercent() < .3 then
						print(v.prefab .. " isn't better...but is close to going bad")
						bestFoodToEat = v
					end
				end
			end
		end
	end
	
	if bestFoodToEat then 
		return SetupBufferedAction(inst,BufferedAction(inst,bestFoodToEat,ACTIONS.EAT))
	end
	
	-- We didn't find anything good. Check food that might hurt us if we are real hungry
	if inst.components.hunger:GetPercent() > .15 then 
		return 
	end
	print("We're too hungry. Check emergency reserves!")
	
	allFoodInInventory = inst.components.inventory:FindItems(function(item) return 
									inst.components.eater:CanEat(item) and 
									item.components.edible:GetHunger(inst) > 0 and
									item.components.edible:GetHealth(inst) < 0 end)
									
	for k,v in pairs(allFoodInInventory) do
		local health = v.components.edible:GetHealth(inst)
		if not bestFoodToEat and health > inst.components.health.currenthealth then 
			bestFoodToEat = v
		elseif bestFoodToEat and health > inst.components.health.currenthealth then
			if v.components.edible:GetHunger(inst) > bestFoodToEat.components.edible:GetHunger(inst) and 
				health <= bestFoodToEat.components.edible:GetHealth(inst) and
				health > inst.components.health.currenthealth then
					bestFoodToEat = v
			end
		end
	end
	
	if bestFoodToEat then 
		return SetupBufferedAction(inst,BufferedAction(inst,bestFoodToEat,ACTIONS.EAT))
	end
	
	
	-- TODO:
	-- We didn't find antying to eat and we're hungry. Set our priority to finding food!

end
---------------------------------------------------------------------------------
-- COMBAT

-- Things to pretty much always run away from
-- TODO: Make this a dynamic list
local function ShouldRunAway(guy)
	return guy:HasTag("WORM_DANGER") or guy:HasTag("guard")
end

-- Under these conditions, fight back. Else, run away
local function FightBack(inst)
	if inst.components.combat.target ~= nil then
		print("Fight Back called with target " .. tostring(inst.components.combat.target.prefab))
		inst.components.combat.target:AddTag("TryingToKillUs")
	else
		inst:RemoveTag("FightBack")
		return
	end

	-- This has priority. 
	inst:RemoveTag("DoingAction")
	inst:RemoveTag("DoingLongAction")
	
	if inst.sg:HasStateTag("busy") then
		return
	end
	
	-- If it's on the do_not_engage list, just run! Not sure how it got us, but it did.
	if ShouldRunAway(inst) then return end
	
	-- If we're close to dead...run away
	if inst.components.health:GetPercent() < .35 then return end
	
	-- All things seem to fight in groups. Count the number of like mobs near this mob. If more than 2, runaway!
	local pos = Vector3(inst.Transform:GetWorldPosition())
	local likeMobs = TheSim:FindEntities(pos.x,pos.y,pos.z, 6)
	local numTargets = 0
	for k,v in pairs(likeMobs) do 
		if v.prefab == inst.components.combat.target.prefab then
			numTargets = numTargets + 1
			v:AddTag("TryingToKillUs")
		end
	end
	
	if numTargets > 3 then
		print("Too many! Run away!")
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
	
	-- If we don't have at least a spears worth of damage, make a spear
	if (highestDamageWeapon and highestDamageWeapon.components.weapon.damage < 34) or highestDamageWeapon == nil then
		--print("Shit shit shit, no weapons")
		
		-- Can we make a spear? We'll equip it on the next visit to this function
		if inst.components.builder and CanIBuildThis(inst, "spear") then
			BuildThis(inst,"spear")
		else
			-- Can't build a spear. If we don't have ANYTHING, run away!
			if highestDamageWeapon == nil then
				-- Can't even build a spear! Abort abort!
				--addRecipeToGatherList("spear",false)
				inst:RemoveTag("FightBack")
				inst.components.combat:GiveUp()
				return
			end
			print("Can't build a spear. I'm using whatever I've got!")
		end
	end
	
	
	-- Equip our best weapon (before armor incase its in our backpack)
	if equipped ~= highestDamageWeapon and highestDamageWeapon ~= nil then
		inst.components.inventory:Equip(highestDamageWeapon)
	end
	
	-- We're gonna fight. Do we have armor that's not equiped?
	if not inst.components.inventory:IsWearingArmor() then
		-- Do we have any? Equip the one with the highest value
		-- Else, try to make some (what order should I make it in?)
		local allArmor = inst.components.inventory:FindItems(function(item) return item.components.armor end)
		
		-- Don't have any. Can we make some?
		if #allArmor == 0 then
			print("Don't own armor. Can I make some?")
			-- TODO: Make this from a lookup table or something.
			if CanIBuildThis(inst,"armorwood") then
				BuildThis(inst,"armorwood")
			elseif CanIBuildThis(inst,"armorgrass") then
				BuildThis(inst,"armorgrass")
			end
		end
		
		-- Do another lookup
		allArmor = inst.components.inventory:FindItems(function(item) return item.components.armor end)
		local highestArmorValue = nil
		for k,v in pairs(allArmor) do 
			if highestArmorValue == nil and v.components.armor.absorb_percent then 
				highestArmorValue = v
			else
				if v.components.armor.absorb_percent and 
				v.components.armor.absorb_percent > highestArmorValue.components.armor.absorb_persent then
					highestArmorValue = v
				end
			end
		end
		
		if highestArmorValue then
			-- TODO: Need to pick up backpack once we make one
			inst.components.inventory:Equip(highestArmorValue)
		end
	end
	
	inst:AddTag("FightBack")
end
----------------------------- End Combat ---------------------------------------


local function IsNearLightSource(inst)
	local source = GetClosestInstWithTag("lightsource", inst, 20)
	if source then
		local dsq = inst:GetDistanceSqToInst(source)
		if dsq > 8 then
			print("It's too far away!")
			return false 
		end
		
		-- Find the source of the light
		local parent = source.entity:GetParent()
		if parent then
			if parent.components.fueled and parent.components.fueled:GetPercent() < .25 then
				return false
			end
		end
		-- Source either has no parent or doesn't need fuel. We're good.
		return true
	end

	return false
end

local function MakeLightSource(inst)
	-- If there is one nearby, move to it
	print("Need to make light!")
	local source = GetClosestInstWithTag("lightsource", inst, 30)
	if source then
		print("Found a light source")
		local dsq = inst:GetDistanceSqToInst(source)
		if dsq >= 15 then
			local pos = GetPointNearThing(source,2)
			if pos then
				inst.components.locomotor:GoToPoint(pos,nil,true)
			end
		end
		
		local parent = source.entity:GetParent()
		if parent and not parent.components.fueled then	
			return 		
		end

	end
	
	-- 1) Check for a firepit to add fuel
	local firepit = GetClosestInstWithTag("campfire",inst,15)
	if firepit then
		-- It's got fuel...nothing to do
		if firepit.components.fueled:GetPercent() > .25 then 
			return
		end
		
		-- Find some fuel in our inventory to add
		local allFuelInInv = inst.components.inventory:FindItems(function(item) return item.components.fuel and 
																				not item.components.armor and
																				item.prefab ~= "livinglog" and
																				firepit.components.fueled:CanAcceptFuelItem(item) end)
		
		-- Add some fuel to the fire.
		local bestFuel = nil
		for k,v in pairs(allFuelInInv) do
			-- TODO: This is a bit hackey...but really, logs are #1
			if v.prefab == "log" then
				return BufferedAction(inst, firepit, ACTIONS.ADDFUEL, v)
			else
				bestFuel = v
			end
		end
		-- Don't add this stuff unless the fire is really sad
		if bestFuel and firepit.components.fueled:GetPercent() < .15 then
			return BufferedAction(inst, firepit, ACTIONS.ADDFUEL, bestFuel)
		end
		
		-- We don't have enough fuel. Let it burn longer before executing backup plan
		if firepit.components.fueled:GetPercent() > .1 then return end
	end
	
	-- No firepit (or no fuel). Can we make one?
	if inst.components.builder:CanBuild("campfire") then
		-- Don't build one too close to burnable things. 
		local burnable = GetClosestInstWithTag("burnable",inst,3)
		local pos = nil
		if burnable then
			print("Don't want to build campfire too close")
			pos = GetPointNearThing(burnable,3)
		end
		--inst.components.builder:DoBuild("campfire",pos)
		local action = BufferedAction(inst,inst,ACTIONS.BUILD,nil,pos,"campfire",nil)
		inst:PushBufferedAction(action)
		return
	end
	
	-- Can't make a campfire...torch it is (hopefully)
	
	local haveTorch = inst.components.inventory:FindItem(function(item) return item.prefab == "torch" end)
	if not haveTorch then
		-- Need to make one!
		if inst.components.builder:CanBuild("torch") then
			--inst.components.builder:DoBuild("torch")
			local action = BufferedAction(inst,inst,ACTIONS.BUILD,nil,nil,"torch",nil)
			inst:PushBufferedAction(action)
		end
	end
	-- Find it again
	haveTorch = inst.components.inventory:FindItem(function(item) return item.prefab == "torch" end)
	if haveTorch then
		inst.components.inventory:Equip(haveTorch)
		return
	end
	
	-- Uhhh....we couldn't add fuel and we didn't have a torch. Find fireflys? 
	print("Shit shit shit, it's dark!!!")
	local lastDitchEffort = GetClosestInstWithTag("lightsource", inst, 50)
	if lastDitchEffort then
		local pos = GetPointNearThing(lastDitchEffort,2)
		if pos then
			inst.components.locomotor:GoToPoint(pos,nil,true)
		end
	else
		print("So...this is how I die")
	end

end

local function MakeTorchAndKeepRunning(inst)
	local haveTorch = inst.components.inventory:FindItem(function(item) return item.prefab == "torch" end)
	if not haveTorch then
		-- Need to make one!
		if inst.components.builder:CanBuild("torch") then
			--inst.components.builder:DoBuild("torch")
			local action = BufferedAction(inst,inst,ACTIONS.BUILD,nil,nil,"torch",nil)
			inst:PushBufferedAction(action)
		end
	end
	-- Find it again
	haveTorch = inst.components.inventory:FindItem(function(item) return item.prefab == "torch" end)
	if haveTorch then
		inst.components.inventory:Equip(haveTorch)
	end
	
	-- OK, have a torch. Run home!
	if  haveTorch and HasValidHome(inst) and
        not inst.components.combat.target then
			inst.components.homeseeker:GoHome(true)
    end
	
end

local function IsNearCookingSource(inst)
	local cooker = GetClosestInstWithTag("campfire",inst,10)
	if cooker then return true end
end

local function CookSomeFood(inst)
	local cooker = GetClosestInstWithTag("campfire",inst,10)
	if cooker then
		-- Find food in inventory that we can cook.
		local cookableFood = inst.components.inventory:FindItems(function(item) return item.components.cookable end)
		
		for k,v in pairs(cookableFood) do
			-- Don't cook this unless we have a free space in inventory or this is a single item or the product is in our inventory
			local has, numfound = inst.components.inventory:Has(v.prefab,1)
			local theProduct = inst.components.inventory:FindItem(function(item) return (item.prefab == v.components.cookable.product) end)
			local canFillStack = false
			if theProduct then
				canFillStack = not inst.components.inventory:Has(v.components.cookable.product,theProduct.components.stackable.maxsize)
			end

			if not inst.components.inventory:IsFull() or numfound == 1 or (theProduct and canFillStack) then
				return SetupBufferedAction(inst,BufferedAction(inst,cooker,ACTIONS.COOK,v))
			end
		end
	end
end

--------------------------------------------------------------------------------

local function MidwayThroughDusk()
	local clock = GetClock()
	local startTime = clock:GetDuskTime()
	return clock:IsDusk() and (clock:GetTimeLeftInEra() < startTime/4)
end

local function IsBusy(inst)
	return inst.sg:HasStateTag("busy") or inst:HasTag("DoingAction")
end


local function OnHitFcn(inst,data)
	inst.components.combat:SetTarget(data.attacker)
end


function ArtificalBrain:OnStop()
	print("Stopping the brain!")
	self.inst:RemoveEventCallback("actionDone",ActionDone)
	self.inst:RemoveEventCallback("finishedwork", OnFinishedWork)
	self.inst:RemoveEventCallback("buildstructure", ListenForScienceMachine)
	self.inst:RemoveEventCallback("attacked", OnHitFcn)
	self.inst:RemoveTag("DoingLongAction")
	self.inst:RemoveTag("DoingAction")
end

function ArtificalBrain:OnStart()
	local clock = GetClock()
	
	self.inst:ListenForEvent("actionDone",ActionDone)
	self.inst:ListenForEvent("finishedwork", OnFinishedWork)
	self.inst:ListenForEvent("buildstructure", ListenForScienceMachine)
	self.inst:ListenForEvent("attacked", OnHitFcn)
	
	-- TODO: Make this a brain function so we can manage it dynamically
	AddToIgnoreList("seeds")
	AddToIgnoreList("petals_evil")
	AddToIgnoreList("marsh_tree")
	AddToIgnoreList("marsh_bush")
	AddToIgnoreList("tallbirdegg")
	
	-- If we don't have a home, find a science machine in the world and make that our home
	if not HasValidHome(self.inst) then
		local scienceMachine = FindEntity(self.inst, 10000, function(item) return item.prefab and item.prefab == "researchlab" end)
		if scienceMachine then
			print("Found our home!")
			self.inst.components.homeseeker:SetHome(scienceMachine)
		end
	end
	
	-- Things to do during the day
	local day = WhileNode( function() return clock and clock:IsDay() end, "IsDay",
		PriorityNode{
			--RunAway(self.inst, "hostile", 15, 30),
			-- We've been attacked. Equip a weapon and fight back.
			
			-- Moved these to root
			--IfNode( function() return self.inst.components.combat.target ~= nil end, "hastarget", 
			--	DoAction(self.inst,function() return FightBack(self.inst) end,"fighting",true)),
			--WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst:HasTag("FightBack") end, "Fight Mode",
			--	ChaseAndAttack(self.inst,20)),
			
			-- If we started doing a long action, keep doing that action
			WhileNode(function() return self.inst.sg:HasStateTag("working") and (self.inst:HasTag("DoingLongAction") and currentTreeOrRock ~= nil) end, "continueLongAction",

				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst,nil,true) end, "continueAction", true) 	),
			
			-- Make sure we eat
			IfNode( function() return not IsBusy(self.inst) and  self.inst.components.hunger:GetPercent() < .5 end, "notBusy_hungry",
				DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true )),
				
			-- If there's a touchstone nearby, activate it
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_lookforTouchstone",
				DoAction(self.inst,function() return FindAndActivateTouchstone(self.inst) end, "findTouchstone", true)),
			
			-- Find a good place to call home
			IfNode( function() return not HasValidHome(self.inst) end, "no home",
				DoAction(self.inst, function() return FindValidHome(self.inst) end, "looking for home", true)),

			-- Collect stuff
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goPickup",
				DoAction(self.inst, function() return FindResourceOnGround(self.inst) end, "pickup_ground", true )),			
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goHarvest",
				DoAction(self.inst, function() return FindResourceToHarvest(self.inst) end, "harvest", true )),
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goChop",
				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst, ACTIONS.CHOP, false) end, "chopTree", true)),
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goMine",
				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst, ACTIONS.MINE, false) end, "mineRock", true)),
				
			-- Can't find anything to do...increase search distance
			IfNode( function() return not IsBusy(self.inst) end, "nothing_to_do",
				DoAction(self.inst, function() return IncreaseSearchDistance() end,"lookingForStuffToDo", true)),
				

			-- No plan...just walking around
			--Wander(self.inst, nil, 20),
		},.5)
		

	-- Do this stuff the first half of duck (or all of dusk if we don't have a home yet)
	local dusk = WhileNode( function() return clock and clock:IsDusk() and (not MidwayThroughDusk() or not HasValidHome(self.inst)) end, "IsDusk",
        PriorityNode{

			-- Moved these to root
			-- We've been attacked. Equip a weapon and fight back.
			--IfNode( function() return self.inst.components.combat.target ~= nil end, "hastarget", 
			--	DoAction(self.inst,function() return FightBack(self.inst) end,"fighting",true)),
			--WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst:HasTag("FightBack") end, "Fight Mode",
			--	ChaseAndAttack(self.inst,20)),
			
			-- If we started doing a long action, keep doing that action
			WhileNode(function() return self.inst.sg:HasStateTag("working") and (self.inst:HasTag("DoingLongAction") and currentTreeOrRock ~= nil) end, "continueLongAction",
					DoAction(self.inst, function() return FindTreeOrRockAction(self.inst,nil,true) end, "continueAction", true)	),
			
			-- Make sure we eat
			IfNode( function() return not IsBusy(self.inst) and  self.inst.components.hunger:GetPercent() < .5 end, "notBusy_hungry",
				DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true )),
			
			-- Find a good place to call home
			IfNode( function() return not HasValidHome(self.inst) end, "no home",
				DoAction(self.inst, function() return FindValidHome(self.inst) end, "looking for home", true)),

			-- Harvest stuff
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goPickup",
				DoAction(self.inst, function() return FindResourceOnGround(self.inst) end, "pickup_ground", true )),		
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goChop",
				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst, ACTIONS.CHOP) end, "chopTree", true)),	
				
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goHarvest",
				DoAction(self.inst, function() return FindResourceToHarvest(self.inst) end, "harvest", true )),
			IfNode( function() return not IsBusy(self.inst) end, "notBusy_goMine",
				DoAction(self.inst, function() return FindTreeOrRockAction(self.inst, ACTIONS.MINE) end, "mineRock", true)),
				
			-- Can't find anything to do...increase search distance
			IfNode( function() return not IsBusy(self.inst) end, "nothing_to_do",
				DoAction(self.inst, function() return IncreaseSearchDistance() end,"lookingForStuffToDo", true)),

			-- No plan...just walking around
			--Wander(self.inst, nil, 20),
        },.2)
		
		-- Behave slightly different half way through dusk
		local dusk2 = WhileNode( function() return clock and clock:IsDusk() and MidwayThroughDusk() and HasValidHome(self.inst) end, "IsDusk2",
			PriorityNode{
			
			IfNode( function() return not IsBusy(self.inst) and  self.inst.components.hunger:GetPercent() < .5 end, "notBusy_hungry",
				DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true )),

			IfNode( function() return HasValidHome(self.inst) end, "try to go home",
				DoAction(self.inst, function() return GoHomeAction(self.inst) end, "go home", true)),
				
			-- If we don't have a home...just
				--IfNode( function() return AtHome(self.inst) end, "am home",
				--	DoAction(self.inst, function() return BuildStuffAtHome(self.inst) end, "build stuff", true)),
				
				-- If we don't have a home, make a camp somewhere
				--IfNode( function() return not HasValidHome(self.inst) end, "no home to go",
				--	DoAction(self.inst, function() return true end, "make temp camp", true)),
					
				-- If we're home (or at our temp camp) start cooking some food.
				
				
		},.5)
		
	-- Things to do during the night
	--[[
		1) Light a fire if there is none close by
		2) Stay near fire. Maybe cook?
	--]]
	local night = WhileNode( function() return clock and clock:IsNight() end, "IsNight",
        PriorityNode{
			-- If we aren't home but we have a home, make a torch and keep running!
			--WhileNode(function() return HasValidHome(self.inst) and not AtHome(self.inst) end, "runHomeJack",
			--	DoAction(self.inst, function() return MakeTorchAndKeepRunning(self.inst) end, "make torch", true)),
				
			-- Must be near light! 	
			IfNode( function() return not IsNearLightSource(self.inst) end, "no light!!!",
				DoAction(self.inst, function() return MakeLightSource(self.inst) end, "making light", true)),
				
			IfNode( function() return IsNearCookingSource(self.inst) end, "let's cook",
				DoAction(self.inst, function() return CookSomeFood(self.inst) end, "cooking food", true)),
			
			-- Eat more at night
			IfNode( function() return not IsBusy(self.inst) and  self.inst.components.hunger:GetPercent() < .9 end, "notBusy_hungry",
				DoAction(self.inst, function() return HaveASnack(self.inst) end, "eating", true )),
            
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
			-- No matter the time, panic when on fire
			--WhileNode(function() local ret = self.inst:HasTag("Stuck") self.inst:RemoveTag("Stuck") return ret end, "Stuck", Panic(self.inst)),
			IfNode( function() return self.inst:HasTag("IsStuck") end, "stuck",
				DoAction(self.inst,function() print("Trying to fix this...") return FixStuckWilson(self.inst) end, "alive3",true)),
			
			-- Quit standing in the fire, idiot
			WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire", Panic(self.inst) ),
			
			-- When hit, determine if we should fight this thing or not
			IfNode( function() return self.inst.components.combat.target ~= nil end, "hastarget", 
				DoAction(self.inst,function() return FightBack(self.inst) end,"fighting",true)),
				
			-- Always run away from these things
			RunAway(self.inst, ShouldRunAway, RUN_AWAY_SEE_DIST, RUN_AWAY_STOP_DIST),

			-- Try to stay healthy
			IfNode(function() return not IsBusy(self.inst) end, "notBusy_heal",
				DoAction(self.inst,function() return ManageHealth(self.inst) end, "Manage Health", true)),
			-- Try to stay sane
			DoAction(self.inst,function() return ManageSanity(self.inst) end, "Manage Sanity", true),
			-- Hunger is managed during the days/nights
			
			-- Prototype things whenever we get a chance
			-- Home is defined as our science machine...
			IfNode(function() return not IsBusy(self.inst) and AtHome(self.inst) end, "atHome", 
				DoAction(self.inst, function() return PrototypeStuff(self.inst) end, "Prototype", true)),
				
			-- Always fight back or run. Don't just stand there like a tool
			WhileNode(function() return self.inst.components.combat.target ~= nil and self.inst:HasTag("FightBack") end, "Fight Mode",
				ChaseAndAttack(self.inst,20)),
			day,
			dusk,
			dusk2,
			night

        }, .5)
    
    self.bt = BT(self.inst, root)

end

return ArtificalBrain