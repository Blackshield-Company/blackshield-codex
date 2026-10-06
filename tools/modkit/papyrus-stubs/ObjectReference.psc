Scriptname ObjectReference extends Form Hidden
Function AddItem(Form akItemToAdd, Int aiCount = 1, Bool abSilent = False) native
Function RemoveItem(Form akItemToRemove, Int aiCount = 1, Bool abSilent = False, ObjectReference akOtherContainer = None) native
Int Function GetItemCount(Form akItem) native
Function AddToMap(Bool abAllowFastTravel = False) native
Function Delete() native
Function Disable(Bool abFadeOut = False) native
Function Enable(Bool abFadeIn = False) native
Bool Function IsDisabled() native
Float Function GetDistance(ObjectReference akOther) native
WorldSpace Function GetWorldSpace() native
Location Function GetCurrentLocation() native
Bool Function IsInLocation(Location akLocation) native
Bool Function IsInInterior() native
Form Function GetBaseObject() native
Function MoveTo(ObjectReference akTarget, Float afXOffset = 0.0, Float afYOffset = 0.0, Float afZOffset = 0.0, Bool abMatchRotation = True) native
ObjectReference Function PlaceAtMe(Form akFormToPlace, Int aiCount = 1, Bool abForcePersist = False, Bool abInitiallyDisabled = False) native
Actor Function PlaceActorAtMe(ActorBase akActorToPlace, Int aiLevelMod = 4, EncounterZone akZone = None) native
Event OnRead()
EndEvent
Event OnActivate(ObjectReference akActionRef)
EndEvent
Event OnLoad()
EndEvent
Bool Function Is3DLoaded() native
Event OnSpellCast(Form akSpell)
EndEvent
Event OnContainerChanged(ObjectReference akNewContainer, ObjectReference akOldContainer)
EndEvent
