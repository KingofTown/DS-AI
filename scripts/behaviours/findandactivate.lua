FindAndActivate = Class(BehaviourNode, function(self, inst, searchDistance, thingToActivate)
    BehaviourNode._ctor(self, "FindAndActivate")
    self.inst = inst
	self.distance = searchDistance
	self.thingToActivate = thingToActivate
end)

-- Returned from the actions
function FindAndActivate:OnFail()
    self.pendingstatus = FAILED
end
function FindAndActivate:OnSucceed()
    self.pendingstatus = SUCCESS
end



function FindAndActivate:Visit()

    if self.status == READY then
		-- Find the 'thingToActivate' within the search distance supplied.
		local target = FindEntity(self.inst, self.distance, function(item) return item.prefab == self.thingToActivate and 
																			item.components.activatable and item.components.activatable.inactive end)
		if target then
			local action = BufferedAction(self.inst,target,ACTIONS.ACTIVATE)
			action:AddFailAction(function() self:OnFail() end)
			action:AddSuccessAction(function() self:OnSucceed() end)
			self.action = action
			self.pendingstatus = nil
			self.inst.components.locomotor:PushAction(action, true)
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



