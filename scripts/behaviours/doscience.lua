require "brains/ai_build_helper"

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
		action:AddSuccessAction(function() self.inst:DoTaskInTime(.2,self:PushNextAction()) end)
		self.waitingForBuild = true
		
		self.inst.components.locomotor:PushAction(action, true)	
		
		print("PushNextAction: done")	
	end
end

-- This is the order to build things. 
local BUILD_PRIORITY = {
		"spear",
		"backpack",
		"firepit",
		"cookpot",
}

-- The BUILD_PRIORITY contains the index into the build info table
-- which stores the important info. Otherwise you cannot control
-- the table ordering.
-- Not all builds need build_info populated. This table will just contain
-- extra info for the build, like position to build it.
-- example entry would be:
-- "spear" = {pos=nil, someValue=x, otherInfo=y}
-- then you would loop over BUILD_PRIORITY and use that
-- index to get the build_info
local build_info = { }

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
							table.insert(BUILD_PRIORITY,1,toBuild)
							build_info[toBuild] = {pos=self.buildTable.pos}
							--local build_info = {pos=self.buildTable.pos, onsuccess=self.buildTable.onsuccess, onfail=self.buildTable.onfail}
							--self.inst.components.prioritizer:AddToBuildList(toBuild,build_info)
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
		
		--print("Standing next to " .. prototyper.prefab .. " ...what can I build...")
		
		local tech_level = self.inst.components.builder.accessible_tech_trees
		for k,v in pairs(BUILD_PRIORITY) do
			-- Looking for things we can prototype
			local recipe = GetRecipe(v)
			
			-- If not nil, will contain useful info like 'where' to build this now
			local buildinfo = build_info[v]
			
			-- This node only cares about things to prototype. If we know the recipe, 
			-- ignore it. 
			if not self.inst.components.builder:KnowsRecipe(v) then

				-- Will check our inventory for all items needed to build this
				if CanPlayerBuildThis(self.inst,v) and CanPrototypeRecipe(recipe.level,tech_level) then
					-- Will push the buffered event to build this thing
					local pos = buildinfo and buildinfo.pos or self.inst.brain:GetPointNearThing(self.inst,7)--Vector3(self.inst.Transform:GetWorldPosition())
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
		--print("There's nothing we know how to build")
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
			
			-- If our current buffered action is nil and we are in the idle state...something
			-- interrupted us. Just leave the node!
         if self.inst:GetBufferedAction() == nil and self.inst.sg:HasStateTag("idle") then
            print("DoScience: SG: ---------- \n " .. tostring(self.inst.sg))
            self.status = FAILED
            return
         end
			
			-- Waiting for the build to complete
			--print("Waiting for current build action to complete")
			self.status = RUNNING
			return
		end
		
	end
end