Scriptname CHT_BountyScript extends Quest
{Contract Hunter - one bounty on one named outlaw. Event driven: the target's
death and 3D load come from CHT_TargetAliasScript, the deadline is a single
game-time update. No polling.}

CHT_HunterScript Property Hunter Auto
Int Property Tier Auto
{0 Notice, 1 Wanted, 2 Dread}
Int Property OutlawIndex Auto
Float Property DeadlineDays Auto
LocationAlias Property ContractLocation Auto
ReferenceAlias Property MapMarker Auto
ReferenceAlias Property Target Auto
LeveledActor Property Accomplices Auto
{Spawned next to the target, one per point of notoriety.}
Spell Property CHT_AbDreadOutlaw Auto

Int Property OBJ_MAIN = 10 AutoReadOnly
Int Property STAGE_STARTED = 10 AutoReadOnly
Int Property STAGE_DONE = 100 AutoReadOnly
Int Property STAGE_EXPIRED = 150 AutoReadOnly
Int Property STAGE_ABANDONED = 200 AutoReadOnly

Bool finished = False
Bool extrasSpawned = False
Int extraGuards = 0

; Called by CHT_HunterScript right after Start() succeeds.
Function Begin(Int aiNotoriety)
	finished = False
	extrasSpawned = False
	extraGuards = aiNotoriety
	ObjectReference marker = MapMarker.GetReference()
	If marker
		marker.AddToMap()
	EndIf
	SetStage(STAGE_STARTED)
	SetObjectiveDisplayed(OBJ_MAIN)
	RegisterForSingleUpdateGameTime(DeadlineDays * 24.0)
	If aiNotoriety > 0
		Debug.Notification("This outlaw has escaped hunters before (notoriety " + aiNotoriety + "). Expect company.")
	EndIf
	; OnLoad won't fire if the target is already loaded near the player.
	Actor victim = Target.GetActorReference()
	If victim && victim.Is3DLoaded()
		TargetLoaded()
	EndIf
EndFunction

Function TargetLoaded()
	If extrasSpawned || finished
		Return
	EndIf
	Actor victim = Target.GetActorReference()
	If !victim || victim.IsDead()
		Return
	EndIf
	extrasSpawned = True
	If Tier == 2
		victim.AddSpell(CHT_AbDreadOutlaw, False)
	EndIf
	Int i = 0
	While i < extraGuards
		victim.PlaceAtMe(Accomplices)
		i += 1
	EndWhile
EndFunction

Function TargetDied()
	If finished || !IsRunning()
		Return
	EndIf
	finished = True
	UnregisterForUpdateGameTime()
	CompleteAllObjectives()
	Hunter.BountyClaimed(OutlawIndex, Tier, ContractLocation.GetLocation())
	SetStage(STAGE_DONE)
	Stop()
EndFunction

; The deadline.
Event OnUpdateGameTime()
	If finished || !IsRunning()
		Return
	EndIf
	Fail(False)
EndEvent

Function Abandon()
	If finished
		Return
	EndIf
	Fail(True)
EndFunction

Function Fail(Bool abAbandoned)
	finished = True
	UnregisterForUpdateGameTime()
	FailAllObjectives()
	Hunter.BountyFailed(OutlawIndex, Tier, ContractLocation.GetLocation(), abAbandoned)
	If abAbandoned
		SetStage(STAGE_ABANDONED)
	Else
		SetStage(STAGE_EXPIRED)
	EndIf
	Stop()
EndFunction
