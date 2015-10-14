local BASE_BUILDING_PRIORITY = {
		"firepit",
		"treasurechest",
}

local BASE_BUILDINGS = {}


ManageBase = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "ManageBase")
    self.inst = inst
end)

function ManageBase:OnFail()
    self.pendingstatus = FAILED
end

function ManageBase:OnSucceed()
    self.pendingstatus = SUCCESS
end

function ManageBase:IsObsticle(thing)
	print("Is this an obsticle???")
	print(thing)
	if thing == nil then
		return false
	elseif not thing.prefab then
		return false
	elseif thing.prefab == "Evergreen" then
		return true
	else
		return false
	end
end

function ManageBase:RemoveObsticle(thing)
	print("REMOVING " .. thing .. "!")
end	

function ManageBase:Visit()
    --if false then
	--	print("I can't manage my base if I'm not there!!!")
	--	self.status = FAILED
	--	return
	local obsticle = nil
	local homePos = self.inst.brain:GetHomePos()
	if homePos ~= nil then
		obsticle = FindEntity(homePos,20,function(thing) return self:IsObsticle(thing) end)
	end
	
	if self.status == READY and next(obsticle) ~= nil then
		self:RemoveObsticle(next(obsticle))
	elseif self.status == READY then
		-- Build up our base
		for k,v in pairs(BASE_BUILDING_PRIORITY) do
			print(v)
			print(BASE_BUILDINGS[v])
			if BASE_BUILDINGS[v] == nil then			
				print("Can I build ")
				print(BASE_BUILDINGS[k])
				print(CanPlayerBuildThis(self.inst, BASE_BUILDINGS[k]))
			end
		end
	end
end



