local Chef = Class(function(self, inst)
   self.inst = inst
   self.healthRecs = {}
   self.hungerRecs = {}
   self.sanityRecs = {}
   
   -- Populate the above tables
   self:GenerateBestRecipes()

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
   return data
end

-- Load our utility map
function Chef:OnLoad(data, newents)

end

-- This runs every game tick. Update the utility
function Chef:OnUpdate(dt)

end

function Chef:MakeSomethingGood()

end

-- Call this when 
function Chef:MakeMeASandwich(result, cooker)

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

-- Takes the entire inventory and generates a list 
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
   
   -- TODO: Store the actual 4 combos for each recipe in the final table
   --       so we can just iterate through that to get the 4 ingredients
   --       we want to use.
   
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
         if v.test("cookpot", j.names, j.tags) then
            candidates[v.name] = v
         end
      end
   end   

   
   local t2 = os.clock()

   if self.inst:HasTag("debugPrint") then
      print("We can make: ")
      for k,v in pairs(candidates) do
         print(candidates[k].name)
      end
      print("CPU Time: " .. os.difftime( t2, t1 ) )
   end
   

                                             
end


return Chef