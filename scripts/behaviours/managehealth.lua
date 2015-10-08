ManageHealth = Class(BehaviourNode, function(self, inst, healthPercent)
    BehaviourNode._ctor(self, "ManageHealth")
    self.inst = inst
	self.percent = healthPercent or .1
end)

-- Returned from the buffered actions
function ManageHealth:OnFail()
    self.pendingstatus = FAILED
end
function ManageHealth:OnSucceed()
    self.pendingstatus = SUCCESS
end

function ManageHealth:DoThisAction(action)
	action:AddFailAction(function() self:OnFail() end)
	action:AddSuccessAction(function() self:OnSucceed() end)
	self.action = action
	self.pendingstatus = nil
	self.inst:PushBufferedAction(action)
end


function ManageHealth:Visit()

    if self.status == READY then
		-- Don't do anything unless we are hurt
		if self.inst.components.health:GetPercent() > self.percent then
			self.status = FAILED
			return
		end
	
	local healthMissing = self.inst.components.health:GetMaxHealth() - self.inst.components.health.currenthealth
	
	-- Do we have edible food? 
	local bestFood = nil
	-- If we have food that restores health, eat it
	local healthFood = self.inst.components.inventory:FindItems(function(item) return self.inst.components.eater:CanEat(item) and 
																					item.components.edible:GetHealth(self.inst) > 0 end)
	
	-- Find the best food that doesn't go over and eat that.
	-- TODO: Sort by staleness
	for k,v in pairs(healthFood) do
		local h = v.components.edible:GetHealth(self.inst)
		-- Only consider foods that heal for less than hunger if we are REALLY hurting
		local z = v.components.edible:GetHunger(self.inst)
		
		-- h > z, this item is better used as healing
		-- or heals for more than 5 and we are really hurting
		if h > z or (h <= z and  h >= 5 and self.inst.components.health:GetPercent() < .2) then
			if h <= healthMissing then
				if not bestFood or (bestFood and bestFood.components.edible:GetHealth(self.inst) < h) then
					bestFood = v
				end
			end
		end
	end
	
	if bestFood then
		self:DoThisAction(BufferedAction(self.inst,bestFood,ACTIONS.EAT))
		self.status = RUNNING
		return
	end
	
	-- Out of food. Do we have any other healing items?
	local healthItems = self.inst.components.inventory:FindItems(function(item) return item.components.healer end)
	
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
		self:DoThisAction(BufferedAction(self.inst,self.inst,ACTIONS.HEAL,bestHealthItem))
		self.status = RUNNING
		return
	end
	
	-- Nothing to heal with...oh well
	self.status = FAILED
		
    elseif self.status == RUNNING then
		if self.pendingstatus then
			self.status = self.pendingstatus
		elseif not self.action:IsValid() then
			self.status = FAILED
		end
    end
end



