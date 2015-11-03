FindThingToBurn = Class(BehaviourNode, function(self, inst, searchDistanceFn, suggestFn)
   BehaviourNode._ctor(self, "FindThingToBurn")
   self.inst = inst
   self.getTargetFn = suggestFn
   self.distance = searchDistanceFn
   
   self.locomotorFailed = function(inst, data)
      local theAction = data.action or "[Unknown]"
      local theReason = data.reason or "[Unknown]"
      print("FindThingToBurn: Action: " .. theAction:__tostring() .. " failed. Reason: " .. tostring(theReason))
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

function FindThingToBurn:OnStop()
   self.inst:RemoveEventCallback("actionfailed", self.locomotorFailed)
   self.inst:RemoveEventCallback("onreachdestination", self.onReachDest)
end

function FindThingToBurn:OnFail()
    self.pendingstatus = FAILED
end
function FindThingToBurn:OnSucceed()
   self.pendingstatus = SUCCESS
end

function FindThingToBurn:BuildDone()
   self.waitingForBuild = false
end

-- Returns a tree that is safe to set on fire. 
-- And by safe...well, that is relative.
function FindThingToBurn:GetSafeTreeToBurn()

   local tree = FindEntity(self.inst, self.distance(), function(item) 
   
      -- Not a tree
      if not item:HasTag("tree") then return false end
      
      -- Half of a tree...
      if item:HasTag("stump") then return false end
      
      -- Too big. We might still burn down a tall tree if, say, we started chopping it then
      -- stop for some reason...
      -- Do I want this 'no large tree' restriction? 
      local workable = item.components.workable
      if workable and workable.workleft > TUNING.EVERGREEN_CHOPS_NORMAL then
         return false 
      end
        
      -- Already burnt down
      if item:HasTag("burnt") then return false end
      
      -- Can't burn it
      if not item.components.burnable then return false end
      
      -- Currently burning
      if item.components.burnable:IsBurning() then return false end
      
      -- Not valid for some reason
      if self.inst.components.prioritizer:OnIgnoreList(item.prefab) then return false end
      if self.inst.components.prioritizer:OnIgnoreList(item.entity:GetGUID()) then return false end
      
      -- Something spooky by it
      if self.inst.brain:HostileMobNearInst(item) then return false end
      
      -- This item is a good candidate. Make sure it doesn't burn down the whole world
      
      local prop_range = item.components.propagator and item.components.propagator.propagaterange or 0
      
      -- Find a burnable entities within this range
      -- TODO: Make this a recursive check (with a limit of course)
      local burnable = nil
      if prop_range > 0 then
         burnable = FindEntity(item, prop_range, 
                        function(b) return b.components.burnable and
                        b.components.propagator and 
                        not (b.components.inventoryitem and b.components.inventoryitem.owner) and
                        not b:HasTag("player") end)
                                                                    
                                                                     
         if burnable then 
            --print("Lighting " .. item.prefab .. " will also ignite " .. burnable.prefab)
            return false
         end
      end                                                            

      -- Whelp...this seems good      
      return true

   end)
   
   return tree

end

function FindThingToBurn:Visit()
   -- If there is something to burn, we will try to burn it.
   -- Will only look for trees to make chacoal if charcoal is not
   -- on the ignore list! 
   
   -- Otherwise, if the suggestedTarget is populated, we will burn that
   -- down if we can
   
   -- Need to determine when a good time is to ignore charcoal. I'd say after 
   -- a full stack? I mean, we'll want drying racks at some point too.
   
   if self.status == READY then
      self.reachedDestination = nil
      self.pendingstatus = nil
      self.currentTarget = nil
      self.currentLighter = nil
      self.action = nil
      
      local target = nil
      if self.getTargetFn then
         target = self.getTargetFn()
      end
      
      -- Look for a valid target
      if not target then
         if self.inst.components.prioritizer:OnIgnoreList("charcoal") then
            self.status = FAILED
            return
         end
         
         -- Otherwise, see if we have a half a stack of it (20) then we don't need more.
         local haveEnough,num = self.inst.components.inventory:Has("charcoal",20)
         if haveEnough then
            self.status = FAILED
            return
         end
         
         -- We need charcoal...lets find a tree!
         target = self:GetSafeTreeToBurn()
      end
      
      -- Nothing to burn down
      if not target then
         self.status = FAILED
         return
      end
      
      local firestarter = nil
      local equipped = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
      local alreadyEquipped = false
      if equipped and equipped.components.lighter then
         firestarter = equipped
         alreadyEquipped = true
      else
         firestarter = self.inst.components.inventory:FindItem(function(item) return item.components.lighter end)
      end
            
      if not firestarter then
         -- Waiting for the torch to appear.
         if not self.waitingForBuild then
            -- Don't craft one unless we can hold one
            if not self.inst.components.inventory:IsTotallyFull() then
               self.waitingForBuild = true
               self.inst.brain:SetSomethingToBuild("torch",nil,function() self.waitingForBuild = false end, function() self.waitingForBuild = false end)
            end
         end
         -- In either case...nothing to do
         self.status = FAILED
         return
      end
      
      -- We have a target and a firestarter. Let's go
      self.currentTarget = target
      self.currentLighter = firestarter
      
      -- Equip the lighter
      if not alreadyEquipped then
         self.inst.components.inventory:Equip(firestarter)
      end
      
      local action = BufferedAction(self.inst,target,ACTIONS.LIGHT,firestarter)
      action:AddFailAction(function() self:OnFail() end)
      action:AddSuccessAction(function() self:OnSucceed() end)
      self.action = action
      self.inst.components.locomotor:PushAction(action, true)
      
      self.status = RUNNING
      
   elseif self.status == RUNNING then
      if self.pendingstatus then
         self.status = self.pendingstatus
      elseif not self.action:IsValid() then
         self.status = FAILED
      elseif not self.inst.components.locomotor:HasDestination() and not self.reachedDestination then
         print("We have no destination and we haven't reached it yet! We're stuck!")
         self.status = FAILED
      end
      
      -- We're done. Unquip the torch
      if self.status ~= RUNNING then
         local equipped = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
         
         -- Can't unquip in this case. Need to swap something
         if self.inst.components.inventory:IsTotallyFull() then
            local somethingElse = self.inst.components.inventory:FindItem(function(item) 
                              return item.components.equippable and         
                                     item.components.equippable.equipslot == EQUIPSLOTS.HANDS and
                                     not item.components.lighter end)
            if somethingElse then
               self.inst.components.inventory:Equip(somethingElse)
            end
         
         else
            if equipped and equipped.components.lighter then
               --self.inst.components.inventory:Unequip(EQUIPSLOTS.HANDS)
               --self.inst:PushBufferedAction(BufferedAction(self.inst,self.inst,ACTIONS.UNEQUIP,equipped))
              self.inst.components.inventory:GiveItem(equipped)
            end
         end
      end
   end
end



