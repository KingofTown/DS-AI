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

function ManageBase:Visit()
	print("ManageBase:Visit")
	print(self.inst.components.basebuilder:GetDistanceToBase())
	if self.status == READY and self.inst.components.basebuilder:GetDistanceToBase() < 100 then
		self.inst.components.basebuilder:CheckBase()
	else
		print("I can't manage my base if I'm not there!!!")
		self.status = FAILED
	end
end



