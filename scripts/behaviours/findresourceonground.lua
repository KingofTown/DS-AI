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
	self.inst:RemoveEventCallback("onreachdestination", self.onReachDest)
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
        --local function isBackpack(item)
        --    if not item then return false end
        --    -- Have to use the not operator to cast to true/false.
        --    return not not item.components.equippable and not not item.components.container
        --end
        
        --local bodyslot = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)

        if not IsWearingBackpack(self.inst) then
            local backpack = FindEntity(self.inst, 30, function(item) return IsItemBackpack(item) end)
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
		
		            -- Don't return true on anything up here. Only false returns valid or you'll go for 
		            -- something prematurely (like stuff floating in the middle of the ocean)
		            if self.inst.components.prioritizer:OnIgnoreList(item.prefab) or self.inst.components.prioritizer:OnIgnoreList(item.entity:GetGUID()) then
		               return false
		            end
		            
			
						-- Ignore backpack (covered above)
						if IsItemBackpack(item) then return false end
						
						-- Ignore these dang trinkets
						if item.prefab and string.find(item.prefab, "trinket") then return false end
						-- We won't need these thing either.
						if item.prefab and string.find(item.prefab, "teleportato") then return false end
						
						-- Ignore things near scary dudes
						if self.inst.brain:HostileMobNearInst(item) then 
							--print("Ignoring " .. item.prefab .. " as there is something scary near it")
							return false 
						end
						
						                  -- Do we have a slot for this already
                  --local haveItem = self.inst.components.inventory:FindItem(function(invItem) return item.prefab == invItem.prefab end)
                        
						local haveFullStack,num = self.inst.components.inventory:Has(
						                  item.prefab, item.components.stackable and item.components.stackable.maxsize or 1)
					
					   -- If we have a full stack of this, ignore it.
                  -- exeption, if we have another stack of this...then I guess we can collect
                  -- multiple stacks of it
                  local canFitInStack = false
                  if num > 0 and haveFullStack then
                     --print("Already have a full stack of : " .. item.prefab)
                     if CanFitInStack(self.inst,item) then
                        print("But it can fit in a stack")
                        canFitInStack = true
                     else
                        -- We don't need more of this thing right now.
                        --print("We don't need anymore of these")
                        return false
                     end
           
                  end
                  
                  if num == 0 and self.inst.components.inventory:IsTotallyFull() then
                     return false
                  end
                  
			
						if item.components.inventoryitem and 
							item.components.inventoryitem.canbepickedup and 
							not item.components.inventoryitem:IsHeld() and
							item:IsOnValidGround() and
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



