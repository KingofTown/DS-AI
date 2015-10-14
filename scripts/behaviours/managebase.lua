local BASE_BUILDING_PRIORITY = {
		"firepit",
		"treasurechest",
}

local BASE_BUILDINGS = {}


ManageBase = Class(BehaviourNode, function(self, inst, atHome)
    BehaviourNode._ctor(self, "ManageBase")
    self.inst = inst
    self.atHome = atHome
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
	

function ManageBase:Visit()

    if not self.atHome then
		print("I can't manage my base if I'm not there!!!")
		self.status = FAILED
		return
	elseif self.status == READY and self.atHome then
		local obsticle = FindEntity(self.inst,200,function(thing) return self.IsObsticle(thing) end)
	
    	-- Build up our base
		--for k,v in pairs(BASE_BUILDING_PRIORITY) do
		--	if BASE_BUILDINGS[k] == nil then
		--		buildIt(k)
		--	end
		--end
	end
end



