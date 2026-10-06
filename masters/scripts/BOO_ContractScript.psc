Scriptname BOO_ContractScript extends Quest
{Daedric Ledger: Bounties of Oblivion - shared logic for the princes' radiant tasks.
ContractType 0 = kill a target, 1 = clear a location (or kill its boss),
2 = recover a relic, 3 = Sanguine's revel (drink at an inn).}

BOO_LedgerScript Property Ledger Auto
Int Property Prince Auto
Int Property ContractType Auto
LocationAlias Property ContractLocation Auto
ReferenceAlias Property MapMarker Auto
ReferenceAlias Property Target Auto
{Kill/clear: the boss or the created champion/quarry.}
ReferenceAlias Property Relic Auto
{Fetch: the relic created in the location's boss container.}
MiscObject Property RelicItem Auto
GlobalVariable Property BOO_RevelCount Auto
Potion Property BOO_RevelWine Auto
Int Property RevelNeeded = 3 AutoReadOnly
Int Property RevelWineGiven = 4 AutoReadOnly

Int Property OBJ_MAIN = 10 AutoReadOnly
Int Property STAGE_STARTED = 10 AutoReadOnly
Int Property STAGE_DONE = 100 AutoReadOnly
Int Property STAGE_ABANDONED = 200 AutoReadOnly

Bool finished = False

; Called by BOO_LedgerScript right after Start() succeeds.
Function Begin()
	finished = False
	ObjectReference marker = MapMarker.GetReference()
	If marker && ContractType != 3
		marker.AddToMap()
	EndIf
	If ContractType == 3
		BOO_RevelCount.SetValueInt(0)
		UpdateCurrentInstanceGlobal(BOO_RevelCount)
		Game.GetPlayer().AddItem(BOO_RevelWine, RevelWineGiven)
	EndIf
	SetStage(STAGE_STARTED)
	SetObjectiveDisplayed(OBJ_MAIN)
	If ContractType != 3
		RegisterForSingleUpdate(5.0)
	EndIf
EndFunction

Event OnUpdate()
	If finished || !IsRunning()
		Return
	EndIf
	If ContractType == 2
		UpdateFetch()
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
	If ContractType == 1
		Location loc = ContractLocation.GetLocation()
		If loc && loc.IsCleared()
			Complete()
		EndIf
	EndIf
EndFunction

Function UpdateFetch()
	If RelicItem && Game.GetPlayer().GetItemCount(RelicItem) > 0
		Complete()
	EndIf
EndFunction

; Sanguine's revel: count drinks taken inside the chosen inn.
Function OnRevelDrink()
	If finished || !IsRunning()
		Return
	EndIf
	Location loc = ContractLocation.GetLocation()
	If loc && Game.GetPlayer().IsInLocation(loc)
		BOO_RevelCount.Mod(1)
		UpdateCurrentInstanceGlobal(BOO_RevelCount)
		SetObjectiveDisplayed(OBJ_MAIN, True, True)
		Int count = BOO_RevelCount.GetValueInt()
		If count >= RevelNeeded
			Complete()
		Else
			Debug.Notification("Sanguine raises a glass with you. (" + count + "/" + RevelNeeded + ")")
		EndIf
	Else
		Debug.Notification("Sanguine sulks. The toast was meant for the inn he chose.")
	EndIf
EndFunction

Function Complete()
	If finished
		Return
	EndIf
	finished = True
	UnregisterForUpdate()
	If ContractType == 2 && RelicItem
		; The relic returns to its prince.
		Game.GetPlayer().RemoveItem(RelicItem, 99, True)
	EndIf
	CompleteAllObjectives()
	Ledger.ContractCompleted(Prince)
	SetStage(STAGE_DONE)
	Stop()
EndFunction

Function Abandon()
	finished = True
	UnregisterForUpdate()
	FailAllObjectives()
	SetStage(STAGE_ABANDONED)
	Stop()
EndFunction
