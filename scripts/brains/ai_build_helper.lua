

-- Copied straight from widgetutil.lua
function CanPrototypeRecipe(recipetree, buildertree)
    for k,v in pairs(recipetree) do
        if buildertree[tostring(k)] and recipetree[tostring(k)] and
        recipetree[tostring(k)] > buildertree[tostring(k)] then
                return false
        end
    end
    return true
end


-- Makes sure we have the right tech level.
-- If we don't have a resource, checks to see if we can craft it/them
-- If we can craft all necessary resources to build something, returns true
-- else, returns false
-- Do not set recursive variable, it will be set on recursive calls
-- If you want this built, have the Crafting behaviour do it
function CanPlayerBuildThis(player, thingToBuild, numToBuild, recursive)

	-- Reset the table if it exists
	if player.itemsNeeded and not recursive then
		for k,v in pairs(player.itemsNeeded) do player.itemsNeeded[k]=nil end
		recursive = 0
	elseif player.itemsNeeded == nil then
		player.itemsNeeded = {}
	end
	
	if recursive == nil then
		recursive = 0
	end
	
	if numToBuild == nil then numToBuild = 1 end
	
	local recipe = GetRecipe(thingToBuild)
	
	-- Not a real thing so we can't possibly build this
	if not recipe then 
		print(thingToBuild .. " is not craftable")
		return false 
	end
	
	print("Checking to see if we can build " .. thingToBuild)
	
	-- Quick check, do we know how to build this thing?
	if not player.components.builder:KnowsRecipe(thingToBuild) then
		-- Check if we can prototype it 
		print("We don't know recipe for " .. thingToBuild)
		local tech_level = player.components.builder.accessible_tech_trees
		if not CanPrototypeRecipe(recipe.level, tech_level) then
			print("...nor can we prototype it")
			return false 
		else
			print("...but we can prototype it!")
		end
	end

	-- For each ingredient, check to see if we have it. If not, see if it's creatable
	for ik,iv in pairs(recipe.ingredients) do
		local hasEnough = false
		local numHas = 0
		local totalAmountNeeded = math.ceil(iv.amount*numToBuild)
		hasEnough, numHas = player.components.inventory:Has(iv.type,totalAmountNeeded)
		
		-- Subtract things already reserved from numHas
		for i,j in pairs(player.itemsNeeded) do
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
				table.insert(player.itemsNeeded,1,{prefab=iv.type,amount=numHas,level=0})
			end
			-- Recursive check...can we make this ingredient
			local canCraft = CanPlayerBuildThis(player,iv.type,needed,recursive+1)
			if not canCraft then
				print("Need " .. tostring(needed) .. " " .. iv.type .. "s but can't craft them!")
				return false
			else
				-- We know the recipe to build this and have the goods. Add it to the list
				-- This should get added in the recursive case
				--table.insert(player.itemsNeeded,1,{prefab=iv.type, amount=needed, level=recursive, toMake=thingToBuild})
			end
		else
			-- We already have enough to build this resource. Add these to the list
			print("Adding " .. tostring(totalAmountNeeded) .. " of " .. iv.type .. " at level " .. tostring(recursive) .. " to the itemsNeeded list")
			table.insert(player.itemsNeeded,1,{prefab=iv.type, amount=totalAmountNeeded, level=recursive, toMake=thingToBuild, toMakeNum=numToBuild})
		end
	end
	
	-- We made it here, we can make this thingy
	return true
end

-- Returns a list of one or more buffered actions.
-- Attaches the onSuccess action only to the final thing wanting to be built
-- Attaches the onFail action to every action.
-- The best way to use this is to have a BehaviourNode run through the queued list until
-- the onSuccess callback is triggered. 

-- Returns nil if there were no actions generated
function GenerateBufferedBuildOrder(player, thingToBuild, pos, onSuccess, onFail)
	local bufferedBuildList = {}
	local recipe = GetRecipe(thingToBuild)
	-- not a real thing
	if not recipe then return end
	
	print("GenerateBufferedBuildOrder called with " .. thingToBuild)
		
	-- generate a callback fn for successful build
	local unlockRecipe = function()
	   if not player.components.builder:KnowsRecipe(thingToBuild) then
		    player.components.builder:UnlockRecipe(thingToBuild)
		end
	end
	
	if not player.itemsNeeded or #player.itemsNeeded == 0 then
		print("itemsNeeded is empty!")
		-- This should always be called first.
		-- If the table doesn't exist, generate it for them
		if not CanPlayerBuildThis(player, thingToBuild) then
			return
		end
	end
	
	for k,v in pairs(player.itemsNeeded) do print(k,v) end
		
	-- TODO: Make sure we have the inventory space! 
	for k,v in pairs(player.itemsNeeded) do
		-- Just go down the list. If level > 0, we need to build it
		if v.level > 0 and v.toMake then
			-- It's assumed that we can build this. They shouldn't have called this 
			-- function otherwise! Can't test here as we might not have all of the
			-- refined resources yet. 
			while v.toMakeNum > 0 do 
            -- Pass own position for refined resources
				local action = BufferedAction(player,nil,ACTIONS.BUILD,nil,Point(player.Transform:GetWorldPosition()),v.toMake,1)
				if onFail then
					action:AddFailAction(function() onFail() end)
				end
				-- Add the recipe unlock success action
				action:AddSuccessAction(unlockRecipe)
				
				print("Adding action " .. action:__tostring() .. " to bufferedBuildList")
				table.insert(bufferedBuildList, action)
				v.toMakeNum = v.toMakeNum - 1
			end
		end
	end
	

	-- Finally, queue the final resource for build
	local action = BufferedAction(player,player,ACTIONS.BUILD,nil,pos,thingToBuild,1)
	if onFail then
		action:AddFailAction(onFail)
	end
	if onSuccess then
		action:AddSuccessAction(onSuccess)
	end
	-- Also add the success action for unlocking the recipe
	action:AddSuccessAction(unlockRecipe)
	
	
	print("Pushing action to build " .. thingToBuild)
	print(action:__tostring())
	table.insert(bufferedBuildList,action)
	
	return bufferedBuildList

end
