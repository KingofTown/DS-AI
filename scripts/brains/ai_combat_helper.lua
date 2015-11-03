--[[ Misc functions relating to combat ]]--

require "brains/ai_build_helper"

--[[
	1) Find the closest hostile mob close to me (within 30?)
		1.5) Maintain a 'do not engage' type list? 
	2) Find all like mobs around that one (or maybe just all 'hostile' mobs around it)
	3) Calculate damage per second they are capabable of doing to me
	4) Calculate how long it will take me to kill with my current weapon and their health
	5) Engage if under some threshold
--]]
function GoForTheEyes(inst)

   -- If this is true, we're waiting for the spear to be built
   if inst.waitingForBuild then
      -- If the build isn't queued and we are in the idle state...something happened
      if not inst.brain:CheckBuildQueued(inst.waitingForBuild) and inst.sg:HasStateTag("idle") then
         inst.waitingForBuild = nil
      else
         -- Waiting for the brain to make this thing. Nothing to do.
         return false   
      end
   end
   
   local closestHostile = FindEntity(inst, 20, function(guy) return
                           guy:HasTag("hostile") and inst.components.combat:CanTarget(guy) end)

	--local closestHostile = GetClosestInstWithTag("hostile", inst, 20)
	
	-- No hostile...nothing to do
	if not closestHostile then return false end
	
	-- If this is on the do not engage list...run the F away!
	-- TODO!
	
	local hostilePos = Vector3(closestHostile.Transform:GetWorldPosition())
		
	-- This should include the closest
	local allHostiles = TheSim:FindEntities(hostilePos.x,hostilePos.y,hostilePos.z,5,{"hostile"})
	
	
	-- Get my highest damage weapon I have or can make
	local allWeaponsInInventory = inst.components.inventory:FindItems(function(item) return 
										item.components.weapon and item.components.equippable and item.components.weapon.damage > 0 end)
										
	local highestDamageWeapon = nil										
	-- The above does not count equipped weapons 
	local equipped = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	
	if equipped and equipped.components.weapon and equipped.components.weapon.damage > 0 then
		highestDamageWeapon = equipped
	end

	for k,v in pairs(allWeaponsInInventory) do
		if highestDamageWeapon == nil then
			highestDamageWeapon = v
		else
			if v.components.weapon.damage > highestDamageWeapon.components.weapon.damage then
				highestDamageWeapon = v
			end
		end
	end
	
	-- TODO: Consider an axe or pickaxe a valid weapon if we are under attack already! 
	--       The spear condition is only if we are going to actively hunt something.
	
	-- We don't have a weapon...can we make one? 
	-- TODO: What do we try to make? Only seeing if we can make a spear here as I don't consider an axe or 
	--       a pickaxe a valid weapon. Should probably excluce
	if highestDamageWeapon == nil or (highestDamageWeapon and highestDamageWeapon.components.weapon.damage < 34) then
	  local canBuildSpear = CanPlayerBuildThis(inst,"spear")
    
	  if canBuildSpear then
   	   -- TODO: Need to check if it's safe to build this. If it's not safe...then don't start!
   	   --       Maybe use what I've got...or run away to build one? No idea.
   	   inst.waitingForBuild = "spear"
   	   inst.brain:SetSomethingToBuild("spear",nil,
   	     function() inst.waitingForBuild = nil end,function() inst.waitingForBuild = nil end)
   	     
   	   -- Gotta wait for that spear to be built
   	   print("Making a spear!")
   	   return false
	  elseif not canBuildSpear and inst.components.combat.target == nil then
			-- TODO: Rather than checking to see if we have a combat target, should make
			--       sure the closest hostile is X away so we have time to craft one.
			--       What I do not want is to just keep trying to make one while being attacked.
			--       Returning false here means we'll run away.
			--print("I don't have a good weapon and cannot make one")
			return false
		elseif highestDamageWeapon ~= nil and inst.components.combat.target then
			print("I'll use what I've got!")
		end
	end
	
	if highestDamageWeapon == nil then return false end
	
	-- TODO: Calculate our best armor.
	
	-- Collect some stats about this group of dingdongs
	
	local totalHealth=0
	local totalWeaponSwings = 0

	-- dpsTable is ordered like so:
	--{ [min_attack_period] = sum_of_all_at_this_period,
	--  [min_attack_period_2] = ...
	--}
	-- We can calculate how much damage we'll take by summing the entire table, then adding up to the min_attack_period
	
	-- If they are in cooldown, do not add to damage_on_first_attack. This number is the damage taken at zero time assuming
	-- all mobs are going to hit at the exact same time.
	
	-- TODO: Get mob attack range and calculate how long until they are in range to attack for better estimate
	
	
	local dpsTable = {}
	local damage_on_first_attack = 0
	for k,v in pairs(allHostiles) do
		local a = v.components.combat.min_attack_period
		dpsTable[a] = (dpsTable[a] and dpsTable[a] or 0) + v.components.combat.defaultdamage
		
		-- If a mob is ready to attack, add this to the damage taken when entering combat
		-- (even though they probably wont attack right away)
		if not v.components.combat:InCooldown() then
			damage_on_first_attack = damage_on_first_attack + v.components.combat.defaultdamage
		end

		totalHealth = totalHealth + v.components.health.currenthealth -- TODO: Apply damage reduction if any
		totalWeaponSwings = totalWeaponSwings + math.ceil(v.components.health.currenthealth / highestDamageWeapon.components.weapon.damage)
	end
	

	
	--print("Total Health of all mobs around me: " .. tostring(totalHealth))
	--print("It will take " .. tostring(totalWeaponSwings) .. " swings of my weapon to kill them all")
	--print("It takes " .. tostring(inst.components.combat.min_attack_period) .. " seconds to swing")
	
	-- Now, determine if we are going to engage. If so, equip a weapon and charge!
	
	-- How long will it take me to swing x times?
	-- If we aren't in cooldown, we can swing right away. Else, we need to add our current min_attack_period to the calc.
	--      yes, we could find the exact amount of time left for cooldown, but this will be a safe estimate
	local inCooldown = inst.components.combat:InCooldown() and 0 or 1
	
	local timeToKill = (totalWeaponSwings-inCooldown) * inst.components.combat.min_attack_period
	
	
	table.sort(dpsTable)
	
	local damageTakenInT = damage_on_first_attack
	for k,v in pairs(dpsTable) do
		if k <= timeToKill then
			damageTakenInT = damageTakenInT + v
		end
	end
	
	--print("It will take " .. tostring(timeToKill) .. " seconds to kill the mob. We'll take about " .. tostring(damageTakenInT) .. " damage")
	
	local ch = inst.components.health.currenthealth
	-- TODO: Make this a threshold
	if (ch - damageTakenInT > 50) then
	
		-- Just compare prefabs...we might have duplicates. no point in swapping
		if not equipped or (equipped and (equipped.prefab ~= highestDamageWeapon.prefab)) then
			inst.components.inventory:Equip(highestDamageWeapon)
		end
		
		-- TODO: Make armor first and equip it if possible!
		
		-- Set this guy as our target
		inst.components.combat:SetTarget(closestHostile)
		return true
	end
end

--------------------------------------------------

function ShouldRunAway(guy)
   
   -- Don't run from anything in our inventory (i.e. killer bees in our inventory)
   if guy.components.inventoryitem and guy.components.inventoryitem.owner then
      return false
   end
   
	-- Wilson apparently gets scared by his own shadow
	-- Also, don't get scared of chester too...
	if guy:HasTag("player") or guy:HasTag("companion") then 
		return false 
	end
	
   -- Angry worker bees don't have any special tag...so check to see if it's spring
   -- Also make sure .IsSpring is not nil (if no RoG, this will not be defined)
   if guy:HasTag("worker") and GetSeasonManager() and GetSeasonManager().IsSpring ~= nil and GetSeasonManager():IsSpring() then
      return true
   end
     
   	
	-- Run away from things that are on fire and don't try to harvest things in fire.
	-- Then again, if a firehound ends up being on fire...we won't run away from it. lol...
	-- TODO: Fix this at some point. Leaving here becuase I don't see that happening ever.
	if guy:HasTag("fire") then
	  -- Any prefab that has the name 'fire' or 'torch' in it is probably safe...
	  local i = string.find(guy.prefab,"fire")
	  local j = string.find(guy.prefab,"torch")
	  if i or j then
	     return false
	  end
 
	  print("Ahh! " .. guy.prefab .. " is on fire! KEEP AWAY!")
	  return true
	end
	

	return guy:HasTag("WORM_DANGER") or guy:HasTag("guard") or guy:HasTag("hostile") or 
		guy:HasTag("scarytoprey") or guy:HasTag("frog") or guy:HasTag("mosquito") or guy:HasTag("merm") or
		guy:HasTag("tallbird")

end
