FindResourceToHarvest = Class(BehaviourNode, function(self, inst, searchDistance)
    BehaviourNode._ctor(self, "FindResourceToHarvest")
    self.inst = inst
	self.distance = searchDistance
end)

-- Returned from the ACTIONS.EAT
function FindResourceToHarvest:OnFail()
    self.pendingstatus = FAILED
end
function FindResourceToHarvest:OnSucceed()
    self.pendingstatus = SUCCESS
end


function FindResourceToHarvest:Visit()

    if self.status == READY then
		local target = FindEntity(self.inst, self.distance, function(item)
					
					if item.components.pickable and item.components.pickable:CanBePicked() and item.components.pickable.caninteractwith then
						local theProductPrefab = item.components.pickable.product
						if theProductPrefab == nil then
							return false
						end
						
						-- If we have some of this product, it will override the isFull check
						local haveItem = self.inst.components.inventory:FindItem(function(invItem) return theProductPrefab == invItem.prefab end)
						
						if self.inst.brain:OnIgnoreList(item.components.pickable.product) then
							return false
						end
						-- This entity is to be ignored
						if self.inst.brain:OnIgnoreList(item.entity:GetGUID()) then return false end
						
						if self.inst.brain:HostileMobNearInst(item) then 
							print("Ignoring " .. item.prefab .. " as there is a monster by it")
							return false 
						end
						
						-- Check to see if we have a full stack of this item
						local theProduct = self.inst.components.inventory:FindItem(function(item) return (item.prefab == theProductPrefab) end)
						if theProduct then
							-- If we don't have a full stack of this...then pick it up (if not stackable, we will hold 2 of them)
							return not self.inst.components.inventory:Has(theProductPrefab,theProduct.components.stackable and theProduct.components.stackable.maxsize or 2)
						else
							-- Don't have any of this...lets get some (only if we have room)						
							return not self.inst.components.inventory:IsFull()
						end
					end
					-- Default case...probably not harvest-able. Return false.
					return false
				end)

		if target then
			local action = BufferedAction(self.inst,target,ACTIONS.PICK)
			action:AddFailAction(function() self:OnFail() end)
			action:AddSuccessAction(function() self:OnSucceed() end)
			self.action = action
			self.pendingstatus = nil
			self.inst.components.locomotor:PushAction(action, true)
			self.inst.brain:ResetSearchDistance()
			self.status = RUNNING
			return
		end
		self.status = FAILED
    elseif self.status == RUNNING then
		if self.pendingstatus then
			self.status = self.pendingstatus
		elseif not self.action:IsValid() then
			self.status = FAILED
		end
    end
end



