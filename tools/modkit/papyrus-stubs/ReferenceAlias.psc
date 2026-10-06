Scriptname ReferenceAlias extends Alias Hidden
Function Clear() native
Function ForceRefTo(ObjectReference akNewRef) native
ObjectReference Function GetReference() native
Actor Function GetActorReference()
	Return GetReference() as Actor
EndFunction
ObjectReference Function GetRef()
	Return GetReference()
EndFunction
; Events of the aliased reference/actor are delivered to the alias script.
Event OnDeath(Actor akKiller)
EndEvent
Event OnLoad()
EndEvent
Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
EndEvent
Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
EndEvent
Event OnSpellCast(Form akSpell)
EndEvent
Event OnPlayerLoadGame()
EndEvent
Event OnLocationChange(Location akOldLoc, Location akNewLoc)
EndEvent
Event OnRead()
EndEvent
Event OnContainerChanged(ObjectReference akNewContainer, ObjectReference akOldContainer)
EndEvent
Event OnActivate(ObjectReference akActionRef)
EndEvent
