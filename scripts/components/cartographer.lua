local Cartographer = Class(function(self, inst)
    self.inst = inst
	self.inst:StartUpdatingComponent(self) -- register for the OnUpdate call
	self.utilityMap = {}
end)


-- This runs every game tick. Update the utility
function Cartographer:OnUpdate(dt)
	
end


return Cartographer