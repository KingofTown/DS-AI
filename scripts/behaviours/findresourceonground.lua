require "brains/ai_inventory_helper"

FindResourceOnGround = Class(BehaviourNode, function(self, inst, searchDistanceFn)
    BehaviourNode._ctor(self, "FindResourceOnGround")
    self.inst = inst
	self.distance = searchDistanceFn
	
	self.locomotorFailed = function(inst, data)
		local theAction = data.action or "[Unknown]"
		local theReason = data.reason or "[Unknown]"
		print("FindResourceOnGround: Action: " .. theAction:__tostring() .. " failed. Reason: " .. tostring(theReason))
        self:OnFail() 
    end
	
	self.onReachDest = function(inst,data)
		local target = data.target
		if target and self.action and target == self.action.target then
			self.reachedDestination = true
		end
	end
	
	self.inst:ListenForEvent("actionfailed", self.locomotorFailed)
	self.inst:ListenForEvent("onreachdestination", self.onReachDest)
end)

function FindResourceOnGround:OnStop()
	self.inst:RemoveEventCallback("actionfailed", self.locomotorFailed)
end

function FindResourceOnGround:OnFail()
	--print(self.action:__tostring() .. " failed!")
    self.pendingstatus = FAILED
end
function FindResourceOnGround:OnSucceed()
	--print(self.action:__tostring() .. " complete!")
    self.pendingstatus = SUCCESS
end


function FindResourceOnGround:Visit()
	--print("FindResourceOnGround:Visit() - " .. tostring(self.status))
    if self.status == READY then
        self.reachedDestination = nil
        
        -- If we aren't wearing a backpack and there is one closeby...go get it
        -- This should find all types of backpacks
        -- Note, we can't carry multiple backpacks, so if we have one in our
        -- inventory, it is equipped
        local function isBackpack(item)
            if not item then return false end
            -- Have to use the not operator to cast to true/false.
            return not not item.components.equippable and not not item.components.container
        end
        
        local bodyslot = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)

        if not isBackpack(bodyslot) then
            local backpack = FindEntity(self.inst, 30, function(item) return isBackpack(item) end)
            if backpack then
            
                local action = BufferedAction(self.inst, backpack, ACTIONS.PICKUP)
                action:AddFailAction(function() self:OnFail() end)
                action:AddSuccessAction(function() self:OnSucceed() end)
                self.action = action
                self.pendingstatus = nil
                self.inst.components.locomotor:PushAction(action, true)
                self.status = RUNNING
                return
            end
        end

		
		local target = FindEntity(self.inst, self.distance(), function(item)
						-- Do we have a slot for this already
						local haveItem = self.inst.components.inventory:FindItem(function(invItem) return item.prefab == invItem.prefab end)
											
						-- Ignore backpack (covered above)
						if isBackpack(item) then return false end
						
						-- Ignore these dang trinkets
						if item.prefab and string.find(item.prefab, "trinket") then return false end
						-- We won't need these thing either.
						if item.prefab and string.find(item.prefab, "teleportato") then return false end
						
						-- Ignore things near scary dudes
						if self.inst.brain:HostileMobNearInst(item) then 
							--print("Ignoring " .. item.prefab .. " as there is something scary near it")
							return false 
						end
						
						local haveFullStack,num = self.inst.components.inventory:Has(item.prefab, item.components.stackable and item.components.stackable.maxsize or 1)
					
			
						if item.components.inventoryitem and 
							item.components.inventoryitem.canbepickedup and 
							not item.components.inventoryitem:IsHeld() and
							item:IsOnValidGround() and
							CanFitInStack(self.inst,item) and
							-- Ignore things we have a full stack of (or one of if it doesn't stack)
							--not self.inst.components.inventory:Has(item.prefab, item.components.stackable and item.components.stackable.maxsize or 1) and
							-- Ignore this unless it fits in a stack
							not (self.inst.components.inventory:IsTotallyFull() and haveItem == nil) and
							not self.inst.brain:OnIgnoreList(item.prefab) and
							not self.inst.brain:OnIgnoreList(item.entity:GetGUID()) and
							not item:HasTag("prey") and
							not item:HasTag("bird") then
								return true
						end
					end)
	if target then
		local action = BufferedAction(self.inst, target, ACTIONS.PICKUP)
		action:AddFailAction(function() self:OnFail() end)
		action:AddSuccessAction(function() self:OnSucceed() end)
		self.action = action
		self.pendingstatus = nil
		self.inst.components.locomotor:PushAction(action, true)
		self.inst.brain:ResetSearchDistance()
		self.status = RUNNING
		return
	end
	
	-- Nothing within distance!
	self.status = FAILED
		
    elseif self.status == RUNNING then
		if self.pendingstatus then
			self.status = self.pendingstatus
		elseif not self.action:IsValid() then
			self.status = FAILED
		elseif not self.inst.components.locomotor:HasDestination() and not self.reachedDestination then
			print("We have no destination and we haven't reached it yet! We're stuck!")
			self.status = FAILED
		end
    end
end



