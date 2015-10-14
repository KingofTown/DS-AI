local CLEARING_DISTANCE = 5

local BASE_BUILDING_PRIORITY = {
		"firepit",
		"treasurechest",
}

local BaseBuilder = Class(function(self, inst)
    self.inst = inst
	self.inst:StartUpdatingComponent(self) -- register for the OnUpdate call
	
	self.baseSize = 0
	self.baseMap = {}
end)

function BaseBuilder:OnSave()
	-- Build the save data map
	local data = {}
	-- Add the stuff to save
	--self.baseMap = baseMap
	-- Return the map
	return data
end

-- Load our utility map
function BaseBuilder:OnLoad(data, newents)
	if data and data.utilityMap then
		self.utilityMap = data.utilityMap
	end
end

-- This runs every game tick. Update the utility
function BaseBuilder:OnUpdate(dt)

end

function BaseBuilder:CheckBase()
	print("CHECKING BASE")

	local obsticle = nil
	local homePos = self.inst.components.homeseeker.home
	if homePos ~= nil then
		obsticle = FindEntity(homePos,self.baseSize + CLEARING_DISTANCE,function(thing) return self:IsObsticle(thing) end)
	end
	
	local baseBuildings = FindEntity(homePos,self.baseSize + 2,function(thing) return self:IsPartOfBase(thing) end)
	print(baseBuildings)
	
	if false then
		-- Build the essentials (firepit, chest)
	elseif obsticle ~= nil and next(obsticle) ~= nil and self:GetItem("shovel") then
		self:RemoveObsticle(next(obsticle))
	else
		-- Build up our base
		for k,v in pairs(BASE_BUILDING_PRIORITY) do
			if baseBuildings == nil or baseBuildings[v] == nil then			
				if CanPlayerBuildThis(self.inst, v) then
					self:BuildThis(v)
				end
			end
		end
	end
end

function BaseBuilder:BuildThis(thing)
	print("BUILD THIS: " .. thing)
	self.inst.components.brain:SetSomethingToBuild(v)
end

function BaseBuilder:IsObsticle(thing)
	print("Is this an obsticle???  ")
	print(thing)
	if thing == nil then
		return false
	elseif not thing.prefab then
		return false
	elseif thing.prefab == "sapling" then
		return true
	elseif thing.prefab == "seeds" then
		return true
	elseif thing.prefab == "evergreen" then
		return true
	elseif thing.prefab == "evergreen_sparse" then
		return true
	elseif thing.prefab == "log" then
		return true
	else
		return false
	end
end

function BaseBuilder:RemoveObsticle(thing)
	print("REMOVING " .. thing .. "!")
end

function BaseBuilder:IsPartOfBase(thing)
	print("Is this part of our base???  ")
	print(thing)
	if thing == nil then
		return false
	elseif not thing.prefab then
		return false
	elseif thing.prefab == "firepit" then
		return true
	elseif thing.prefab == "treasurechest" then
		return true
	else
		return false
	end
end

-------------------------------------------------------------------------------
--
--  HELPER FUNCTIONS
--
-------------------------------------------------------------------------------

function BaseBuilder:GetDistanceToBase()
	return self.inst:GetDistanceSqToPoint(self.inst.components.homeseeker:GetHomePos(self.inst))
end

function BaseBuilder:GetItem(item, num)
	local has, numfound = inst.components.inventory:Has(item, num)
	if has then
		return true
	end
	
	-- We will eventually need to check items in chests and our backpack
	
	-- None found... can we make one?
	
	
	return false
end

return BaseBuilder