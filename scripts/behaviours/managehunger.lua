ManageHunger = Class(BehaviourNode, function(self, inst, hungerPercent)
    BehaviourNode._ctor(self, "ManageHunger")
    self.inst = inst
	self.percent = hungerPercent
end)

-- Returned from the ACTIONS.EAT
function ManageHunger:OnFail()
    self.pendingstatus = FAILED
end
function ManageHunger:OnSucceed()
    self.pendingstatus = SUCCESS
end

function ManageHunger:EatThisFood(food)
	local action = BufferedAction(self.inst,food,ACTIONS.EAT)
	action:AddFailAction(function() self:OnFail() end)
	action:AddSuccessAction(function() self:OnSucceed() end)
	self.action = action
	self.pendingstatus = nil
	self.inst:PushBufferedAction(action)
end


function ManageHunger:Visit()

    if self.status == READY then
		-- Don't do anything unless we are hungry enough
		if self.inst.components.hunger:GetPercent() > self.percent then
			self.status = FAILED
			return
		end
	
		-- Look for something in our inventory to eat. If we find something, go to status RUNNING
		local allFoodInInventory = self.inst.components.inventory:FindItems(function(item) return 
								self.inst.components.eater:CanEat(item) and 
								item.components.edible:GetHunger(self.inst) > 0 and
								item.components.edible:GetHealth(self.inst) >= 0 and
								item.components.edible:GetSanity(self.inst) >= 0 end)
		
		local bestFoodToEat = nil
		for k,v in pairs(allFoodInInventory) do
			if bestFoodToEat == nil then
				bestFoodToEat = v
			else
				print("Comparing " .. v.prefab .. " to " .. bestFoodToEat.prefab)
				if v.components.edible:GetHunger(self.inst) >= bestFoodToEat.components.edible:GetHunger(self.inst) then
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
			self:EatThisFood(bestFoodToEat)
			self.status = RUNNING
			return
		end
		
		-- We didn't find anything good. Check food that might hurt us if we are real hungry
		if self.inst.components.hunger:GetPercent() > .15 then
			-- Not hungr enough to care at this point. 
			self.status = FAILED
			return
		end
		
		print("We're too hungry. Check emergency reserves!")
		
		allFoodInInventory = self.inst.components.inventory:FindItems(function(item) return 
										self.inst.components.eater:CanEat(item) and 
										item.components.edible:GetHunger(self.inst) > 0 and
										item.components.edible:GetHealth(self.inst) < 0 end)
										
		for k,v in pairs(allFoodInInventory) do
			local health = v.components.edible:GetHealth(self.inst)
			if not bestFoodToEat and health > self.inst.components.health.currenthealth then 
				bestFoodToEat = v
			elseif bestFoodToEat and health > self.inst.components.health.currenthealth then
				if v.components.edible:GetHunger(self.inst) > bestFoodToEat.components.edible:GetHunger(self.inst) and 
					health <= bestFoodToEat.components.edible:GetHealth(self.inst) and
					health > self.inst.components.health.currenthealth then
						bestFoodToEat = v
				end
			end
		end
		
		if bestFoodToEat then
			self:EatThisFood(bestFoodToEat)
			self.status = RUNNING
			return
		end	
		
		-- Nothing to eat!  
		self.status = FAILED
		
    elseif self.status == RUNNING then
		if self.pendingstatus then
			self.status = self.pendingstatus
		elseif not self.action:IsValid() then
			self.status = FAILED
		end
    end
end



