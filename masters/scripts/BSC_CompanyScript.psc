Scriptname BSC_CompanyScript extends Quest
{Blackshield Company - main controller. Handles recruitment, the company
ledger menus, contract dispatch and payment, renown and rank progression,
the company treasury and the company sellsword.}

; ---------------------------------------------------------------------------
; Properties (filled by the plugin generator, see src/plugin)
; ---------------------------------------------------------------------------

GlobalVariable Property BSC_Joined Auto
GlobalVariable Property BSC_Rank Auto
GlobalVariable Property BSC_Renown Auto
GlobalVariable Property BSC_Treasury Auto
GlobalVariable Property BSC_ContractsDone Auto
GlobalVariable Property BSC_ContractActive Auto
GlobalVariable Property BSC_TreasuryShare Auto
GlobalVariable Property BSC_IntroMinLevel Auto
GlobalVariable Property BSC_PayMult Auto
GlobalVariable Property PlayerFollowerCount Auto

Quest Property MQ101 Auto
Quest Property DialogueFollower Auto

Quest[] Property Contracts Auto
{0 = clear a bandit camp, 1 = bounty on a marked target, 2 = hold a fort}

Book Property BSC_Letter Auto
Book Property BSC_Ledger Auto
Spell Property BSC_PowerLedger Auto
Spell Property BSC_AbCommander Auto
Weapon Property BSC_BlackshieldBlade Auto
Armor Property BSC_BlackshieldShield Auto
Armor Property BSC_BlackshieldPlate Auto
ActorBase Property BSC_Sellsword Auto
MiscObject Property Gold001 Auto

ReferenceAlias Property Sellsword Auto

Message Property BSC_MsgCourier Auto
Message Property BSC_MsgJoinOffer Auto
Message Property BSC_MsgWelcome Auto
Message Property BSC_MsgNotMember Auto
Message[] Property LedgerMenus Auto
{One main ledger menu per rank, 0 (Recruit) to 4 (Commander).}
Message Property BSC_MsgContractMenu Auto
Message Property BSC_MsgNoContract Auto
Message Property BSC_MsgContractStatus Auto
Message Property BSC_MsgContractPaid Auto
Message Property BSC_MsgTreasury Auto
Message Property BSC_MsgTreasuryLocked Auto
Message[] Property PromotionMessages Auto
{Index 1..4 = promotion to Blade, Sergeant, Captain, Commander. Index 0 unused.}

; ---------------------------------------------------------------------------
; Tunables
; ---------------------------------------------------------------------------

Int Property RANK_RECRUIT = 0 AutoReadOnly
Int Property RANK_BLADE = 1 AutoReadOnly
Int Property RANK_SERGEANT = 2 AutoReadOnly
Int Property RANK_CAPTAIN = 3 AutoReadOnly
Int Property RANK_COMMANDER = 4 AutoReadOnly

Int Property AbandonPenalty = 10 AutoReadOnly
Int Property SigningBonus = 100 AutoReadOnly

Bool letterDelivered = False

; ---------------------------------------------------------------------------
; Recruitment: a courier letter arrives once the player is out in the world
; ---------------------------------------------------------------------------

Event OnInit()
	RegisterForSingleUpdate(20.0)
EndEvent

Event OnUpdate()
	If BSC_Joined.GetValueInt() != 0 || letterDelivered
		Return
	EndIf
	If CanDeliverLetter()
		DeliverLetter()
	Else
		RegisterForSingleUpdate(30.0)
	EndIf
EndEvent

Bool Function CanDeliverLetter()
	Actor player = Game.GetPlayer()
	If player.GetLevel() < BSC_IntroMinLevel.GetValueInt()
		Return False
	EndIf
	; Still inside the vanilla Helgen intro? (Alternate-start mods never run it.)
	If MQ101 && MQ101.IsRunning() && !MQ101.IsCompleted()
		Return False
	EndIf
	If player.IsInCombat()
		Return False
	EndIf
	If !Game.IsMovementControlsEnabled() || !Game.IsFightingControlsEnabled()
		Return False
	EndIf
	Return True
EndFunction

Function DeliverLetter()
	letterDelivered = True
	BSC_MsgCourier.Show()
	Game.GetPlayer().AddItem(BSC_Letter, 1)
EndFunction

; Called by BSC_LetterScript when the player reads the recruitment letter.
Function OnLetterRead()
	letterDelivered = True
	If BSC_Joined.GetValueInt() != 0
		Return
	EndIf
	If BSC_MsgJoinOffer.Show() == 0
		Join()
	EndIf
EndFunction

Function Join()
	Actor player = Game.GetPlayer()
	BSC_Joined.SetValueInt(1)
	BSC_Rank.SetValueInt(RANK_RECRUIT)
	player.AddItem(BSC_Ledger, 1)
	player.AddSpell(BSC_PowerLedger)
	player.AddItem(Gold001, SigningBonus)
	BSC_MsgWelcome.Show()
EndFunction

; ---------------------------------------------------------------------------
; The company ledger (lesser power + ledger book)
; ---------------------------------------------------------------------------

Function OpenLedger()
	If BSC_Joined.GetValueInt() == 0
		BSC_MsgNotMember.Show()
		Return
	EndIf
	SyncContractActive()
	Bool keepOpen = True
	While keepOpen
		Int rank = BSC_Rank.GetValueInt()
		Message menu = LedgerMenus[rank]
		Int choice
		If rank >= RANK_COMMANDER
			; The Commander menu has no "next rank" field.
			choice = menu.Show(BSC_Renown.GetValue(), BSC_Treasury.GetValue(), BSC_ContractsDone.GetValue())
		Else
			choice = menu.Show(BSC_Renown.GetValue(), NextRankThreshold(rank), BSC_Treasury.GetValue(), BSC_ContractsDone.GetValue())
		EndIf
		If choice == 0
			keepOpen = !ContractMenu()
		ElseIf choice == 1
			keepOpen = ContractStatusMenu()
		ElseIf choice == 2
			TreasuryMenu()
		ElseIf choice == 3
			SummonSellsword()
			keepOpen = False
		Else
			keepOpen = False
		EndIf
	EndWhile
EndFunction

; Returns True if a contract was taken (closes the ledger).
Bool Function ContractMenu()
	Int choice = BSC_MsgContractMenu.Show()
	If choice < 0 || choice > 2
		Return False
	EndIf
	Return TakeContract(choice)
EndFunction

Bool Function TakeContract(Int aiType)
	If ActiveContract() != None
		Return False
	EndIf
	Quest q = Contracts[aiType]
	If q.IsRunning()
		q.Stop()
	EndIf
	Int tries = 0
	While q.IsStopping() && tries < 50
		Utility.Wait(0.1)
		tries += 1
	EndWhile
	q.Reset()
	If !q.Start()
		BSC_MsgNoContract.Show()
		Return False
	EndIf
	BSC_ContractActive.SetValueInt(1)
	(q as BSC_ContractScript).Begin()
	Return True
EndFunction

; Returns True to keep the ledger open.
Bool Function ContractStatusMenu()
	BSC_ContractScript active = ActiveContract()
	If active == None
		BSC_ContractActive.SetValueInt(0)
		Return True
	EndIf
	If BSC_MsgContractStatus.Show() == 1
		active.Abandon()
		BSC_ContractActive.SetValueInt(0)
		AddRenown(-AbandonPenalty)
		Debug.Notification("Contract abandoned. The company remembers.")
		Return True
	EndIf
	Return False
EndFunction

BSC_ContractScript Function ActiveContract()
	Int i = 0
	While i < Contracts.Length
		If Contracts[i].IsRunning()
			Return Contracts[i] as BSC_ContractScript
		EndIf
		i += 1
	EndWhile
	Return None
EndFunction

Function SyncContractActive()
	If ActiveContract() != None
		BSC_ContractActive.SetValueInt(1)
	Else
		BSC_ContractActive.SetValueInt(0)
	EndIf
EndFunction

; ---------------------------------------------------------------------------
; Payment, renown and ranks
; ---------------------------------------------------------------------------

Int Function BasePay(Int aiType)
	If aiType == 0
		Return 300
	ElseIf aiType == 1
		Return 250
	EndIf
	Return 350
EndFunction

Int Function BaseRenown(Int aiType)
	If aiType == 0
		Return 50
	ElseIf aiType == 1
		Return 40
	EndIf
	Return 60
EndFunction

Float Function NextRankThreshold(Int aiRank)
	If aiRank == RANK_RECRUIT
		Return 100.0
	ElseIf aiRank == RANK_BLADE
		Return 300.0
	ElseIf aiRank == RANK_SERGEANT
		Return 700.0
	ElseIf aiRank == RANK_CAPTAIN
		Return 1500.0
	EndIf
	Return 0.0
EndFunction

; Called by BSC_ContractScript when a contract objective is fulfilled.
Function ContractCompleted(Int aiType)
	Actor player = Game.GetPlayer()
	Int rank = BSC_Rank.GetValueInt()
	Float pay = (BasePay(aiType) + 15.0 * player.GetLevel()) * (1.0 + 0.1 * rank) * BSC_PayMult.GetValue()
	If rank >= RANK_COMMANDER
		pay = pay * 1.25
	EndIf
	Int total = Math.Floor(pay)
	Int share = Math.Floor(total * BSC_TreasuryShare.GetValue())
	Int net = total - share
	Int renown = BaseRenown(aiType)

	If net > 0
		player.AddItem(Gold001, net, True)
	EndIf
	BSC_Treasury.Mod(share)
	BSC_ContractsDone.Mod(1)
	BSC_ContractActive.SetValueInt(0)
	BSC_MsgContractPaid.Show(net, share, renown, BSC_Renown.GetValue() + renown)
	AddRenown(renown)
EndFunction

Function AddRenown(Int aiAmount)
	Float value = BSC_Renown.GetValue() + aiAmount
	If value < 0.0
		value = 0.0
	EndIf
	BSC_Renown.SetValue(value)
	Int rank = BSC_Rank.GetValueInt()
	While rank < RANK_COMMANDER && value >= NextRankThreshold(rank)
		rank += 1
		Promote(rank)
	EndWhile
EndFunction

Function Promote(Int aiNewRank)
	Actor player = Game.GetPlayer()
	BSC_Rank.SetValueInt(aiNewRank)
	If aiNewRank == RANK_BLADE
		player.AddItem(BSC_BlackshieldBlade, 1)
	ElseIf aiNewRank == RANK_SERGEANT
		player.AddItem(BSC_BlackshieldShield, 1)
	ElseIf aiNewRank == RANK_CAPTAIN
		player.AddItem(BSC_BlackshieldPlate, 1)
	ElseIf aiNewRank == RANK_COMMANDER
		player.AddSpell(BSC_AbCommander)
	EndIf
	PromotionMessages[aiNewRank].Show()
EndFunction

; ---------------------------------------------------------------------------
; Treasury
; ---------------------------------------------------------------------------

Function TreasuryMenu()
	If BSC_Rank.GetValueInt() < RANK_CAPTAIN
		BSC_MsgTreasuryLocked.Show(BSC_Treasury.GetValue())
		Return
	EndIf
	Int choice = BSC_MsgTreasury.Show(BSC_Treasury.GetValue())
	If choice == 0
		Withdraw(100)
	ElseIf choice == 1
		Withdraw(500)
	ElseIf choice == 2
		Withdraw(BSC_Treasury.GetValueInt())
	EndIf
EndFunction

Function Withdraw(Int aiAmount)
	Int available = BSC_Treasury.GetValueInt()
	If aiAmount > available
		aiAmount = available
	EndIf
	If aiAmount <= 0
		Debug.Notification("The company treasury is empty.")
		Return
	EndIf
	BSC_Treasury.SetValue(available - aiAmount)
	Game.GetPlayer().AddItem(Gold001, aiAmount)
EndFunction

; ---------------------------------------------------------------------------
; Company sellsword (Captain and above), uses the vanilla follower system
; ---------------------------------------------------------------------------

Function SummonSellsword()
	Actor player = Game.GetPlayer()
	If BSC_Rank.GetValueInt() < RANK_CAPTAIN
		Return
	EndIf
	Actor merc = Sellsword.GetActorReference()
	If merc && !merc.IsDead()
		merc.MoveTo(player)
	Else
		merc = player.PlaceActorAtMe(BSC_Sellsword)
		Sellsword.ForceRefTo(merc)
	EndIf
	merc.SetRelationshipRank(player, 3)
	If PlayerFollowerCount.GetValue() < 1.0
		(DialogueFollower as DialogueFollowerScript).SetFollower(merc)
		Debug.Notification("A Blackshield sellsword falls in at your side.")
	ElseIf merc.IsPlayerTeammate()
		Debug.Notification("Your Blackshield sellsword rejoins you.")
	Else
		Debug.Notification("A Blackshield sellsword reports for duty. Dismiss your current follower to take them along.")
	EndIf
EndFunction
