Scriptname BSC_ContractScript extends Quest
{Blackshield Company - shared logic for radiant contracts.
ContractType 0 = clear a bandit camp (kill the boss / clear the location),
1 = bounty on a marked target, 2 = hold a fort against raider waves.}

BSC_CompanyScript Property Company Auto
Int Property ContractType Auto
LocationAlias Property ContractLocation Auto
ReferenceAlias Property MapMarker Auto
ReferenceAlias Property Target Auto
{Clear: the location boss. Bounty: the marked target. Hold: unused.}
LeveledActor Property RaiderList Auto
{Hold contracts: leveled actor spawned in each wave.}
Int Property WaveCount = 3 Auto
Float Property TriggerDistance = 2500.0 Auto

Int Property OBJ_MAIN = 10 AutoReadOnly
Int Property OBJ_HOLD = 20 AutoReadOnly
Int Property STAGE_STARTED = 10 AutoReadOnly
Int Property STAGE_DONE = 100 AutoReadOnly
Int Property STAGE_ABANDONED = 200 AutoReadOnly

Bool finished = False
Bool engaged = False
Int wavesSpawned = 0
Actor[] raiders
Bool raidersReady = False

; Called by BSC_CompanyScript right after Start() succeeds.
Function Begin()
	finished = False
	engaged = False
	wavesSpawned = 0
	raiders = new Actor[8]
	raidersReady = True
	ObjectReference marker = MapMarker.GetReference()
	If marker
		marker.AddToMap()
	EndIf
	SetStage(STAGE_STARTED)
	SetObjectiveDisplayed(OBJ_MAIN)
	RegisterForSingleUpdate(5.0)
EndFunction

Event OnUpdate()
	If finished || !IsRunning()
		Return
	EndIf
	If ContractType == 2
		UpdateHold()
	Else
		UpdateKill()
	EndIf
	If !finished
		RegisterForSingleUpdate(4.0)
	EndIf
EndEvent

Function UpdateKill()
	Actor victim = Target.GetActorReference()
	If victim && victim.IsDead()
		Complete()
		Return
	EndIf
	If ContractType == 0
		Location loc = ContractLocation.GetLocation()
		If loc && loc.IsCleared()
			Complete()
		EndIf
	EndIf
EndFunction

Function UpdateHold()
	Actor player = Game.GetPlayer()
	ObjectReference marker = MapMarker.GetReference()
	If !marker
		Return
	EndIf
	If !engaged
		WorldSpace ws = player.GetWorldSpace()
		If ws && ws == marker.GetWorldSpace() && player.GetDistance(marker) < TriggerDistance
			engaged = True
			SetObjectiveCompleted(OBJ_MAIN)
			SetObjectiveDisplayed(OBJ_HOLD)
			SpawnWave()
		EndIf
	ElseIf WaveDefeated()
		If wavesSpawned >= WaveCount
			Complete()
		Else
			Debug.Notification("More raiders are coming. Hold the line!")
			SpawnWave()
		EndIf
	EndIf
EndFunction

Function SpawnWave()
	Actor player = Game.GetPlayer()
	ObjectReference marker = MapMarker.GetReference()
	Int count = 2 + Company.BSC_Rank.GetValueInt() / 2
	If count > raiders.Length
		count = raiders.Length
	EndIf
	Int i = 0
	While i < raiders.Length
		If i < count
			Actor raider = marker.PlaceAtMe(RaiderList) as Actor
			raiders[i] = raider
			If raider
				raider.StartCombat(player)
			EndIf
		Else
			raiders[i] = None
		EndIf
		i += 1
	EndWhile
	wavesSpawned += 1
EndFunction

Bool Function WaveDefeated()
	Int i = 0
	While i < raiders.Length
		If raiders[i] && !raiders[i].IsDead()
			Return False
		EndIf
		i += 1
	EndWhile
	Return True
EndFunction

Function CleanUpRaiders()
	If !raidersReady
		Return
	EndIf
	Int i = 0
	While i < raiders.Length
		If raiders[i]
			; Deleted once the cell unloads, so bodies stay lootable until then.
			raiders[i].Delete()
			raiders[i] = None
		EndIf
		i += 1
	EndWhile
EndFunction

Function Complete()
	If finished
		Return
	EndIf
	finished = True
	UnregisterForUpdate()
	CompleteAllObjectives()
	Company.ContractCompleted(ContractType)
	SetStage(STAGE_DONE)
	CleanUpRaiders()
	Stop()
EndFunction

Function Abandon()
	finished = True
	UnregisterForUpdate()
	FailAllObjectives()
	SetStage(STAGE_ABANDONED)
	CleanUpRaiders()
	Stop()
EndFunction
