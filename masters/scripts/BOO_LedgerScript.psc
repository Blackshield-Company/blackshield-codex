Scriptname BOO_LedgerScript extends Quest
{Daedric Ledger: Bounties of Oblivion - main controller. Delivers the Ledger,
runs its menus, dispatches contracts, pays out, and tracks favor, rivalries,
blessings and boons for the eight princes.}

; ---------------------------------------------------------------------------
; Properties (filled by the plugin generator, see src/plugin)
; ---------------------------------------------------------------------------

GlobalVariable Property BOO_Bound Auto
{1 once the player has signed the Ledger, -1 if they cast it away.}
GlobalVariable Property BOO_ContractActive Auto
GlobalVariable Property BOO_ContractsDone Auto
GlobalVariable Property BOO_IntroMinLevel Auto
GlobalVariable Property BOO_PayMult Auto
GlobalVariable Property BOO_FavorGain Auto
GlobalVariable Property BOO_RivalLoss Auto

GlobalVariable[] Property Favor Auto
{Favor per prince, 0 to 100. Index order below.}
Quest[] Property Contracts Auto
Spell[] Property Blessings Auto
Armor[] Property Boons Auto
Message[] Property OfferMessages Auto

Quest Property MQ101 Auto
Book Property BOO_Ledger Auto
Spell Property BOO_PowerLedger Auto
MiscObject Property Gold001 Auto

Message Property BOO_MsgArrival Auto
Message Property BOO_MsgBindOffer Auto
Message Property BOO_MsgBound Auto
Message Property BOO_MsgRefused Auto
Message Property BOO_MsgLedgerMenu Auto
Message Property BOO_MsgPrinceMenu Auto
Message Property BOO_MsgNoContract Auto
Message Property BOO_MsgContractStatus Auto

; Prince indices: 0 Mehrunes Dagon, 1 Boethiah, 2 Namira, 3 Molag Bal,
; 4 Clavicus Vile, 5 Hircine, 6 Sanguine, 7 Vaermina.
Int Property PRINCE_COUNT = 8 AutoReadOnly
Int Property BLESSING_FAVOR = 30 AutoReadOnly
Int Property BOON_FAVOR = 80 AutoReadOnly
Int Property MAX_FAVOR = 100 AutoReadOnly
Int Property AbandonPenalty = 10 AutoReadOnly

Bool ledgerDelivered = False
Float eligibleSince = -1.0
Bool[] boonGiven

; ---------------------------------------------------------------------------
; Delivery: the Ledger appears after the player sleeps (or after a day
; of being eligible, for players who never sleep).
; ---------------------------------------------------------------------------

Event OnInit()
	boonGiven = new Bool[8]
	RegisterForSleep()
	RegisterForSingleUpdate(30.0)
EndEvent

Event OnUpdate()
	If BOO_Bound.GetValueInt() != 0 || ledgerDelivered
		Return
	EndIf
	If CanDeliver()
		Float now = Utility.GetCurrentGameTime()
		If eligibleSince < 0.0
			eligibleSince = now
		ElseIf now - eligibleSince >= 1.0
			DeliverLedger()
			Return
		EndIf
	EndIf
	RegisterForSingleUpdate(60.0)
EndEvent

Event OnSleepStop(Bool abInterrupted)
	If BOO_Bound.GetValueInt() != 0
		Return
	EndIf
	; Also re-delivers a Ledger the player lost or sold before signing it.
	If (!ledgerDelivered || Game.GetPlayer().GetItemCount(BOO_Ledger) == 0) && CanDeliver()
		DeliverLedger()
	EndIf
EndEvent

Bool Function CanDeliver()
	Actor player = Game.GetPlayer()
	If player.GetLevel() < BOO_IntroMinLevel.GetValueInt()
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

Function DeliverLedger()
	ledgerDelivered = True
	BOO_MsgArrival.Show()
	Game.GetPlayer().AddItem(BOO_Ledger, 1)
EndFunction

; Called by BOO_LedgerBookScript when the player reads the Ledger.
Function OnLedgerRead()
	ledgerDelivered = True
	Int bound = BOO_Bound.GetValueInt()
	If bound > 0
		OpenLedger()
		Return
	EndIf
	Int choice = BOO_MsgBindOffer.Show()
	If choice == 0
		Bind()
	ElseIf choice == 2
		BOO_Bound.SetValueInt(-1)
		UnregisterForSleep()
		Game.GetPlayer().RemoveItem(BOO_Ledger, 99, True)
		BOO_MsgRefused.Show()
	EndIf
EndFunction

Function Bind()
	BOO_Bound.SetValueInt(1)
	UnregisterForSleep()
	Game.GetPlayer().AddSpell(BOO_PowerLedger)
	BOO_MsgBound.Show()
EndFunction

; ---------------------------------------------------------------------------
; Ledger menus (lesser power + ledger book)
; ---------------------------------------------------------------------------

Function OpenLedger()
	If BOO_Bound.GetValueInt() <= 0
		Return
	EndIf
	SyncContractActive()
	Bool keepOpen = True
	While keepOpen
		Int choice = BOO_MsgLedgerMenu.Show(BOO_ContractsDone.GetValue())
		If choice == 0
			keepOpen = !PrinceMenu()
		ElseIf choice == 1
			keepOpen = ContractStatusMenu()
		ElseIf choice == 2
			Debug.MessageBox(StandingsText())
			keepOpen = False
		Else
			keepOpen = False
		EndIf
	EndWhile
EndFunction

; Returns True if a contract was taken (closes the ledger).
Bool Function PrinceMenu()
	While True
		Int prince = BOO_MsgPrinceMenu.Show()
		If prince < 0 || prince >= PRINCE_COUNT
			Return False
		EndIf
		If OfferMessages[prince].Show(Favor[prince].GetValue()) == 0
			If TakeContract(prince)
				Return True
			EndIf
		EndIf
	EndWhile
	Return False
EndFunction

Bool Function TakeContract(Int aiPrince)
	If ActiveContract() != None
		Return False
	EndIf
	Quest q = Contracts[aiPrince]
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
		BOO_MsgNoContract.Show()
		Return False
	EndIf
	BOO_ContractActive.SetValueInt(1)
	(q as BOO_ContractScript).Begin()
	Return True
EndFunction

; Returns True to keep the ledger open.
Bool Function ContractStatusMenu()
	BOO_ContractScript active = ActiveContract()
	If active == None
		BOO_ContractActive.SetValueInt(0)
		Return True
	EndIf
	If BOO_MsgContractStatus.Show() == 1
		Int prince = active.Prince
		active.Abandon()
		BOO_ContractActive.SetValueInt(0)
		ModFavor(prince, -AbandonPenalty)
		Debug.Notification(PrinceName(prince) + " will remember this.")
		Return True
	EndIf
	Return False
EndFunction

BOO_ContractScript Function ActiveContract()
	Int i = 0
	While i < Contracts.Length
		If Contracts[i].IsRunning()
			Return Contracts[i] as BOO_ContractScript
		EndIf
		i += 1
	EndWhile
	Return None
EndFunction

Function SyncContractActive()
	If ActiveContract() != None
		BOO_ContractActive.SetValueInt(1)
	Else
		BOO_ContractActive.SetValueInt(0)
	EndIf
EndFunction

; Called by BOO_RevelWineEffectScript whenever the player drinks Revel Wine.
Function OnRevelDrink()
	BOO_ContractScript active = ActiveContract()
	If active && active.ContractType == 3
		active.OnRevelDrink()
	EndIf
EndFunction

; ---------------------------------------------------------------------------
; Payment, favor, rivalries, blessings and boons
; ---------------------------------------------------------------------------

; Called by BOO_ContractScript when a contract is fulfilled.
Function ContractCompleted(Int aiPrince)
	Actor player = Game.GetPlayer()
	Int pay = Math.Floor((150.0 + 10.0 * player.GetLevel()) * BOO_PayMult.GetValue())
	Int gain = BOO_FavorGain.GetValueInt()
	Int loss = BOO_RivalLoss.GetValueInt()
	Int rival = RivalOf(aiPrince)

	If pay > 0
		player.AddItem(Gold001, pay, True)
	EndIf
	BOO_ContractsDone.Mod(1)
	BOO_ContractActive.SetValueInt(0)

	Int before = Favor[aiPrince].GetValueInt()
	Int rivalBefore = Favor[rival].GetValueInt()
	SetFavor(aiPrince, before + gain)
	SetFavor(rival, rivalBefore - loss)
	Int after = Favor[aiPrince].GetValueInt()
	Int rivalAfter = Favor[rival].GetValueInt()

	String text = PrinceName(aiPrince) + " is satisfied.\n\n"
	text += pay + " gold.\n"
	text += "Favor with " + PrinceName(aiPrince) + ": " + before + " -> " + after + "\n"
	If rivalAfter != rivalBefore
		text += "Favor with " + PrinceName(rival) + ": " + rivalBefore + " -> " + rivalAfter
	Else
		text += PrinceName(rival) + " has nothing left to take from you."
	EndIf
	Debug.MessageBox(text)

	ApplyTiers(aiPrince)
	ApplyTiers(rival)
EndFunction

Function ModFavor(Int aiPrince, Int aiAmount)
	SetFavor(aiPrince, Favor[aiPrince].GetValueInt() + aiAmount)
	ApplyTiers(aiPrince)
EndFunction

Function SetFavor(Int aiPrince, Int aiValue)
	If aiValue < 0
		aiValue = 0
	ElseIf aiValue > MAX_FAVOR
		aiValue = MAX_FAVOR
	EndIf
	Favor[aiPrince].SetValueInt(aiValue)
EndFunction

; Grants or removes the blessing, and hands out the boon once.
Function ApplyTiers(Int aiPrince)
	Actor player = Game.GetPlayer()
	Int value = Favor[aiPrince].GetValueInt()
	Spell blessing = Blessings[aiPrince]
	If value >= BLESSING_FAVOR
		If !player.HasSpell(blessing)
			player.AddSpell(blessing, False)
			Debug.MessageBox(PrinceName(aiPrince) + " grants you a blessing.\n\n" + BlessingText(aiPrince) + "\n\nIt lasts while your favor stays at " + BLESSING_FAVOR + " or more.")
		EndIf
	ElseIf player.HasSpell(blessing)
		player.RemoveSpell(blessing)
		Debug.Notification("The blessing of " + PrinceName(aiPrince) + " fades.")
	EndIf
	If value >= BOON_FAVOR
		If boonGiven.Length != PRINCE_COUNT
			boonGiven = new Bool[8]
		EndIf
		If !boonGiven[aiPrince]
			boonGiven[aiPrince] = True
			player.AddItem(Boons[aiPrince], 1, True)
			Debug.MessageBox(PrinceName(aiPrince) + " counts you among the chosen, and sends a gift: " + BoonText(aiPrince) + ".")
		EndIf
	EndIf
EndFunction

Int Function RivalOf(Int aiPrince)
	If aiPrince == 0
		Return 1
	ElseIf aiPrince == 1
		Return 0
	ElseIf aiPrince == 2
		Return 4
	ElseIf aiPrince == 4
		Return 2
	ElseIf aiPrince == 3
		Return 5
	ElseIf aiPrince == 5
		Return 3
	ElseIf aiPrince == 6
		Return 7
	EndIf
	Return 6
EndFunction

String Function PrinceName(Int aiPrince)
	If aiPrince == 0
		Return "Mehrunes Dagon"
	ElseIf aiPrince == 1
		Return "Boethiah"
	ElseIf aiPrince == 2
		Return "Namira"
	ElseIf aiPrince == 3
		Return "Molag Bal"
	ElseIf aiPrince == 4
		Return "Clavicus Vile"
	ElseIf aiPrince == 5
		Return "Hircine"
	ElseIf aiPrince == 6
		Return "Sanguine"
	EndIf
	Return "Vaermina"
EndFunction

String Function BlessingText(Int aiPrince)
	If aiPrince == 0
		Return "Blessing of Dagon: Resist Fire +15%"
	ElseIf aiPrince == 1
		Return "Blessing of Boethiah: Health +20"
	ElseIf aiPrince == 2
		Return "Blessing of Namira: Resist Disease +50%, Resist Poison +15%"
	ElseIf aiPrince == 3
		Return "Blessing of Molag Bal: Resist Frost +15%"
	ElseIf aiPrince == 4
		Return "Blessing of Clavicus Vile: Carry Weight +25"
	ElseIf aiPrince == 5
		Return "Blessing of Hircine: Stamina +25"
	ElseIf aiPrince == 6
		Return "Blessing of Sanguine: Stamina regenerates 25% faster"
	EndIf
	Return "Blessing of Vaermina: Magicka regenerates 25% faster"
EndFunction

String Function BoonText(Int aiPrince)
	If aiPrince == 0
		Return "the Ember Torc of Dagon (Destruction +12%)"
	ElseIf aiPrince == 1
		Return "Oathbreaker's Band (One-Handed +15%)"
	ElseIf aiPrince == 2
		Return "the Ring of the Hollow (Sneak +15%)"
	ElseIf aiPrince == 3
		Return "the Chain of Coldharbour (Two-Handed +15%)"
	ElseIf aiPrince == 4
		Return "the Band of the Wager (Speech +15%)"
	ElseIf aiPrince == 5
		Return "the Fang of the Hunt (Archery +15%)"
	ElseIf aiPrince == 6
		Return "Sanguine's Merry Band (Health regenerates 25% faster)"
	EndIf
	Return "the Dreamstone of Vaermina (Illusion +15%)"
EndFunction

String Function TierName(Int aiFavor)
	If aiFavor >= BOON_FAVOR
		Return "Chosen"
	ElseIf aiFavor >= BLESSING_FAVOR
		Return "Blessed"
	ElseIf aiFavor > 0
		Return "Noticed"
	EndIf
	Return "Unknown"
EndFunction

String Function StandingsText()
	String text = "FAVOR OF THE PRINCES\n"
	Int i = 0
	While i < PRINCE_COUNT
		Int value = Favor[i].GetValueInt()
		text += "\n" + PrinceName(i) + ": " + value + " (" + TierName(value) + ")"
		i += 1
	EndWhile
	text += "\n\nBlessing at " + BLESSING_FAVOR + ". Gift at " + BOON_FAVOR + ". Contracts fulfilled: " + BOO_ContractsDone.GetValueInt()
	Return text
EndFunction
