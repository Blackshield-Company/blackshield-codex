Scriptname Actor extends ObjectReference Hidden
Bool Function AddSpell(Spell akSpell, Bool abVerbose = True) native
Bool Function RemoveSpell(Spell akSpell) native
Bool Function HasSpell(Form akForm) native
Function AddToFaction(Faction akFaction) native
Function RemoveFromFaction(Faction akFaction) native
Bool Function IsInFaction(Faction akFaction) native
ActorBase Function GetActorBase() native
Int Function GetLevel() native
Bool Function IsDead() native
Bool Function IsInCombat() native
Bool Function IsPlayerTeammate() native
Function StartCombat(Actor akTarget) native
Function StopCombat() native
Function EvaluatePackage() native
Function SetRelationshipRank(Actor akOther, Int aiRank) native
Int Function GetRelationshipRank(Actor akOther) native
Function SetPlayerTeammate(Bool abTeammate = True, Bool abCanDoFavor = True) native
Event OnDeath(Actor akKiller)
EndEvent
Armor Function GetEquippedShield() native
Weapon Function GetEquippedWeapon(Bool abLeftHand = False) native
Bool Function WornHasKeyword(Keyword akKeyword) native
Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
EndEvent
Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
EndEvent
Spell Function GetEquippedSpell(Int aiSource) native
Race Function GetRace() native
Function SetActorValue(String asValueName, Float afValue) native
