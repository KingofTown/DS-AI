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

-- Returns a point somewhere near thing at a distance dist
function GetPointNearThing(thing, dist)
	local pos = Vector3(thing.Transform:GetWorldPosition())

	if pos then
		local theta = math.random() * 2 * PI
		local radius = dist
		local offset = FindWalkableOffset(pos, theta, radius, 12, true)
		if offset then
			return pos+offset
		end
	end
end

function ManageBase:buildIt(buildableThing)
	if self.inst.components.builder:CanBuild(buildableThing) then
		-- Find some valid ground near us
		local buildableThingPos = GetPointNearThing(self.inst,3)
		if buildableThingPos ~= nil then
			print("Found a valid place to build a %s", buildableThing)
			--return SetupBufferedAction(self.inst, BufferedAction(self.inst,self.inst,ACTIONS.BUILD,nil,machinePos,"researchlab",nil))
			local action = BufferedAction(self.inst,self.inst,ACTIONS.BUILD,nil,buildableThingPos,buildableThing,nil)
			self.inst:PushBufferedAction(action)
			self.status = SUCCESS
		else
			print("Could not find a place for a %s", buildableThing)
			self.status = FAILED
		end
	else
		print("I don't have the resources to build %s", buildableThing)
		self.status = FAILED
	end
end

function ManageBase:Visit()

    if not self.atHome then
		print("I can't manage my base if I'm not there!!!")
		self.status = FAILED
		return
	elseif self.status == READY and self.atHome then
    	-- Build up our base
		for k,v in pairs(BASE_BUILDING_PRIORITY) do
			if BASE_BUILDINGS[k] == nil then
				buildIt(k)
			end
		end
	end
end



