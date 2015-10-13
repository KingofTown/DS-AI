require "brains/ai_helper_functions"

-- getBuildFn should return a table with the following
--    thingToBuild
--    pos or nil
--    onsuccess or nil
--    onfail or nil
-- Finally, the getBuildFn should clear the return value so it is nil next pass.
DoScience = Class(BehaviourNode, function(self, inst, getBuildFn)
    BehaviourNode._ctor(self, "DoScience")
    self.inst = inst
	self.getThingToBuildFn = getBuildFn
	self.bufferedBuildList = nil
	self.buildStatus = nil 
	self.waitingForBuild = nil
	
	-- Is set when the final build is complete
	self.onSuccess = function()
		self.buildStatus = SUCCESS
		if self.buildTable and self.buildTable.onsuccess then
			self.buildTable.onsuccess()
		end
	end
	
	self.onFail = function()
		self.buildStatus = FAILED
		if self.buildTable and self.buildTable.onfail then
			self.buildTable.onfail()
		end
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
		self.buildTable = nil
		
		-- Some other nodes has something they want built. 
		if self.getThingToBuildFn ~= nil then
			self.buildTable = self.getThingToBuildFn()
			
			if self.buildTable and self.buildTable.prefab then
				local toBuild = self.buildTable.prefab
				local recipe = GetRecipe(toBuild)
				
				if not recipe then
					print("Cannot build " .. toBuild .. " as it doesn't have a recipe")
					if self.buildTable.onfail then 
						self.buildTable.onfail()
					end
					self.status = FAILED
					return
				else
					if not self.inst.components.builder:KnowsRecipe(toBuild) then
						-- Add it to the prototype list.
						if BUILD_PRIORITY[toBuild] == nil then
							print("Don't know how to build " .. toBuild .. "...adding to build table")
							table.insert(BUILD_PRIORITY,toBuild,1)
						end
						if self.buildTable.onfail then 
							self.buildTable.onfail()
						end
						self.status = FAILED
						return
					else
						-- We know HOW to craft it. Can we craft it?
						if CanPlayerBuildThis(self.inst,toBuild) then
							self.bufferedBuildList = GenerateBufferedBuildOrder(self.inst,toBuild,self.buildTable.pos,self.onSuccess, self.onFail)
							-- We apparnetly know how to make this thing. Let's try!
							if self.bufferedBuildList ~= nil then
								print("Attempting to build " .. toBuild)
								self.status = RUNNING
								self:PushNextAction()
								return
							end	
						else
							-- Don't have enough resources to build this.
							print("Don't have enough resources to make " .. toBuild)
							if self.buildTable.onfail then 
								self.buildTable.onfail()
							end
							self.status = FAILED
							return
						end
					end
				end
			end
			-- If buildThing doesn't return something, just do our normal stuff.
		end
		
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