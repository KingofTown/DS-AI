DontBeOnFire = Class(BehaviourNode, function(self, inst)
    BehaviourNode._ctor(self, "DontBeOnFire")
    self.inst = inst
    self.waittime = 0
end)

function DontBeOnFire:Visit()

   if self.status == READY then
      if not self.inst.components.health.takingfiredamage then
         self.status = FAILED
         return
      end
   
      -- We must be on fire!
      self.status = RUNNING   
   
   elseif self.status == RUNNING then
   
      -- No longer on fire! 
      if not self.inst.components.health.takingfiredamage then
         self.inst.components.locomotor:Stop()
         self.status = SUCCESS
         return
      end
   
      if GetTime() > self.waittime then
         -- Just get away from all fire. It's not hard.
         local pos = Vector3(self.inst.Transform:GetWorldPosition())
         local allFires = TheSim:FindEntities(pos.x,pos.y,pos.z, 10, {"fire"}, {"player"})
         
         -- Filter out any inventory items (the torch has a 'fire' tag when lit...)
         for k,v in pairs(allFires) do 
            if v.components and v.components.inventoryitem then
               allFires[k] = nil
            end
         end
         
         -- No more fire. We win!
         if #allFires == 0 then
            self.status = SUCCESS
            return
         end
         
         -- Get the positions of these fires and calculate an escape angle
         local angles = {}
         for k,v in pairs(allFires) do
            --print(v.prefab .. " is on fire!")
            local point = Vector3(v.Transform:GetWorldPosition())
            if point then
               table.insert(angles, self.inst:GetAngleToPoint(point))
            end
         end
         
         -- Calculate the average angle towards the fire.
         local x,y = 0,0
         for k,v in pairs(angles) do
            --print("Direction to fire: " .. tostring(v))
            x = x + math.cos(math.rad(v))
            y = y + math.sin(math.rad(v))
         end
         
         local avg = math.deg(math.atan2(y,x))
         --print("Average direction to fire: " .. tostring(avg))
         
         local runAngle = (avg + 180) % 360
         
         --print("Running at angle: " .. tostring(runAngle))
         self.inst.components.locomotor:RunInDirection(runAngle)
         -- Keep running for a bit before recalculating the new angle
         self.waittime = GetTime() + 2
      end
         
      self:Sleep(self.waittime - GetTime())
    
   end    
end



