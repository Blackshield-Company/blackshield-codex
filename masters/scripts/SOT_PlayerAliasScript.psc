Scriptname SOT_PlayerAliasScript extends ReferenceAlias
{Steel Oath - on the controller quest's Player alias. Forwards the player's
spell casts and equipment changes to the controller, which checks them
against the oaths currently sworn. Event-driven: nothing polls.}

SOT_OathScript Property Oaths Auto

Event OnSpellCast(Form akSpell)
	Oaths.OnPlayerSpellCast(akSpell)
EndEvent

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
	Oaths.OnPlayerEquipped(akBaseObject)
EndEvent

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
	Oaths.OnPlayerUnequipped(akBaseObject)
EndEvent
