

function IsItemBackpack(item)
   if not item then return false end
      -- Have to use the not operator to cast to true/false.
      return not not item.components.equippable and not not item.components.container
   end

function IsWearingBackpack(inst)
   if not inst.components.inventory then return false end
   local bodyslot = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
   return IsItemBackpack(bodyslot)
end

-- Will maintain a list of properties/items that should/should not go into a backpack.

local notInBackpack = {}
notInBackpack["log"] = 1
notInBackpack["twigs"] = 1
notInBackpack["cutgrass"] = 1
notInBackpack["torch"] = 1


function ShouldGoInBackpack(item)
    -- Don't ever put weapons or armor in there
    if item.components.armor or item.components.weapon then return false end
    
    -- Don't put essentials in there
    if notInBackpack[item.prefab] then return false end
    
    -- Anything else...sure, why not
    return true
end

-- Returns true only if the item can fit in an existing stack in the inventory.
function CanFitInStack(inst,item)
   if not inst.components.inventory then return false end
    
   local inInv = inst.components.inventory:FindItems(function(i) return item.prefab == i.prefab end)
   for k,v in pairs(inInv) do
      if v.components.stackable then
        if not v.components.stackable:IsFull() then
           return true
        end
      end
   end
   return false
end

-- Transfers one (or all) of the item in the fromContainer to the toContainer
function TransferItemTo(item, fromInst, toInst, fullStack)

   if not item or not fromInst or not toInst then return false end
   
   local fromContainer = fromInst.components.inventory and fromInst.components.inventory or fromInst.components.container
   local toContainer = toInst.components.inventory and toInst.components.inventory or toInst.components.container

   if not fromContainer or not toContainer then 
      print("TransferItemTo only works with type inventory or type container")
      return false 
   end
      
   -- Passing GetScreenPosition will make the item sail across the screen all fancy like
   local success = toContainer:GiveItem(item,nil,TheInput:GetScreenPosition(),false,false)
   --local success = toContainer:GiveItem(item)

   -- If this worked, remove them from the other container   
   if success then
      fromContainer:RemoveItem(item, fullStack)
   end
   
   
   return success

end