

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