local assets=
{
   Asset("ANIM", "anim/firefighter_range.zip")    
}

local function fn(Sim)
   local inst = CreateEntity()
   local trans = inst.entity:AddTransform()
   local anim = inst.entity:AddAnimState()
   --trans:SetScale(1.55,1.55,1.55)
   -- TODO: Lookup the range and set the scale based on that...
   trans:SetScale(2,2,2)
   
   anim:SetBank("firefighter_placement")
   anim:SetBuild("firefighter_range")
   anim:PlayAnimation("idle")
    
   anim:SetOrientation( ANIM_ORIENTATION.OnGround )
   anim:SetLayer( LAYER_BACKGROUND )
   anim:SetSortOrder( 3 )
   
   inst.persists = false
   inst:AddTag("fx")
   inst:AddTag("range_indicator")
    
    local minimap = inst.entity:AddMiniMapEntity()
    minimap:SetIcon("map_circle.tex")
    
   return inst
end

return Prefab( "common/range_indicator", fn, assets) 