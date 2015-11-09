local Cartographer = Class(function(self, inst)
    self.inst = inst
	--self.inst:StartUpdatingComponent(self) -- we'll schedule ourselves
	self.utilityMap = {}
	self.map = {}
	self.updateRate = .5 -- in seconds
	self.task = nil
	
	-- how far to graph based on current position
	self.mapOffset = 2
	self.resolution = 5
	
	self.circleRadius = 10
	self.circleMap = {}
	
	-- The number of points to test around each
   -- circle.
   self.numPoints = 16
	
	-- Contains self.numPoints equadistant points
	-- around a unit circle.
	self.offsetTable = {}
	
	-- Genearte the offsetTable above
	local slices = 2*math.pi / self.numPoints
	for i=1,self.numPoints do
	  local angle = slices*i
	  local entry = {}
	  entry.x = math.cos(angle)
	  entry.z = math.sin(angle)
	  table.insert(self.offsetTable,entry)
	end
	
	
	self.lastCircle = nil
	
	self:StartUpdate()
end)


function Cartographer:OnSave()
	-- Build the save data map
	local data = {}
	-- Add the stuff to save
	data.map = self.map
	data.resolution = self.resolution
	data.utilityMap = self.utilityMap
	
	-- Before we can save this circleMap, we have
	-- to get rid of the actual circles
	for k,v in pairs(self.circleMap) do
	  v.circle = nil
	end
	data.circleMap = self.circleMap
	-- Return the map
	return data
end

-- Load our utility map
function Cartographer:OnLoad(data, newents)
   -- If the saved resolution is different than
   -- the default, it means I've changed it. Clear the
   -- saved map.
   if data and data.resolution then
      if self.resolution ~= data.resolution then
         self.map = {}
      else
         self.map = data and data.map or {}
      end
   end
   
	if data and data.utilityMap then
		self.utilityMap = data.utilityMap
	end
	
	if data and data.circleMap then
	  -- Draw the circles again
	  self.circleMap = data.circleMap
	  for k,v in pairs(data.circleMap) do
	     if v.pos then
	        v.circle = self:DropCircle(v.pos)
	        
	     end
	  end
	end
end

function Cartographer:StartUpdate()
   if not self.task then
      self.task = self.inst:DoPeriodicTask(self.updateRate, function() self:OnUpdate(self.updateRate) end)
   end
end


-- Draws a circle at our current point
function Cartographer:DropCircle(circlePos)
   local pos = circlePos or Point(self.inst.Transform:GetWorldPosition())
   local range = SpawnPrefab("range_indicator")
   
   -- The circle is 625px wide...so scale it based on the radius
   local scale = math.sqrt((self.circleRadius/6.25))
   
   range.Transform:SetScale(scale,scale,scale)
   range.Transform:SetPosition(pos.x, pos.y, pos.z)
   return range
end

function Cartographer:GetIndexFromCircle(circle)
   for k,v in pairs(self.circleMap) do
      if v.circle == circle then
         return k
      end
   end
end

function Cartographer:CheckForWater(pos)
   local test = function(offset)
      local testPoint = pos + offset
      local ground = GetWorld()
      local tile = ground.Map:GetTileAtPoint(testPoint.x, testPoint.y, testPoint.z)
      if tile == GROUND.IMPASSABLE then
         return true
      end
   end

   return FindValidPositionByFan(0, 1, 4, test)
end

-- Given a point {x,y,z}, determines if a circle can be placed here.
-- Checks for water and overlapping circles.
-- Returns true if a circle can be placed here.
-- Returns false otherwise.
-- If false, the sTiles  will not be complete maps...just 
--    the points up to the point where water was found.
-- Else, sTiles will contain a list of all ground types at each point.

function Cartographer:CanPlaceCircleAtPoint(p, sTiles)
   if not p and not p.x and not p.y and not p.z then return false end
   
   -- Don't want circles at exactly 2*rad..so subtracting a tiny bit
   local closestCircles = TheSim:FindEntities(p.x,p.y,p.z, 2*self.circleRadius-.1, {"range_indicator"}, {"exit_circle"})
   if #closestCircles ~= 0 then
      return false
   end
   
   local ground = GetWorld()
   
   for k=1,self.numPoints do
      local offsetPos = {}
      offsetPos.x = p.x + self.circleRadius*self.offsetTable[k].x
      offsetPos.y = p.y 
      offsetPos.z = p.z + self.circleRadius*self.offsetTable[k].z
      local groundTile = ground.Map:GetTileAtPoint(offsetPos.x, offsetPos.y, offsetPos.z)
      if groundTile == GROUND.IMPASSABLE or groundTile >= GROUND.UNDERGROUND then
         --print("Found water! Not a valid place for a circle.")
         return false
      elseif sTiles then
         table.insert(sTiles,groundTile)
      end
   end
   
   -- Yay, it's valid.
   return true
end

-- Links these 2 circles together. Checks for existing entries
-- and stuff like that.
function Cartographer:ConnectCircles(aIndex, bIndex)
   local aCircle = self.circleMap[aIndex]
   local bCircle = self.circleMap[bIndex]
   
   -- Nothing to do if they don't exist
   if not aCircle and bCircle then
      print("Cannot connect " .. tostring(aIndex) .. " and " .. tostring(bIndex))
      return
   end
   
   local circles = {}
   table.insert(circles, aCircle)
   table.insert(circles, bCircle)
   
   for k,v in pairs(circles) do
      local otherIndex = (v.index == aIndex and bIndex or aIndex)
      -- Add to each other's map
      local exists = false
      for i,j in pairs(v.linkedCircles) do
         if j == otherIndex then
            exists = true
            break
         end
      end
      if not exists then
         print("New entry! Adding " .. tostring(otherIndex) .. " to " .. tostring(v.index) .. " linkedCircles!")
         -- Just store the index in this list.
         table.insert(v.linkedCircles, otherIndex)
      end
   end
end

function Cartographer:OnUpdate(dt)
   local pos = self.inst:GetPosition()
   if not pos then return end
   
   -- Are we within range of another circle?
   local closestCircle = FindEntity(self.inst, 2*self.circleRadius-.1, function(c) return c.prefab == "range_indicator" and not c:HasTag("exit_circle") end)
   
   -- If this returns something, a new circle will overlap an existing one. 
   if closestCircle then
      local distToCircleSq = self.inst:GetDistanceSqToInst(closestCircle)
      local index = self:GetIndexFromCircle(closestCircle)
      if not index then
         print("Uhh, there is a circle not in our map?")
      elseif distToCircleSq <= self.circleRadius*self.circleRadius then
         -- We are actually standing inside of a circle right now. Make this our
         -- 'last circle'. 
         self.lastCircle = index
      end
      return
   end
   
   -- We are at a point where there is no overlap. Check for water.
   --print("Checking for potential circle at " .. tostring(pos))
   
   local ground = GetWorld()
   local sTiles = {}
   local exitPositions = {}
   
   -- Insert this current tile into the temp sTiles map.
   table.insert(sTiles, ground.Map:GetTileAtPoint(pos.x, pos.y, pos.z))
   
   -- Check for water. Also keep track of the tiles at each point.
   for k=1,self.numPoints do

      -- Offset pos are the points ON the circle. Use those to check
      -- for water.
      local offsetPos = {}
      offsetPos.x = pos.x + self.circleRadius*self.offsetTable[k].x
      offsetPos.y = pos.y 
      offsetPos.z = pos.z + self.circleRadius*self.offsetTable[k].z
      
      local exitPos = {}
      exitPos.x = pos.x + 2*self.circleRadius*self.offsetTable[k].x
      exitPos.y = pos.y
      exitPos.z = pos.z + 2*self.circleRadius*self.offsetTable[k].z
      table.insert(exitPositions,Vector3(exitPos.x,exitPos.y,exitPos.z))

      --[[
      local isWater = self:CheckForWater(offsetPos)
      if isWater then
         print("Found water! Not a valid place for a circle")
         return
      end
      --]]
      
      local groundTile = ground.Map:GetTileAtPoint(offsetPos.x, offsetPos.y, offsetPos.z)
      if groundTile == GROUND.IMPASSABLE or groundTile >= GROUND.UNDERGROUND then
         --print("...not here...there's water!")
         return
      end
      
      -- This is a valid point (no water). Add the tile type to the list.
      table.insert(sTiles,groundTile)
   end
   
   
   -- We've looped through the entire list and have not found water. This is a good spot.
   local circle = self:DropCircle()
   local index = #self.circleMap + 1
   
   -- Build some info about this location
   local info = {}
   
   -- Store the circle prefab for quick reference later
   info.circle = circle
   
   -- The key is the index...but I store it here too for reverse lookup.
   info.index = index
   
   -- The circle does contain this pos...but when I go to save this map
   -- I can't save things with a Transform. So, I'll just generate the circles
   -- from the pos table onLoad
   info.pos = pos
   
   -- Create a table to store our linked circles and exit nodes
   info.linkedCircles = {}
   info.exitNodes = {}
   

   -- Find the majority of the tiles around this point and mark this as
   -- one of those places.
   local popular = {}
   for k,v in pairs(sTiles) do
      if popular[v] == nil then
         popular[v] = 1
      else
         popular[v] = popular[v] + 1
      end
   end
   -- Sort ascending order. 
   table.sort(popular, function(a,b) return a > b end)
   
   -- Actually...just store this whole array. It'll probably be useful
   info.tiles = popular
   
   -- Store this info in the map. 
   self.circleMap[index] = info
   
   -- Link this circle to the last one we were in
   if self.lastCircle ~= nil then
      self:ConnectCircles(index, self.lastCircle)
   end
   
   
   -- We are now technically in this circle. Mark it as the
   -- 'lastCircle'
   self.lastCircle = index

   -- Finally, calculate the exit nodes from this circle.
   self:FindExitNodesFrom(index, exitPositions)
end

-- Given an index for a circle and a list of points,
-- determine of those points are valid exits.
-- exitPoints should be a list of points
function Cartographer:FindExitNodesFrom(index, exitPoints)
   local circleInfo = self.circleMap[index]
   if not circleInfo then
      print("FindExitNodesFrom: Index = " .. tostring(index) .. " does not exist")
      return 
   end
   
   local ground = GetWorld()
   local p = circleInfo.pos
   
   local allCircles = TheSim:FindEntities(p.x,p.y,p.z,3*self.circleRadius,{"range_indicator"},{"exit_circle"})
   
   if #allCircles == 0 then
      print("No circles within 3*" .. tostring(self.circleRadius))
   end
   
   -- Exclude circles that we cannot walk to
   local potentialCircles = {}
   for k,v in pairs(allCircles) do
      -- Ignore self circle
      local dIndex = self:GetIndexFromCircle(v)
      if dIndex ~= index then
         local angleToPoint = circleInfo.circle:GetAngleToPoint(v:GetPosition())
         print("Checking circle at angle: " ..tostring(angleToPoint))
         -- Determine if we can even walk to this circle (could be across a river)
         local offset, angle, deflected = FindWalkableOffset(p,angleToPoint*DEGREES,3*self.circleRadius,2,true,true)
         -- If offset is nil, we couldn't walk to this circle. Ignore it.
         if offset then
            print("Adding circle " .. tostring(dIndex) .. " to potentialCircles")
            --table.insert(potentialCircles, self.circleMap[dIndex])
            potentialCircles[dIndex] = self.circleMap[dIndex]
            
            -- We can walk to this. Link it as a connected circle
            self:ConnectCircles(index, dIndex)
         else
            print("We cannot walk to circle " .. tostring(dIndex))
         end
      end
   end
   
   -- Now, loop through all of these circles' exit nodes and remove
   -- them if they overlap with this circle
   for k,v in pairs(potentialCircles) do
      for i,j in pairs(v.exitNodes) do
         local dsq = circleInfo.circle:GetDistanceSqToPoint(j)
         if math.sqrt(dsq) < 2*self.circleRadius then
            print("Exit node: " .. tostring(i) .. " of circle " .. tostring(k) .. " overlaps with new circle. Removing.")
            self.circleMap[k].exitNodes[i] = nil
            
            -- For testing...remove the green exit circle that overlaps
            local exitCircles = TheSim:FindEntities(j.x,j.y,j.z, 2*self.circleRadius, {"exit_circle"})
            for p,q in pairs(exitCircles) do
               q:Remove()
            end

         end
      end
   end
   
   -- Loop through all exitPoints and determine if it is a valid exit.
   -- TODO: maybe combine this with the above loop to save some cycles? don't
   --       care right now.
   for k,v in pairs(exitPoints) do
      -- 1) Can we draw a circle here. If so, add it as an exit.
      --    This function should check for overlapping circles
      --    and water.
      --print("Checking for exit at " .. tostring(v))
      -- TEST THINGY
      --local testThingy = SpawnPrefab("teleportato_ring")
      --testThingy.Physics:Teleport(v:Get())
      -------
      if self:CanPlaceCircleAtPoint(v) then
         --print("Found exit at " .. tostring(v))
         local exitCircle = self:DropCircle(v)
         exitCircle:AddTag("exit_circle")
         exitCircle.AnimState:SetMultColour(.25,5,.5,.75)
         table.insert(circleInfo.exitNodes, v)
      end
      
   end
   
end


return Cartographer