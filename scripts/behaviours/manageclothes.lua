ManageClothes = Class(BehaviourNode, function(self, inst)
   BehaviourNode._ctor(self, "ManageClothes")
   self.inst = inst

   self.currentHat = nil

   self.onWorkDone = function(inst, data)
      self.workDone = SUCCESS
   end

   self.inst:ListenForEvent("workfinished", self.onWorkDone)
end)

function ManageClothes:OnStop()
   self.inst:RemoveEventCallback("workfinished", self.onWorkDone)
end

function ManageClothes:BuildSucceed()
  self.pendingBuildStatus = SUCCESS
end
function ManageClothes:BuildFailed()
  self.pendingBuildStatus = FAILED
end

-- Looks in inventory to see if already have right clothing item to equip.
function ManageClothes:FindAndEquipClothes(clothes)
   local equiped = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
   if equiped and equiped.prefab == clothes then
      return true, equiped
   else
      local clothing = self.inst.components.inventory:FindItem(function(item) return item.prefab == clothes end)
      if clothing then
         print("equipping " .. clothes)
         self.inst.components.inventory:Equip(clothing)
         return true, clothing
      end
   end

   return false, nil
end

function ManageClothes:Visit()

   -- If raining: wear a straw hat
   -- else, wear a flower hat.
   if self.status == READY then
      local equipped = false
      local hat = nil

      if GetSeasonManager():IsRaining() then
         self.currentHat = "strawhat"
      else
         self.currentHat = "flowerhat"
      end

      -- The right hat is already equipped...nothing to do.
      equipped, hat = self:FindAndEquipClothes(self.currentHat)
      if equipped then
         --print("Right hat already equipped")
         self.status = FAILED
         return
      end

      -- Not equipped....can I make the right hat?
      -- Make sure we have room for it!
      -- TODO: Drop something else? Or just wait?
      if self.inst.components.inventory:IsTotallyFull() then
         --print("Cant make hat - inventory full")
         self.status = FAILED
         return
      end

      -- See if we can even make the hat we want
      if self.currentHat ~= nil and self.inst.components.builder and self.inst.components.builder:CanBuild(self.currentHat) then
         print("I can build a hat!")
         local buildAction = BufferedAction(self.inst,self.inst,ACTIONS.BUILD,nil,nil,self.currentHat,nil)
         self.action = buildAction
         self.pendingBuildStatus = nil
         buildAction:AddFailAction(function() self:BuildFailed() end)
         buildAction:AddSuccessAction(function() self:BuildSucceed() end)
         self.inst:PushBufferedAction(buildAction)
         self.status = RUNNING
      else
         self.status = FAILED
         return
      end

   elseif self.status == RUNNING then
      -- Wait here for the build to finish
      if self.action.action == ACTIONS.BUILD then
         if self.pendingBuildStatus then
            if self.pendingBuildStatus == FAILED then
               self.status = FAILED
               return
            else
               -- Tool has been built. Equip it and queue the action
               local equiped, hat = self:FindAndEquipClothes(self.currentHat)
               if equiped then
                  self.currentHat = nil
                  self.status = SUCCESS
                  return
               end
            end
         end

         -- Still waiting on that hat
         self.status = RUNNING
         return
      end
   end
end




