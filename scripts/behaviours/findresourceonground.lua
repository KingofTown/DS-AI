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
		local target = FindEntity(self.inst, self.distance(), function(item)
						-- Do we have a slot for this already
						local haveItem = self.inst.components.inventory:FindItem(function(invItem) return item.prefab == invItem.prefab end)
											
						
						-- Ignore these dang trinkets
						if item.prefab and string.find(item.prefab, "trinket") then return false end
						-- We won't need these thing either.
						if item.prefab and string.find(item.prefab, "teleportato") then return false end
						
						-- Ignore things near scary dudes
						if self.inst.brain:HostileMobNearInst(item) then 
							--print("Ignoring " .. item.prefab .. " as there is something scary near it")
							return false 
						end
			
						if item.components.inventoryitem and 
							item.components.inventoryitem.canbepickedup and 
							not item.components.inventoryitem:IsHeld() and
							item:IsOnValidGround() and
							-- Ignore things we have a full stack of (or one of if it doesn't stack)
							not self.inst.components.inventory:Has(item.prefab, item.components.stackable and item.components.stackable.maxsize or 1) and
							-- Ignore this unless it fits in a stack
							not (self.inst.components.inventory:IsFull() and haveItem == nil) and
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



