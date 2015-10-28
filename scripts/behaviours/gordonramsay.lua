MasterChef = Class(BehaviourNode, function(self, inst)
   BehaviourNode._ctor(self, "MasterChef")
   self.inst = inst
   self.action = nil
   self.currentCooker = nil
   self.reachedDestination = nil
   
   -- Anytime we need to walk somewhere, I use this to make sure I get there
   self.onReachDest = function(inst,data)
      local target = data.target
      if target and self.action and target == self.action.target then
         self.reachedDestination = true
      end
   end
   self.inst:ListenForEvent("onreachdestination", self.onReachDest)

   -- When we get to the cooker, this will automatically cook something for us.
   -- This node will move to the RUNNING state after pushing the RUMMAGE action and
   -- should remain there until this happens.
   self.openedCooker = function(inst, data)
      if self.currentCooker and data and data.container == self.currentCooker then
         -- We have arrived at our cooker. Push the cook action
         local act = self.inst.components.chef:MakeSomethingGood(self.currentCooker,
                           function() self:OnFail() end, function() self:OnSucceed() end)
                        
         -- Guess we had nothing to make   
         if not act then
            print("Turns out there was nothing to make afterall...")
            self.pendingstatus = FAILED
            return
         else
            self.action = act
            
         end
      end
   end

   self.inst:ListenForEvent("opencontainer", self.openedCooker)

end)

function MasterChef:OnStop()
   self.inst:RemoveEventCallback("opencontainer", self.openedCooker)
   self.inst:RemoveEventCallback("onreachdestination", self.onReachDest)
end

-- Returned from the actions
function MasterChef:OnFail()
    self.pendingstatus = FAILED
end
function MasterChef:OnSucceed()
    self.pendingstatus = SUCCESS
end


function MasterChef:Visit()

    if self.status == READY then
      self.pendingstatus = nil
      self.action = nil
      self.reachedDestination = nil
      
      -- Do we have a cookpot nearby? 
      local cooker = FindEntity(self.inst, 15, function(thing) return thing.prefab == "cookpot" and not thing:HasTag("burnt") end)
      -- No cookpot...nothing to do
      if not cooker then
         self.status = FAILED
         return
      end
      
      -- There's a cookpot! Is it running or does it have something in it?
      if not cooker.components.container.canbeopened then
         print("Cooker nearby...but it can't be opened!")
         -- It is marked as this when cooking, or when something is inside. Check to see if we 
         -- need to harvest it
         if cooker.components.stewer.cooking then
            print("Because it's still cooking!")
            self.status = FAILED
            return
         end
         
         if cooker.components.stewer.product then
            print("...becuase something is inside!")
            -- Let's go harvest this thing (use normal inventory rules)
            local prefab = cooker.components.stewer.product
            if not prefab then
               print("Cookpot says it's done...but there's nothing inside!")
               self.status = FAILED
               return
            end
            
            -- Check inventory for space and stackable
            if not self.inst.components.inventory:IsTotallyFull() then
               -- Go harvest the cooker
               local action = BufferedAction(self.inst,cooker,ACTIONS.HARVEST)
               action:AddFailAction(function() self:OnFail() end)
               action:AddSuccessAction(function() self:OnSucceed() end)
               self.action = action
               self.inst.components.locomotor:PushAction(action,true)
               self.status = RUNNING
               return
            else
               self.status = FAILED
               return
            end
            
            -- Shouldn't get here
            self.status = FAILED
            return
         end
         
         print("Hmm...it's not cooking and there is no product? This is odd...")
         -- We can't open it and it's not done. Must be running
         self.status = FAILED
         return
      end
      
      local haveSomethingToMake = self.inst.components.chef:WhatCanIMake()
      
      if not haveSomethingToMake then
         print(".....nothing")
         self.status = FAILED
         return
      end
      
      -- We have something to make! Go to RUNNING state
      local action = BufferedAction(self.inst, cooker, ACTIONS.RUMMAGE)
      action:AddFailAction(function() self:OnFail() end)
      -- Don't add a success action...we handle that with a different event listener
      self.action = action
      self.currentCooker = cooker
      self.inst.components.locomotor:PushAction(action,true)
      self.status = RUNNING
      return
      
    elseif self.status == RUNNING then
    
      if self.pendingstatus then
         self.status = self.pendingstatus
         return
      elseif not self.action:IsValid() then
         self.status = FAILED
         return
      elseif not self.inst.components.locomotor:HasDestination() and not self.reachedDestination then
         print("We have no destination and we haven't reached it yet! We're stuck!")
         self.status = FAILED
      end
    end
end



