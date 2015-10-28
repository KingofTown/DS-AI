local Chef = Class(function(self, inst)
   self.inst = inst
   self.healthRecs = {}
   self.hungerRecs = {}
   self.sanityRecs = {}
   
   -- Populate the above tables
   self:GenerateBestRecipes()
   
   -- Every time WhatCanIMake is run, it 
   -- will store the results here. This allows
   -- us to just keep using these recipes until
   -- we determine we don't have enough ingredients
   -- and can just rerun the WhatCanIMake function
   -- as needed rather than every single time.
   self.knownRecipes = {}

end)

local cooking = require("cooking")

function Chef:GenerateBestRecipes()

   local function sortByHighest(a,b)
      if a.val == b.val then
         return a.priority > b.priority
      end
      return a.val > b.val
   end

   for k,v in pairs(cooking.recipes.cookpot) do
      if v.health > 0 then
         table.insert(self.healthRecs,{item=k,val=v.health,priority=v.priority})
      end
      if v.hunger > 0 then
         table.insert(self.hungerRecs,{item=k,val=v.hunger,priority=v.priority})
      end
      if v.sanity > 0 then
         table.insert(self.sanityRecs,{item=k,val=v.sanity,priority=v.priority})
      end
   end
   
   table.sort(self.healthRecs,sortByHighest)
   table.sort(self.hungerRecs,sortByHighest)
   table.sort(self.sanityRecs,sortByHighest)
end

function Chef:OnSave()
   -- Build the save data map
   local data = {}
   data.knownRecipes = self.knownRecipes
   return data
end

-- Load our utility map
function Chef:OnLoad(data, newents)
   self.knownRecipes = data and data.knownRecipes or {}
end

-- This runs every game tick. Update the utility
function Chef:OnUpdate(dt)
   
end

-- Generates the buffered action to cook something in
-- the closest cooker
function Chef:MakeSomethingGood(cooker, onsuccess, onfail)
   -- I could look for a stewer here...but all over I have 'cookpot' hard coded. 
   -- The only stewer in the game is a cookpot anyway. I could be flexible for mods, but
   -- i'll leave that as a TODO
   --local cooker = FindEntity(self.inst, 3, function(thing) return thing.prefab == "cookpot" end)
   if not cooker then return end
   
   -- Until I get a way to compare the last knownRecipes to current inv, just generating a new one every time
   self:WhatCanIMake()
   
   -- What am I making?
   local thingsToMake = nil
   if next(self.knownRecipes) == nil then
      self.knownRecipes = self:WhatCanIMake()
   end
   
   -- We don't know how to make anything. Should
   -- return a special value here so whoever called it knows
   -- why we aren't making something
   -- (no recipes, too far from a cooker, etc)
   if next(self.knownRecipes) == nil then
      print("We don't know how to make anything!")
      return
   end
   
   local whatImMaking = nil
   for k,v in pairs(self.knownRecipes) do
      -- If I'm low on health, make a good
      -- healing recipe. 
      -- TODO: Just going down all lists for now
       
      if whatImMaking ~= nil then
         break
      end
      
      for i,j in pairs(self.hungerRecs) do
         if j.item == k then
            whatImMaking = v
            break
         end
      end
      if not whatImMaking then
         for i,j in pairs(self.healthRecs) do
            if j.item == k then
               whatImMaking = v
               break
            end
         end      
      end
      
      if not whatImMaking then
         for i,j in pairs(self.sanityRecs) do
            if j.item == k then
               whatImMaking = v
               break
            end
         end   
      end  
   end
   
   -- Umm, even though we know recipes...we seem to not be able to make them
   if not whatImMaking then 
      print("Something went wrong...")
      return
   else
      print("Attempting to make " .. tostring(whatImMaking[1].recipe.name))
   end
   
   -- TODO: Make sure there's nothing in the cookpot already. If so, uhh...take it out?
   
   
   -- Open it to make it look like we're doing real stuff
   cooker.components.container:Open(self.inst)
   
   

   
      
   -- Until we get a utility function, just picking a random
   -- one from the list to make thing thing.
   local numCombos = #whatImMaking
   local randCombo = math.random(1,numCombos)
   print("Using combo # " .. tostring(randCombo))
   
   local invItems = {}
   local haveAllItems = true
   for prefab,num in pairs(whatImMaking[randCombo].combo.names) do
       -- Convert meat aliases back to their original. This is annoying.
      if prefab == "smallmeat_cooked" then
         prefab = "cookedsmallmeat"
      elseif prefab == "meat_cooked" then
         prefab = "coodedmeat"
      elseif prefab == "monstermeat_cooked" then
         prefab = "cookedmonstermeat"
      end  
      
      local ing = self.inst.components.inventory:FindItem(function(item) return item.prefab == prefab end)
      if not ing then
         print("Can not find " .. prefab .. " in our inventory!")
         haveAllItems = false
         break
      end
      
      local numHave = ing.components.stackable and ing.components.stackable:StackSize() or 1
      
      -- Do we have enough of this
      if numHave >= num then
         for z=1,num do
            table.insert(invItems,ing)
         end
      else
         print("Recipe requires " .. tostring(num) .. " " .. prefab .. " but we only have " .. tostring(numHave))
         haveAllItems = false
         break
      end
   end
   
   if not haveAllItems then
      print("We don't have all of the items in our inventory!")
      return
   end
   
   local tdelay = .25
   local interval = .25
   for k,v in pairs(invItems) do
      -- There should be 4 things here. I put the same thing in multiple spots if 
      -- the combo called for duplicates to make it easier.
      self.inst:DoTaskInTime(tdelay,function() TransferItemTo(v,self.inst,cooker,false) end)
      tdelay = tdelay+interval
   end
   
   
   --[[
   -- Need to trade for ingredients to the cooker. 
   -- TODO: Cooking uses _cooked food as regular. A recipe
   --       will just say "berries", but can take either. Need
   --       to account for that.
   local tdelay = .25
   local interval = .25
   for prefab,num in pairs(whatImMaking[randCombo].combo.names) do
      -- Convert meat aliases back to their original. This is annoying.
      if prefab == "smallmeat_cooked" then
         prefab = "cookedsmallmeat"
      elseif prefab == "meat_cooked" then
         prefab = "coodedmeat"
      elseif prefab == "monstermeat_cooked" then
         prefab = "cookedmonstermeat"
      end
   
      local ing = self.inst.components.inventory:FindItem(function(item) return item.prefab == prefab end)
      if not ing then
         print("Could not find " .. prefab .. " in inventory!")
         return
      end
      for k=1,num do
         print("Transfering " .. ing.prefab .. " to the cooker")
         self.inst:DoTaskInTime(tdelay,function() TransferItemTo(ing,self.inst,cooker,false) end)
         tdelay = tdelay+interval
         --TransferItemTo(ing,self.inst,cooker,false)
      end
   end
   
   --]]
   
   print("The cookpot should have shit in it by now!")
   
   -- Doing this with a slight delay so we can see the stuff in the container for a sec
   local action = BufferedAction(self.inst,cooker,ACTIONS.COOK)
   action:AddFailAction(function() if onfail then onfail() end end)
   action:AddSuccessAction(function() if math.random() < .4 then self.inst.components.talker:Say("I'm mother fucking Gordon Ramsay") end if onsuccess then onsuccess() end end)
   
   -- Doing this with a slight delay so it's not so BAM IM DONE!
   self.inst:DoTaskInTime(tdelay+(2*interval), function() self.inst.components.locomotor:PushAction(action,true) end)
   
   return action
   
end


----------------------------------------------------------------
-- The following are stolen straight from "cooking.lua"
-- This is taken from the RoG file...so hopefully it works with
-- the base game. It looks like it should, it's mostly doing
-- string compares.
local aliases=
{
   cookedsmallmeat = "smallmeat_cooked",
   cookedmonstermeat = "monstermeat_cooked",
   cookedmeat = "meat_cooked"
}

local null_ingredient = {tags={}}
local function GetIngredientData(prefabname)
   local name = aliases.prefabname or prefabname

   return cooking.ingredients[name] or null_ingredient
end

local function GetIngredientValues(prefablist)
   local prefabs = {}
   local tags = {}
   for k,v in pairs(prefablist) do
      local name = aliases[v] or v
      prefabs[name] = prefabs[name] and prefabs[name] + 1 or 1
      local data = GetIngredientData(name)

      if data then

         for kk, vv in pairs(data.tags) do

            tags[kk] = tags[kk] and tags[kk] + vv or vv
         end
      end
   end

   return {tags = tags, names = prefabs}
end
---------------------------------------------------------------


-- Recursive function to generate all combinations 
-- Formula for computing k-combination with repitition from n elements is: (n+k-1k) = (n+k-1n-1)
local function GetAllRepeatedCombinations(list, maxChoose, output, startIndex, numChosenSoFar, currentCombo)
   if not startIndex then startIndex = 1 end
   if not numChosenSoFar then numChosenSoFar = 0 end
   if not output then output = {} end
   if not currentCombo then currentCombo = {} end
   
   -- Need to copy the temp table to a new array
   if numChosenSoFar == maxChoose then
      local tempCombo = {}
      --print("Found combination: ")
      for k,v in pairs(currentCombo) do
         --print(v)
         tempCombo[k] = v
      end
      
      table.insert(output, tempCombo)
      
      currentCombo = {}
      return
   end
   
   local function haveEnough(item)
      local count = 0
      for k,v in pairs(currentCombo) do
         if v == item.prefab then
            count = count + 1
         end
      end
      return  count >= (item.components.stackable and item.components.stackable:StackSize() or 1)
   end
   
   local index = 1
   for k,v in pairs(list) do
      if index >= startIndex and not haveEnough(list[index]) then
         currentCombo[numChosenSoFar + 1] = list[index].prefab
         GetAllRepeatedCombinations(list, maxChoose, output, index, numChosenSoFar+1, currentCombo)
      end
      index = index + 1
   end
   return output
end

-- Takes the entire inventory and generates a list of what we can make
function Chef:WhatCanIMake()
   local t1 = os.clock()

   -- Get a list of all viable food in our inventory
   local candidateFood = self.inst.components.inventory:FindItems(function(item) 
                                       return cooking.IsCookingIngredient(item.prefab) end)
                                       
   -- Get all repeated combinations of this stuff...
   local combos = GetAllRepeatedCombinations(candidateFood,4)
   
   if self.inst:HasTag("debugPrint") then
      if #combos == 0 then
         print("No combinations found")
         return
      else
         print("Found " .. #combos .. " combinations")
      end
   end
      
   -- Generate a table of ingredients from this
   local combo_ingredients = {}
   for k,v in pairs(combos) do
      local t = {}
      t = GetIngredientValues(v)
      table.insert(combo_ingredients,t)
   end
   
   -- Now, try all recipes with our combos
   local candidates = {}
   for i,j in pairs(combo_ingredients) do
      --print("Checking possible recipes for " .. tostring(i))
      for k,v in pairs(cooking.recipes.cookpot) do
      
         -- Don't test for wetgoop
         if v.name ~= "wetgoop" then
         
            -- TODO: Need to sort this by priority. It might say we can 
            --       make X with the given combo, but it will really make
            --       Y as Y is a higher priority. 
            --       Maybe only store the highest priority combo in here...
            --       but then again, it will roll a die and potentially make
            --       the other thing too.
            if v.test("cookpot", j.names, j.tags) then
               local entry = {}
               entry.combo = j
               entry.recipe = v
               
               if not candidates[v.name] then
                  candidates[v.name] = {}
               end
               
               table.insert(candidates[v.name],entry)

            end
         end
      end
   end   

   
   local t2 = os.clock()
   
   self.knownRecipes = candidates

   if self.inst:HasTag("debugPrintAll") then
      print("We can make: ")
      for k,v in pairs(candidates) do
         print(tostring(k) .. " with: ")
         for i,j in pairs(v) do
            for p,q in pairs(j.combo.names) do 
               print("   " .. tostring(q) .. " " .. tostring(p))
            end
            print("  ****")
         end
      end
      print("CPU Time: " .. os.difftime( t2, t1 ) )
   end
   
   -- Returns true if we have at least one thing we can make
   return next(self.knownRecipes) ~= nil
                 
end


return Chef