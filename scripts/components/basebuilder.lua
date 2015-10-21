MAX_BASE_SIZE = 20
MAX_CLEAN_SIZE = 22

local BASE_BUILDING_PRIORITY = {
		"firepit",
		"treasurechest",
}

local BaseBuilder = Class(function(self, inst)
    self.inst = inst
	self.inst:StartUpdatingComponent(self) -- register for the OnUpdate call
	
	self.baseSize = 0
	self.cleanSize = 0
	self.priorityTarget = nil
	self.baseMap = {}
end)

function BaseBuilder:OnSave()
	-- Build the save data map
	local data = {}
	-- Add the stuff to save
	--data.baseMap = baseMap
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

function BaseBuilder:UpgradeBase()
	print("UPGRADING BASE")

	local home = self.inst.components.homeseeker.home
	local baseBuildings = FindEntity(home,self.MAX_BASE_SIZE + 1,function(thing) return self:IsPartOfBase(thing) end)
	print("BASE BUILDINGS: ")
	for k,v in pairs(baseBuildings) do print(k,v) end

	if true then
		-- Build up our base
		for k,v in pairs(BASE_BUILDING_PRIORITY) do
			if baseBuildings == nil or baseBuildings[v] == nil then
				if CanPlayerBuildThis(self.inst, v) then
					self:BuildThis(v)
					-- We were able to build something, return success
					print("WE WERE ABLE TO BUILD A " .. v .. "!!!")
					return true
				end
			end
		end
		print("WE COULDN'T BUILD ANYTHING")
		-- We couldn't build anything, return failure
		return false
	else
		print("WE COULDN'T PERFORM ANY ACTIONS")
		-- We couldn't perform any actions, return failure
		return false
	end
end

function BaseBuilder:BuildThis(thing)
	print("BUILD THIS: " .. thing)
	self.inst.components.brain:SetSomethingToBuild(v)
end

function BaseBuilder:IsPartOfBase(thing)
	if thing == nil then
		return false
	elseif not thing.prefab then
		return false
	elseif thing.prefab == "firepit" then
		return true
	elseif thing.prefab == "treasurechest" then
		return true
	elseif thing.prefab == "researchlab" then
		return true
	else
		return false
	end
end

function BaseBuilder:IgnoreObject(thing)
	if thing == nil then
		return true
	elseif not thing.prefab then
		return true
	elseif thing.prefab == "raindrop" then
		return true
	elseif thing.prefab == "flies" then
		return true
	else
		return false
	end
end

function BaseBuilder:GetPriorityTarget()
	local home = self.inst.components.homeseeker.home

	if home == nil then
		self.cleanSize = 0
		self.priorityTarget = nil
		return nil
	end

	local x, y, z = home.Transform:GetWorldPosition()
	local objects = TheSim:FindEntities(x,y,z,MAX_CLEAN_SIZE)

	if objects == nil then
		self.cleanSize = MAX_CLEAN_SIZE
		self.priorityTarget = nil
		return nil
	end

	local target = nil
	local cleanSize = MAX_CLEAN_SIZE
	for k,v in pairs(objects) do
		if not self:IsPartOfBase(v) and not self:IgnoreObject(v) then
			local dist = self:GetDistanceBetweenPoints(home,v)
			if dist < cleanSize then
				cleanSize = dist
				target = v
			end
		end
	end

	self.cleanSize = cleanSize
	self.priorityTarget = target
	if target then
		print("FOUND TARGET: " .. target.prefab .. " AT DIST " .. cleanSize)
	else
		print("COULDN'T FIND A PRIORITY TARGET...")
	end
	return target
end

function BaseBuilder:GetBaseSize()
	local home = self.inst.components.homeseeker.home

	if home == nil then
		self.baseSize = 0
		return 0
	end

	local x, y, z = home.Transform:GetWorldPosition()
	local baseBuildings = TheSim:FindEntities(x,y,z,MAX_BASE_SIZE)

	if baseBuildings == nil then
		self.baseSize = 0
		return 0
	end

	local baseSize = 0
	for k,v in pairs(baseBuildings) do
		if self.inst.components.basebuilder:IsPartOfBase(v) then
			local dist = self.inst.components.basebuilder:GetDistanceBetweenPoints(home,v)
			if dist > baseSize then
				baseSize = dist
			end
		end
	end

	self.baseSize = baseSize
	return baseSize
end

function BaseBuilder:GetTargetToClean()
	local target = self.priorityTarget
	self.priorityTarget = nil
	return target
end

-------------------------------------------------------------------------------
--
--  HELPER FUNCTIONS
--
-------------------------------------------------------------------------------

function BaseBuilder:GetDistanceToBase(inst)
	if self.inst == nil or not self.inst.components.homeseeker:HasHome() then
		print("Failed to get the distance to base")
		return 9999999
	else
		return math.pow(self.inst:GetDistanceSqToPoint(self.inst.components.homeseeker:GetHomePos(self.inst)),0.5)
	end
end

function BaseBuilder:GetDistanceBetweenPoints(point1, point2)
	if point1 == nil or point2 == nil then
		print("Failed to get the distance between points")
		return 9999999
	else
		return math.pow(point1:GetDistanceSqToInst(point2),0.5)
	end
end

function BaseBuilder:GetCurrentSearchDistance()
	print("HEY, SOMEONE ASKED ME FOR OUR DISTANCE!!!")
	return 10
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