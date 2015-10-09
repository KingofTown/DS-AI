FindTreeOrRock = Class(BehaviourNode, function(self, inst, searchDistance, actionType)
    BehaviourNode._ctor(self, "FindTreeOrRock")
    self.inst = inst
	self.distance = searchDistance
	self.actionType = actionType
	self.currentTarget = nil
	
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


function FindTreeOrRock:SetupActionWithTool(target, tool)
	self.inst.brain:ResetSearchDistance()
	local action = BufferedAction(self.inst, target, self.actionType,tool)
	self.action = action
	self.inst.components.locomotor:PushAction(action, true)
	self.inst.brain:ResetSearchDistance()
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


function FindTreeOrRock:Visit()

    if self.status == READY then
		-- TODO: Get the loot table for these rather than this hacky hardcode
		if self.actionType == ACTIONS.CHOP and self.inst.components.inventory:Has("log",20) then
			self.status = FAILED
			return
		end
		
	local target = FindEntity(self.inst, self.distance, function(item)
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
			
			-- Skip this if it only drops stuff we are full of
			-- TODO, get the lootdroper rather than knowing what prefab it is...
			if item.prefab and item.prefab == "rock1" then
				return not self.inst.components.inventory:Has("flint",20)
			elseif item.prefab and item.prefab == "rock2" then
				return not self.inst.components.inventory:Has("goldnugget",20)
			elseif item.prefab and item.prefab == "rock_flintless" then
				return not self.inst.components.inventory:Has("rocks",40)
			end

			
			-- Found one
			return true
	
		end)
		
		if target then
			-- Keep going until it's finished
			
			
			self.currentTarget = target 
			
			local haveRightTool, tool = self:FindAndEquipRightTool()

			-- We are holding the right tool or have one in inventory
			if haveRightTool then
				self.currentTarget = target
				self:SetupActionWithTool(target, tool)
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
			print("We can't continue this action!")
			self.currentTarget = nil
			self.status = FAILED
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



