ManageSanity = Class(BehaviourNode, function(self, inst, sanityTargetFn)
   BehaviourNode._ctor(self, "ManageSanity")
   self.inst = inst
   self.targetSanityFn = sanityTargetFn
end)

-- Returned from the ACTIONS.EAT
function ManageSanity:OnFail()
    self.pendingstatus = FAILED
end
function ManageSanity:OnSucceed()
    self.pendingstatus = SUCCESS
end

function ManageSanity:EatThisFood(food)
	local action = BufferedAction(self.inst,food,ACTIONS.EAT)
	action:AddFailAction(function() self:OnFail() end)
	action:AddSuccessAction(function() self:OnSucceed() end)
	self.action = action
	self.pendingstatus = nil
	self.inst:PushBufferedAction(action)
end


function ManageSanity:Visit()

    if self.status == READY then
    
      -- Allow the brain to set a target sanity. It will attempt to stay near that value
      local targetSanity, sanityRange = self.targetSanityFn() or .9,.75
      local currentSanity = self.inst.components.sanity:GetPercent()
    
      -- Don't bother picking up flowers until our sanity starts dropping
      if currentSanity < targetSanity*.95 and self.inst.brain:OnIgnoreList("petals") then
         self.inst.brain:RemoveFromIgnoreList("petals")
      elseif currentSanity >= math.max(1,targetSanity*1.05) and not self.inst.brain:OnIgnoreList("petals") then
         self.inst.brain:AddToIgnoreList("petals")
      end
      
      -- Until we get to below some value...don't do anything.
      -- This will allow us to maintian the sanity by picking flowers and doing other things.
      -- Only try to eat sanity food if we are below the range
      if currentSanity >= math.max(0,targetSanity*sanityRange) then
         self.status = FAILED
         return
      end
      
      local currentHealth = self.inst.components.health.currenthealth

      -- Look for something in our inventory to eat. If we find something, go to status RUNNING
      local allFoodInInventory = self.inst.components.inventory:FindItems(function(item) return 
                        self.inst.components.eater:CanEat(item) and
                        currentHealth - item.components.edible:GetHealth(self.inst) > 0 and 
                        item.components.edible:GetSanity(self.inst) > 0 end)
                        
      

      
      -- Find the best thing to eat here to restore some sanity.
      local bestFoodToEat = nil
      local bhe, bhu, bsa = nil
      local function SetBestFood(food)
         bestFoodToEat = food
         bhe = bestFoodToEat.components.edible:GetHealth(self.inst)
         bhu = bestFoodToEat.components.edible:GetHunger(self.inst)
         bsa = bestFoodToEat.components.edible:GetSanity(self.inst)
         --print("Setting best food: " ..food.prefab)
         --print("bhe, bhu, bsa: " .. tostring(bhe) .. " " .. tostring(bhu) .. " " .. tostring(bsa))
      end         
      
      for k,v in pairs(allFoodInInventory) do
         local he = v.components.edible:GetHealth(self.inst)
         local hu = v.components.edible:GetHunger(self.inst)
         local sa = v.components.edible:GetSanity(self.inst)
        
         if bestFoodToEat == nil then
            SetBestFood(v)
         else
            -- Can make this better...simply find what gives the most sanity
            -- parameters:
            --            sa > 0
            --            he > 0 or he*he < 2*sa (health loss squared less than 2x sanity gained) 
            --                 ( will accept a -3 health for 9+ sanity...)

            -- This is better on all accounts
            if (he >=0 or he >= bhe) and sa > bsa then
               -- If health > 0, this is better
               -- or if health is greater than current negative...this is still better
               SetBestFood(v)
            elseif he < 0 and sa > bsa then
               
               local hdiff = bhe - he
               local sdiff = bsa - sa
               -- This food is only better if the health difference squared
               -- is less than 2*sa. 
               if hdiff*hdiff < 2*sa then
                  print("1) CurrentBest: " .. bestFoodToEat.prefab .. " bhe: " .. tostring(bhe) .. " sa: " .. tostring(sa))
                  SetBestFood(v)
               end
            elseif he >= bhe and sa < bsa then
               -- This gives less sanity than the current...but we lose less health.
               -- Only switch if the sanity gained from this food falls within the threshold 
               if bhe*bhe >= 2*sa then
                  print("2) CurrentBest: " .. bestFoodToEat.prefab .. " bhe: " .. tostring(bhe) .. " sa: " .. tostring(sa))
                  SetBestFood(v)
               end
            end
               
         end
      
      end
		
	   if bestFoodToEat ~= nil then
	      self:EatThisFood(bestFoodToEat)
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



