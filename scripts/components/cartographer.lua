local Cartographer = Class(function(self, inst)
    self.inst = inst
	self.inst:StartUpdatingComponent(self) -- register for the OnUpdate call
	self.utilityMap = {}
end)

function Cartographer:OnSave()
	-- Build the save data map
	local data = {}
	-- Add the stuff to save
	data.utilityMap = self.utilityMap

	-- Return the map
	return data
end

-- Load our utility map
function Cartographer:OnLoad(data, newents)
	if data and data.utilityMap then
		self.utilityMap = data.utilityMap
	end
end

-- This runs every game tick. Update the utility
function Cartographer:OnUpdate(dt)
	
end


return Cartographer