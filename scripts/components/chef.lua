local Chef = Class(function(self, inst)
   self.inst = inst
   self.healthRecs = {}
   self.hungerRecs = {}
   self.sanityRecs = {}
   
   -- These are things we've learned about. They should
   -- be saved.
   self.ct = {}
   self.knownRecipes = {}
   
   -- Generate an ordered list of recipes for the 3 vals we care about.
   -- Could persist this list on save...but then we wouldn't be able to
   -- adapt to new recipes (mods, etc). 
   self:GenerateBestRecipes()
   
   -- Test fcn
   self:InputHardCodedRecipes()
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

-- Until I figure out how to learn these things...
function Chef:InputHardCodedRecipes()
   local meatball_recipes = {
      {"ice","ice","ice","monstermeat"},
      {"ice","ice","berries","monstermeat"},
      {"ice", "berries", "berries", "monstermeat"},
      {"berries","berries","berries","monstermeat"}
   }
   self.knownRecipes["meatballs"] = meatball_recipes

end



function Chef:OnSave()
   -- Build the save data map
   local data = {}
   data.ct = self.ct
   data.knownRecipes = self.knownRecipes
   return data
end

-- Load our utility map
function Chef:OnLoad(data, newents)
   self.ct = data and data.ct or {}
   self.knownRecipes = data and data.knownRecipes or {}
end

-- This runs every game tick. Update the utility
function Chef:OnUpdate(dt)

end



-- Given our inventory, what can we make that is good.
-- What do we need right now? 
--    i.e. if we are low on health, health food is what we need
--         or low on sanity...sanity food
--         or low on hunger...hunger food!
--    If we aren't low on anything, then what will we want? 
--         Probably a mix of health and hunger food. 
--             Trailmix and meatballs usually...
function Chef:MakeSomethingGood()

   local listOfIngredients = self.inst.components.inventory:FindItems(function(item) 
                                             return cooking.IsCookingIngredient(item.prefab) end)
                                             
   -- print what ingredients we have
   for k,v in pairs(listOfIngredients) do
      local ings = cooking.ingredients[v.prefab]
      if ings then
         for i,j in pairs(ings.tags) do
            print(v.prefab)
            print(i,j)
         end
      end
   end
   
   -- Just test all combinations? 
   -- I mean...there should be some rhyme/reason to this.
   -- Maybe I have a list of 'good' recipes and just go down the list and see
   -- if I can make it with what I've got.
   
   --[[
   local ingredients = {}  
   for k,v in pairs(listOfIngredients) do
      -- Seriously..this seems like it will be a lot to search through.
      -- For testing...let's return the first thing that we can make (that isn't wet goop)
      
      local num = 1
      if v.components.stackable then
         num = v.components.stackable:StackSize()
      end
      
      if #ingredients < 4 then
         table.insert(ingredients, v.prefab)
      end
      
      if #ingredients == 4 then
         break
      end
      
   end
   
   --]]

end

-- Call this when 
function Chef:MakeMeASandwich(result, cooker)

end

local function recursiveCheck(array, keys, level)
   if not level then level = 1 end
   local key = keys[level]

   -- Made it to the end. Return final value
   if level == 4 then return array[key] end

   return array[key] and recursiveCheck(array[key],level+1) or false
end

function Chef:HasComboBeenTested(combo)
   -- Sort the elements of the combo array by strings
   local sorted = {}
   for n in pairs(combo) do table.insert(sorted,n) end
   table.sort(sorted)

   return recursiveCheck(self.ct, sorted)
end

-- Damn local functions. This is straight from cooking -------
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


-- Compres our inventory into the ingredient tags. From there
-- we can generate all possible combinations of ingredients and 
-- see what we can make

-- TODO: Should bound this in case list is huge
local function GetAllRepeatedCombinations(list, maxChoose, output, startIndex, numChosenSoFar, currentCombo)
   if not startIndex then startIndex = 1 end
   if not numChosenSoFar then numChosenSoFar = 0 end
   if not output then output = {} end
   if not currentCombo then currentCombo = {} end
   
   -- Need to copy the temp table to a new array
   if numChosenSoFar == maxChoose then
      local tempCombo = {}
      print("Found combination: ")
      for k,v in pairs(currentCombo) do
         print(v)
         tempCombo[k] = v
      end
      
      table.insert(output, tempCombo)
      return
   end
   
   local index = 1
   for k,v in pairs(list) do
      if index >= startIndex then
         currentCombo[numChosenSoFar + 1] = list[index]
         GetAllRepeatedCombinations(list, maxChoose, output, index, numChosenSoFar+1, currentCombo)
      end
      index = index + 1
   end
   
   return output
   
end

function Chef:WhatCanIMake()

   -- Get a list of all viable food in our inventory
   local candidateFood = self.inst.components.inventory:FindItems(function(item) 
                                       return cooking.IsCookingIngredient(item.prefab) end)
                                       
   local prefabList = {}
   
   -- Generate a unique list of all prefabs we have
   for k,v in pairs(candidateFood) do
      table.insert(prefabList,v.prefab)
   end
   
   print("Inventory food to check:")
   for _,v in pairs(prefabList) do 
      print(v)
   end
   

   -- Get all repeated combinations of this stuff...
   -- TODO: This assumes we have 4 of each of these!
   --       need to be able to tell it how many of each we have
   --       so it will not use more than that in the list!!!
   local combos = GetAllRepeatedCombinations(prefabList,4)
   
   if #combos == 0 then
      print("No combinations found")
      return
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
      print("Checking possible recipes for " .. tostring(i))
      for k,v in pairs(cooking.recipes.cookpot) do
         if v.test("cookpot", j.names, j.tags) then
            candidates[v.name] = v
         end
      end
   end   

   
   print("We can make: ")
   for k,v in pairs(candidates) do
      print(candidates[k].name)
   end
                                             
end


return Chef