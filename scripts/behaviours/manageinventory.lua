require "brains/ai_inventory_helper"

ManageInventory = Class(BehaviourNode, function(self, inst)
   BehaviourNode._ctor(self, "ManageInventory")
   self.inst = inst
end)

-- If we ever get blueprints...learn it right away
function ManageInventory:CheckForBlueprints()
   local blueprints = self.inst.components.inventory:FindItems(function(item) return item.components.teacher ~= nil end)
   
   if blueprints then
      for k,v in pairs(blueprints) do
         -- Skipping the push action bs...let's just learn the damn thing
         v.components.teacher:Teach(self.inst)
      end
   end
end

-- Keep less important things in the backpack
function ManageInventory:BackpackManagement()

   -- If we don't have a backpack or are not standing near a chest...nothing to do.
   -- Not sure if basemanager should handle the chest part as there are probably 
   -- specific places to put things. Just checking backpack here.
   if not IsWearingBackpack(self.inst) then
      self.status = FAILED
      return
   end
   
   local backpack = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
   
   -- We're wearing a backpack. Put stuff in there!
   -- Loop through our inventory and put anything we can in there.
   local inv = self.inst.components.inventory
   for k=1,inv:GetNumSlots() do
      local item = inv:GetItemInSlot(k)
      if item then
         if ShouldGoInBackpack(item) then
            -- Just because it should go doesn't mean there is room. Find a slot.
            -- This fcn will return false if not successful. Should maybe
            -- do something with that return value...
            TransferItemTo(item,self.inst,backpack,true)
         end
      end
   end
   
   -- Loop through the backpack and move things that shouldn't go there to our inventory
   local bpInv = backpack.components.container
   for k=1, bpInv:GetNumSlots() do
      local item = bpInv:GetItemInSlot(k)
      if item then
         if not ShouldGoInBackpack(item) then
            TransferItemTo(item,backpack,self.inst,true)
            self.status = SUCCESS
            return
         end
      end
   end

end

-- Sometimes we get full of useless stuff. 
-- Do something about it
function ManageInventory:FreeUpSpace()
   if not self.inst.components.inventory:IsTotallyFull() then
      return
   end
   
   print("Free up space!")
   
   -- We're completely full. Lets eat some food first to make some space
   -- Just call this directly
   --self.inst.components.eater:Eat(obj)

   local allFoodInInventory = self.inst.components.inventory:FindItems(function(item) return 
                        self.inst.components.eater:CanEat(item) and 
                        item.components.edible:GetHunger(self.inst) >= 0 and
                        item.components.edible:GetHealth(self.inst) >= 0 and
                        item.components.edible:GetSanity(self.inst) >= 0 and
                        ((item.components.stackable and item.components.stackable:StackSize() == 1) or 
                           (not item.components.stackable))
                        end)
   
   local healthMissing = self.inst.components.health:GetMaxHealth() - self.inst.components.health.currenthealth
   local hungerMissing = self.inst.components.hunger.max - self.inst.components.hunger.current
   local sanityMissing = self.inst.components.sanity.max - self.inst.components.sanity.current

   -- Eat one of them!
   for k,v in pairs(allFoodInInventory) do
      print(v.prefab)
      local h = v.components.edible:GetHunger(self.inst)
      local s = v.components.edible:GetSanity(self.inst)
      local he = v.components.edible:GetHealth(self.inst)
      
      -- Eat something that will give us value first. Otherwise...just eat
      -- the lowest utility one
      if h >= s and h >= he and h <= hungerMissing then
         -- These actions bypass the animation...bah
         self.inst.components.eater:Eat(v)
         return
      elseif s >= h and s >= he and s <= sanityMissing then
         self.inst.components.eater:Eat(v)
         return
      elseif he >=h and he >= s and he <= healthMissing then
         self.inst.components.eater:Eat(v)
         return
      end      
      
   end
   
   -- We didn't eat anything...just eat the first one
   if next(allFoodInInventory) ~= nil then
      local i,v = next(allFoodInInventory)
      self.inst.components.eater:Eat(v)
      return
   end
   
   -- We have no single foods. Drop something useles?

   
end

function ManageInventory:Visit()

   if self.status == READY then
   
      -- Any one of these can return or leave the node
      -- This is kind of a mini priority 
      self:CheckForBlueprints()
      self:BackpackManagement()
      
      self:FreeUpSpace()
      
      self.status = FAILED
   elseif self.status == RUNNING then
      -- Should never get to this state currently. 
      self.status = FAILED
   end
   
end
