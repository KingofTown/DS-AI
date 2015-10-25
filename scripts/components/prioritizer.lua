local Prioritizer = Class(function(self, inst)
   self.inst = inst
   --self.inst:StartUpdatingComponent(self) -- register for the OnUpdate call
   
   -- Contains a list of prefabs and/or GUIDs to ignore while collecting stuff
   self.ignore_list = {}
   
   -- Contains a list of things to research and build. May even expand so that
   -- he will build these things asap after collecting the right resources. 
   -- Currently, will only build later if needs to stand by a science machine
   self.build_order = {}
   self.build_parameters = {}
   self.try_ignore_dist = 30
end)

function Prioritizer:OnSave()
   -- Build the save data map
   local data = {}
   data.ignore_list = self.ignore_list
   data.build_order = self.build_order
   data.build_parameters = self.build_parameters
   return data
end

-- Load our utility map
function Prioritizer:OnLoad(data, newents)
   print("Prioritizer:OnLoad called")
   self.ignore_list = data and data.ignore_list or {}
   self.build_order = data and data.build_order or {}
   self.build_parameters = data and data.build_parameters or {}
end

-- This runs every game tick. Update the utility
function Prioritizer:OnUpdate(dt)
   -- Uncommned the 'startupdatingcomponent' to run this
   if not self.inst.brain.HostileMobNearInst then return end
end

------------------- IGNORE_LIST stuff ---------------------------
function Prioritizer:OnIgnoreList(prefab)
   if not prefab then return false end
   if self.ignore_list[prefab] == nil then return false end
   if self.ignore_list[prefab].always then return true end
      
   -- Loop through the positions and compare with current pos
   for k,v in pairs(self.ignore_list[prefab].posTable) do
      local dsq = self.inst:GetDistanceSqToPoint(v)
      if dsq then
         if dsq <= self.try_ignore_dist*self.try_ignore_dist then
             --print("Too close to a point we tried before")
             return true             
         end
       end
   end
   
   print("We can try " .. tostring(prefab) .. " again...")
   return false
end

function Prioritizer:AddToIgnoreList(prefab, fromPos)
   if not prefab then return end

   --IGNORE_LIST[prefab] = fromPos or 1
   
   if self.ignore_list[prefab] == nil then
      print("Adding " .. tostring(prefab) .. " to the ignore list")
      self.ignore_list[prefab] = {}
      self.ignore_list[prefab].posTable = {}
      self.ignore_list[prefab].always = false
   end
   
   -- If this is defined, it means we want to ignore ALL types
   -- of this prefab.
   if not fromPos then 
      self.ignore_list[prefab].always = true
   else
      -- We only want to ignore this specific GUID from this
      -- specific region
      print("...updating ignore with pos: " .. tostring(fromPos))
      table.insert(self.ignore_list[prefab].posTable, fromPos)
   end
end

function Prioritizer:RemoveFromIgnoreList(prefab)
   if not prefab then return end
   if self:OnIgnoreList(prefab) then
      self.ignore_list[prefab] = nil
   end
end

-- For debugging 
function Prioritizer:GetIgnoreList()
    return self.ignore_list
end

-----------------------------------------------------------------------

------------------- BUILD_ORDER stuff ---------------------------------

-- Adds a prefab to the build list. If topOfList is true, will move it
-- to the top. It may get pushed down by other things later...but it means
-- you want this built asap
function Prioritizer:AddToBuildList(toBuild, build_params, topOfList)
   -- build_params contain things like, onsuccess, onfail, pos...and whatever else 
   -- these can be nil if there isn't anything important about it
   
   -- The BUILD_PRIORITY list will be defined as
   -- {
   --   {prefab="prefab", info={info}},
   --   {prefab="prefab", info={info}},
   --   {prefab="diffPre", info={info}},
   -- }
   -- ...
   -- When requesting next thing to build, it is just
   -- table.remove(BUILD_PRIORITY,1) which shifts everything up by one. 
   
   local table_entry = {prefab=toBuild, info=build_params}
   if not topOfList then
      table.insert(self.build_order, table_entry)
   else
      table.insert(self.build_order, 1, table_entry)
   end
   
end

-- Probably not needed...but to remove something, the prefab and build_params must match
-- If there are multiple with the same params...don't care. This will just remove the first
-- match
function Prioritizer:RemoveFromBuildList(toBuild, build_params)
   for k,v in pairs(self.build_order) do
      if v.prefab == toBuild and v.build_params == build_params then
         table.remove(self.build_order, k)
         break
      end
   end
end














return Prioritizer