local Cartographer = Class(function(self, inst)
    self.inst = inst
	--self.inst:StartUpdatingComponent(self) -- we'll schedule ourselves
	self.utilityMap = {}
	self.map = {}
	self.updateRate = 1 -- in seconds
	self.task = nil
	
	-- how far to graph based on current position
	self.mapOffset = 2
	self.resolution = 5
	
	self.circleRadius = 25
	self.circleMap = {}
	
	self.lastCircle = nil
	
	self:StartUpdate()
end)

-- An offset table. Basically, 0, 45, 90, etc degrees of a circle
local diag = math.sqrt(2)/2
local offsetTable = {
   -- horizontal axis, vertical axis
   -- in this game, x is north/south, z is east/west
   {0,1},
   {diag,diag},
   {1,0},
   {diag,-1*diag},
   {0,-1},
   {-1*diag,-1*diag},
   {-1,0},
   {-1*diag,diag}
}

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
   --local range_indicators = TheSim:FindEntities(pos.x,pos.y,pos.z, 2, {"range_indicator"} )
   --if #range_indicators < 1 then
   local range = SpawnPrefab("range_indicator")
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


function Cartographer:OnUpdate(dt)
   local pos = self.inst:GetPosition()
   if not pos then return end
   
   -- Are we within range of another circle?
   local closestCircle = FindEntity(self.inst, 2*self.circleRadius, function(c) return c.prefab == "range_indicator" end)
   
   -- If this is found, it means we are inside of a circle. Nothing to do.
   if closestCircle then
      local index = self:GetIndexFromCircle(closestCircle)
      if not index then
         print("Uhh, there is a circle not in our map?")
      else
         self.lastCircle = index
      end
      return
   end
   
   print("Checking for potential circle at " .. tostring(pos))
   
   -- Get 8 points in all directions and see if 
   --    there is any water in that path. If there
   --    is...not a valid place for a circle.
   local ground = GetWorld()
   local sTiles = {}
   table.insert(sTiles, ground.Map:GetTileAtPoint(pos.x, pos.y, pos.z))
   for k=1,8 do
      local offsetData = {}
      local offsetPos = {}
      offsetPos.x = pos.x + self.circleRadius*offsetTable[k][2]
      offsetPos.y = pos.y 
      offsetPos.z = pos.z + self.circleRadius*offsetTable[k][1]

      --print("Offset pos[" ..tostring(k) .. "] {" .. tostring(offsetPos.x) .. "," .. tostring(0) .. "," .. tostring(offsetPos.z) .. "}")
      
      
      local groundTile = ground.Map:GetTileAtPoint(offsetPos.x, offsetPos.y, offsetPos.z)
      if groundTile == GROUND.IMPASSABLE or groundTile >= GROUND.UNDERGROUND then
         print("Found water! Not a valid place for a circle.")
         return
      end
      table.insert(sTiles,groundTile)
   end
   
   -- This is a valid place!
   local circle = self:DropCircle()
   local index = #self.circleMap + 1
   
   -- Build some info about this location
   local info = {}
   
   -- Store the circle prefab for quick reference later
   info.circle = circle
   
   -- The circle does contain this pos...but when I go to save this map
   -- I can't save things with a Transform. So, I'll just generate the circles
   -- from the pos table onLoad
   info.pos = pos
   
   
   
   -- I want to save neighbor circles that are linked to this one. 
   --  1) The circle we came from will always link to this. 
   --  TODO: 2) Find the other closest circles and determine if we can walk to them. 
   
   info.linkedCircles = {}
   if self.lastCircle ~= nil then
      print("Last visited circle index: " .. tostring(self.lastCircle))
      -- Insert a link to the connected tables. 
      table.insert(info.linkedCircles, self.circleMap[self.lastCircle])
   end
   
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
   
   -- We are now technically in this circle. Update the index.
   self.lastCircle = index
   
end


return Cartographer