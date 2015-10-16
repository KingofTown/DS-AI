MAX_BASE_SIZE = 20

ManageBase = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "ManageBase")
    self.inst = inst
    self.cleanDist = 0
end)

function ManageBase:OnFail()
    self.pendingstatus = FAILED
end

function ManageBase:OnSucceed()
    self.pendingstatus = SUCCESS
end

function ManageBase:GetBaseSize()
	local home = self.inst.components.homeseeker.home

	if home == nil then
		return 0
	end

	local x, y, z = home.Transform:GetWorldPosition()
	local baseBuildings = TheSim:FindEntities(x,y,z,MAX_BASE_SIZE)

	if baseBuildings == nil then
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

	return baseSize
end

function ManageBase:IncreaseCleanDistance()
	self.cleanDist = self.cleanDist + 1
	print("Incresing the clean distance to " .. self.cleanDist)
	return self.cleanDist
end

function ManageBase:GetCleanDist()
	return self.cleanDist
end

function ManageBase:Visit()
	print("ManageBase:Visit")
	print(self.inst.components.basebuilder:GetDistanceToBase())
	if self.status == READY and self.inst.components.basebuilder:GetDistanceToBase() < 0 and self:GetBaseSize() < 2 then
		self.inst.components.basebuilder:CheckBase()
	elseif self:GetBaseSize() < 8 and self.cleanDist < 50 then
		print("CLEANING UP BASE??? WILSON, THIS MEANS YOU!  " .. self.cleanDist)

	else
		print "MANAGE BASE ELSE"
		self.status = FAILED
	end
end



