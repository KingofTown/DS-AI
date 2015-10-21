ManageBase = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "ManageBase")
    self.inst = inst
	self.maxBaseSize = 20
	self.maxCleanSize = 22
end)

function ManageBase:OnFail()
    self.pendingstatus = FAILED
end

function ManageBase:OnSucceed()
    self.pendingstatus = SUCCESS
end

function ManageBase:Visit()
	--local home = self.inst.components.homeseeker.home
	local distanceToBase = self.inst.components.basebuilder:GetDistanceToBase()
	local baseSize = self.inst.components.basebuilder:GetBaseSize()
	local cleanSize = self.inst.components.basebuilder.cleanSize

	local priorityTarget = nil
	if not cleanSize or not self.maxCleanSize then
		print("FOUND A NIL VALUE!")
	elseif cleanSize < self.maxCleanSize then
		priorityTarget = self.inst.components.basebuilder:GetPriorityTarget()
	end

	print("ManageBase:Visit")
	print(self.inst.components.basebuilder:GetDistanceToBase())

	-- Check if anything is on fire
	-- Check if anything is damaged and in need of repair (just walls?)
	-- Check if any of our structures are destroyed and in need of removing

	if self.status == READY and distanceToBase < 0 and baseSize < 2 then
		self.inst.components.basebuilder:UpgradeBase()
	elseif baseSize < 8 and cleanSize < 50 and priorityTarget then
		self.inst:PushEvent("cleanBase")
		print("CLEANING UP BASE??? WILSON, THIS MEANS YOU!")
	else
		print "MANAGE BASE ELSE"
		self.status = FAILED
	end
end



