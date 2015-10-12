require "brains/ai_helper_functions"

DoScience = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "DoScience")
    self.inst = inst
	self.bufferedBuildList = nil
	self.buildStatus = nil 
	self.waitingForBuild = nil
	
	-- Is set when the final build is complete
	self.onSuccess = function()
		self.buildStatus = SUCCESS
	end
	
	self.onFail = function()
		self.buildStatus = FAILED
	end
end)

function DoScience:PushNextAction()
	self.waitingForBuild = true
	
	if self.bufferedBuildList then
		-- Grab the action and remove it from the list
		local action = table.remove(self.bufferedBuildList,1)

		if not action then
			print("PushNextAction: action empty")
			-- The list is empty.
			self.buildListEmpty = true
			return
		end
		
		print("PushNextAction: " .. action:__tostring())
		
		-- Have the buffered action schedule the next one
		action:AddSuccessAction(function() self:PushNextAction() end)
		self.inst.components.locomotor:PushAction(action, true)
	end
end

local BUILD_PRIORITY = {
		"axe",
		"pickaxe",
		"rope",
		"boards",
		"cutstone",
		"papyrus",
		"spear",
		"footballhat",
		"backpack",
		"treasurechest",
		"armorwood",
}

function DoScience:Visit()

    if self.status == READY then
		-- These things should not exist in the READY state. Clear them
		self.buildListEmpty = nil
		self.buildStatus = nil
		self.bufferedBuildList = nil
		self.waitingForBuild = nil
		
		local prototyper = self.inst.components.builder.current_prototyper;
		if not prototyper then
			--print("Not by a science machine...nothing to do")
			self.status = FAILED
			return
		end
		
		print("Standing next to " .. prototyper.prefab .. " ...what can I build...")
		
		local tech_level = self.inst.components.builder.accessible_tech_trees
		for k,v in pairs(BUILD_PRIORITY) do
			-- Looking for things we can prototype
			local recipe = GetRecipe(v)
			
			-- This node only cares about things to prototype. If we know the recipe, 
			-- ignore it. 
			if not self.inst.components.builder:KnowsRecipe(v) then

				-- Will check our inventory for all items needed to build this
				if CanPlayerBuildThis(self.inst,v) and CanPrototypeRecipe(recipe.level,tech_level) then
					-- Will push the buffered event to build this thing
					-- TODO: Add a position for non inventory items
					local pos = Vector3(self.inst.Transform:GetWorldPosition())
					self.bufferedBuildList = GenerateBufferedBuildOrder(self.inst,v,pos,self.onSuccess, self.onFail)
					-- We apparnetly know how to make this thing. Let's try!
					if self.bufferedBuildList ~= nil then
						print("Attempting to build " .. v)
						self.status = RUNNING
						self:PushNextAction()
						return
					end
				end		
			end -- end KnowsRecipe
			-- Don't know how to build this. Check the next thing
		end
		-- Either list is empty or we can't building anything. Nothing to do
		print("There's nothing we know how to build")
		self.status = FAILED
		return		
		
    elseif self.status == RUNNING then
		if self.waitingForBuild then
			-- If this is set, the buffered list is done (either by error or successfully). 
			-- Nothing left to do.
			if self.buildStatus then
				print("Build status has returned : " .. tostring(self.buildStatus))
				self.status = self.buildStatus
				return
			end
			
			-- We tried to schedule the next command and it was empty. 
			if self.buildListEmpty then
				-- If this isn't set, something is really messed up.
				if not self.buildStatus then
					print("Something went wrong!")
					self.status = FAILED
					return
				end
			end
			
			-- Waiting for the build to complete
			--print("Waiting for current build action to complete")
			self.status = RUNNING
			return
		end
		
	end
end
