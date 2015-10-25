FindTreeOrRock = Class(BehaviourNode, function(self, inst, searchDistanceFn, actionType, searchMode)
    BehaviourNode._ctor(self, "FindTreeOrRock")
    self.inst = inst
    self.actionType = actionType
    self.searchMode = searchMode
	self.currentTarget = nil
	self.distance = searchDistanceFn

	if searchMode == "BaseManagement" then
		self.targetInst = nil
		self.getTarget = function() return self.inst.components.basebuilder:GetTargetToClean() end
	else
		self.targetInst = inst
		self.getTarget = self.GetTarget
	end

	self.onWorkDone = function(inst, data)
		self.workDone = SUCCESS
	end

	self.inst:ListenForEvent("workfinished", self.onWorkDone)
end)

function FindTreeOrRock:OnStop()
    self.inst:RemoveEventCallback("workfinished", self.onWorkDone)
end

function FindTreeOrRock:BuildSucceed()
	self.pendingBuildStatus = SUCCESS
end
function FindTreeOrRock:BuildFailed()
	self.pendingBuildStatus = FAILED
end

local function getLootFromTable(inst)
    if not inst.components.lootdropper then return end
    
    local loot = {}
    -- Only add the prefab once. Don't care about counting.
    local function insertLoot(prefab)
        if loot[prefab] == nil then
            loot[prefab] = 1
        end
    end
    

    -- Let's assume everything has a 100% chance
    -- to drop right now.
    if inst.components.lootdropper.chanceloottable then
        local loot_table = LootTables[inst.components.lootdropper.chanceloottable]
        if loot_table then
            for i, entry in ipairs(loot_table) do
                local prefab = entry[1]
                local chance = entry[2] -- Not using for now
                insertLoot(prefab)
            end
        end
    end
    
    if inst.components.lootdropper.loot then
        for k,v in pairs(inst.components.lootdropper.loot) do
            insertLoot(v)
        end
    end
       
    return loot
end


function FindTreeOrRock:SetupActionWithTool(target, tool)
	local action = BufferedAction(self.inst, target, self.actionType,tool)
	action:AddFailAction(function() end)
	action:AddSuccessAction(function() end)
	self.action = action
	self.inst.components.locomotor:PushAction(action, true)
end

-- returns false if no tool 
function FindTreeOrRock:FindAndEquipRightTool()
	-- Get the right tool
	local equiped = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	local alreadyEquipped = false
	local tool = nil
	if equiped and equiped.components.tool and equiped.components.tool:CanDoAction(self.actionType) then
		return true, equiped
	else
		-- Find the right one
		tool = self.inst.components.inventory:FindItem(function(item) return item.components.equippable and 
								item.components.tool and item.components.tool:CanDoAction(self.actionType) end)
	end
	if tool then
		if not alreadyEquipped then
			self.inst.components.inventory:Equip(tool)
			return true, tool
		end
	end
	return false, nil
end

function FindTreeOrRock:GetTarget()
	local target = FindEntity(self.targetInst, self.distance(), function(item)
		if not item.components.workable then return false end
		if not item.components.workable:IsActionValid(self.actionType) then return false end

		-- TODO: Put ignored prefabs
		if self.inst.brain:OnIgnoreList(item.prefab) then return false end
		-- We will ignore some things forever
		if self.inst.brain:OnIgnoreList(item.entity:GetGUID()) then return false end
		-- Don't go near things with hostile dudes
		if self.inst.brain:HostileMobNearInst(item) then
			print("Ignoring " .. item.prefab .. " as there is something spooky by it")
			return false 
		end
		

	local target = FindEntity(self.inst, self.distance(), function(item)
			if not item.components.workable then return false end
			if not item.components.workable:IsActionValid(self.actionType) then return false end
			
			-- TODO: Put ignored prefabs
			if self.inst.components.prioritizer:OnIgnoreList(item.prefab) then return false end
			-- We will ignore some things forever
			if self.inst.components.prioritizer:OnIgnoreList(item.entity:GetGUID()) then return false end
			-- Don't go near things with hostile dudes
			if self.inst.brain:HostileMobNearInst(item) then
				print("Ignoring " .. item.prefab .. " as there is something spooky by it")
				return false 
			end
			
			-- Some prefabs modify their loot table dynamically depending on their condition (burnt trees).
			-- There's no good way to tell if it will drop a special loot in the code.
			if item:HasTag("tree") and item:HasTag("burnt") then
    			 -- Charcoal!
    			 local invFull = self.inst.components.inventory:IsTotallyFull()
    			 if not invFull then
    			     return true
    			 end

    			 local ch = self.inst.components.inventory:FindItem(function(i) return i.prefab == "charcoal" end)
    			 if invFull and not ch then
    			     return false
    			 elseif invFull and ch then
    			     return not ch.components.stackable:IsFull()
    			 end
    	   
		end
		
		-- Only do work on this item if it will drop something we want
		local itemLoot = getLootFromTable(item)
		if not itemLoot then return false end

		
		for k,v in pairs(itemLoot) do
			     -- If we aren't ignoring this type of loot.
			     -- TODO: I don't want to cut down a tree for the acorns only...but I also don't 
			     --       want to add them to the ignore list as I want them.
			     --       This is kinda hacky.
			     if  not self.inst.components.prioritizer:OnIgnoreList(k) and k ~= "acorn" then
    			     local itemInInv = self.inst.components.inventory:FindItem(function(i) return i.prefab == k end)
    			     -- If we don't have one and not full, pick it up!
    			     if not itemInInv and not self.inst.components.inventory:IsTotallyFull() then
    			         return true
    			     end
    			     
    			     -- Else, if we have one...make sure we want it
    			     local canStack = itemInInv and itemInInv.components.stackable and not itemInInv.components.stackable:IsFull()
    			     
    			     if canStack then
    			         return true 
    			     end
    			     
    			     --print("Meh, don't need any " .. k .. "s. What else do you have, " .. item.prefab .. "?")
    			     -- Check next item in the table
		     end
		end
		
            -- This is nothing that I want
		return false

	end)
	
	return target
end

function FindTreeOrRock:Visit()
	--print("FindTreeOrRock:Visit() - " .. tostring(self.status))
	
	if self.searchMode == "BaseManagement" then
		print("UPDATING self.targetInst!!!")
		self.targetInst = self.inst.components.homeseeker.home
	end

    if self.targetInst == nil then
    	-- This happens when the this inst isn't wilson and we haven't set it yet... so pass
		return
	elseif self.status == READY then
		-- TODO: Get the loot table for these rather than this hacky hardcode
		--if self.actionType == ACTIONS.CHOP and self.inst.components.inventory:Has("log",20) then
		--	self.status = FAILED
		--	return
		--end
	--if self.inst.components.basebulder:GetTree() then

	--end

		local target = self:GetTarget()
		if target then
    		-- Keep going until it's finished
    		self.currentTarget = target
			
			local haveRightTool, tool = self:FindAndEquipRightTool()

			-- We are holding the right tool or have one in inventory
			if haveRightTool then
				self.currentTarget = target
				self:SetupActionWithTool(target, tool)
				self.inst.brain:ResetSearchDistance()
				self.status = RUNNING
				return
			else
				-- Can we craft one? 
				local thingToBuild = nil
				if self.actionType == ACTIONS.CHOP then
					thingToBuild = "axe"
				elseif self.actionType == ACTIONS.MINE then
					thingToBuild = "pickaxe"
				end
				
				-- Axe and pickaxe are always level 1...so we don't need to do a more intense check here. Just see if 
				-- we have the resources and craft it.
				if thingToBuild and self.inst.components.builder and self.inst.components.builder:CanBuild(thingToBuild) then

					local buildAction = BufferedAction(self.inst,self.inst,ACTIONS.BUILD,nil,nil,thingToBuild,nil)
					self.action = buildAction
					self.pendingBuildStatus = nil
					buildAction:AddFailAction(function() self:BuildFailed() end)
					buildAction:AddSuccessAction(function() self:BuildSucceed() end)
					self.inst:PushBufferedAction(buildAction)
					self.inst.brain:ResetSearchDistance()
					self.status = RUNNING
				else
					--addRecipeToGatherList(thingToBuild,false)
					-- cant build the right tool
					self.status = FAILED
					return
				end
			end
		end		
		
		-- No target, or no tool, etc etc...nothing to do
		self.status = FAILED
		
    elseif self.status == RUNNING then
		-- We did it!
		if self.workDone and self.workDone == SUCCESS then
			self.status = SUCCESS
			return
		end
		
		-- Some things don't return the workDone. Make sure the target
		-- is still valid (we could have finished in the first action)
        if not self.currentTarget then
             self.status = SUCCESS
             return
        elseif self.currentTarget and not self.currentTarget.components.workable then
            self.status = SUCCESS
            return
        end
		
		-- We've queued up a tool build. Wait for it to be done
		if self.action.action == ACTIONS.BUILD then
			if self.pendingBuildStatus then
				if self.pendingBuildStatus == FAILED then
					self.status = FAILED
					return
				else
					-- Tool has been built. Equip it and queue the action
					local equiped, tool = self:FindAndEquipRightTool()
					if self.currentTarget and equiped then
						self:SetupActionWithTool(self.currentTarget, tool)
						-- Keep going
						self.status = RUNNING
						return
					else
						-- Something went wrong
						self.status = FAILED
						return
					end
				end
			end
			
			-- Still waiting on that tool
			self.status = RUNNING
			return
		end
		
		-- We're doing the action. Keep going until the target is down.

		-- Make sure we still have a tool. 
		
		local tool = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if not tool or not tool.components.tool:CanDoAction(self.currentTarget.components.workable.action) then
			--print("We can't continue this action!")
			-- We probably killed it. Return success.
			self.currentTarget = nil
			self.status = SUCCESS
			return
		else 
			-- Still good. Keep going
			self:SetupActionWithTool(self.currentTarget, tool)
			self.status = RUNNING
		end
		
		-- Make sure nothing has happened
		if not self.action:IsValid() then
			self.status = FAILED
		end
		
    end
end



