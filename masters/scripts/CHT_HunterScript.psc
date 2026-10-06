Scriptname CHT_HunterScript extends Quest
{Contract Hunter - main controller. Delivers the Hunter's Writ, runs the
ledger menus, sends bounty letters by courier, pays bounties, and tracks
per-outlaw notoriety, per-hold standing and the avengers sent after a
hunter who lets a Dread warrant lapse.}

; ---------------------------------------------------------------------------
; Properties (filled by the plugin generator, see src/plugin)
; ---------------------------------------------------------------------------

GlobalVariable Property CHT_Registered Auto
GlobalVariable[] Property OpenFlags Auto
{1 while a bounty of that tier is open. 0 Notice, 1 Wanted, 2 Dread.}
GlobalVariable Property CHT_OpenCount Auto
GlobalVariable Property CHT_BountiesClaimed Auto
GlobalVariable Property CHT_EscapedOutlaws Auto
GlobalVariable Property CHT_IntroMinLevel Auto
GlobalVariable Property CHT_WantedMinLevel Auto
GlobalVariable Property CHT_DreadMinLevel Auto
GlobalVariable Property CHT_PayMult Auto
GlobalVariable Property CHT_LetterIntervalDays Auto
GlobalVariable[] Property Standing Auto
{Standing with each hold, 0 to 100, same order as Holds.}
Location[] Property Holds Auto
Quest[] Property Bounties Auto
{One quest per named outlaw: 8 Notice, 8 Wanted, 6 Dread.}

Quest Property MQ101 Auto
Book Property CHT_HuntersWrit Auto
Spell Property CHT_PowerLedger Auto
MiscObject Property CHT_TrophySignet Auto
MiscObject Property CHT_TrophySkull Auto
LeveledActor Property CHT_LCharDreadAvenger Auto
MiscObject Property Gold001 Auto
Keyword[] Property SafeLocationTypes Auto
{Avengers never attack inside these (cities, towns, settlements, homes).}

Message Property CHT_MsgIntroCourier Auto
Message Property CHT_MsgRegisterOffer Auto
Message Property CHT_MsgRegistered Auto
Message Property CHT_MsgBountyCourier Auto
Message Property CHT_MsgLedgerMenu Auto
Message Property CHT_MsgRequestMenu Auto
Message Property CHT_MsgAbandonMenu Auto
Message Property CHT_MsgNoBounty Auto

; ---------------------------------------------------------------------------
; Tunables
; ---------------------------------------------------------------------------

Int Property TIER_NOTICE = 0 AutoReadOnly
Int Property TIER_WANTED = 1 AutoReadOnly
Int Property TIER_DREAD = 2 AutoReadOnly
Int Property OUTLAW_COUNT = 22 AutoReadOnly
Int Property HOLD_COUNT = 9 AutoReadOnly
Int Property MAX_OPEN = 3 AutoReadOnly
Int Property MAX_NOTORIETY = 3 AutoReadOnly
Int Property JARL_GIFT_STANDING = 50 AutoReadOnly
Int Property JARL_GIFT_GOLD = 500 AutoReadOnly
Int Property MAX_AVENGERS = 4 AutoReadOnly

Bool writDelivered = False
Int[] notoriety
Bool[] retired
Bool[] jarlGiftGiven
Float nextLetterTime = 0.0
Int pendingAvengers = 0

; ---------------------------------------------------------------------------
; Intro: the Hunter's Writ
; ---------------------------------------------------------------------------

Event OnInit()
	notoriety = new Int[22]
	retired = new Bool[22]
	jarlGiftGiven = new Bool[9]
	RegisterForSingleUpdate(20.0)
EndEvent

; Real-time poll, only until the writ has been delivered.
Event OnUpdate()
	If CHT_Registered.GetValueInt() != 0 || writDelivered
		Return
	EndIf
	If Game.GetPlayer().GetLevel() >= CHT_IntroMinLevel.GetValueInt() && CanDeliver()
		DeliverWrit()
	Else
		RegisterForSingleUpdate(30.0)
	EndIf
EndEvent

Function DeliverWrit()
	writDelivered = True
	CHT_MsgIntroCourier.Show()
	Game.GetPlayer().AddItem(CHT_HuntersWrit, 1)
	; Re-delivered once a day if it gets lost before it is signed.
	RegisterForSingleUpdateGameTime(24.0)
EndFunction

Bool Function CanDeliver()
	Actor player = Game.GetPlayer()
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

; Called by CHT_WritScript when the writ is read.
Function OnWritRead()
	writDelivered = True
	If CHT_Registered.GetValueInt() != 0
		OpenLedger()
		Return
	EndIf
	If CHT_MsgRegisterOffer.Show() == 0
		Register()
	EndIf
EndFunction

Function Register()
	CHT_Registered.SetValueInt(1)
	Game.GetPlayer().AddSpell(CHT_PowerLedger)
	CHT_MsgRegistered.Show()
	; The first notice arrives within the next game day.
	nextLetterTime = Utility.GetCurrentGameTime() + 0.25
	RegisterForSingleUpdateGameTime(6.0)
EndFunction

; ---------------------------------------------------------------------------
; Game-time tick (every 6 hours, 1 hour while avengers are pending)
; ---------------------------------------------------------------------------

Event OnUpdateGameTime()
	Actor player = Game.GetPlayer()
	If CHT_Registered.GetValueInt() == 0
		If writDelivered && player.GetItemCount(CHT_HuntersWrit) == 0 && CanDeliver()
			CHT_MsgIntroCourier.Show()
			player.AddItem(CHT_HuntersWrit, 1)
		EndIf
		RegisterForSingleUpdateGameTime(24.0)
		Return
	EndIf
	If pendingAvengers > 0
		TrySendAvengers()
	EndIf
	Float now = Utility.GetCurrentGameTime()
	If now >= nextLetterTime && CHT_OpenCount.GetValueInt() < MAX_OPEN && CanDeliver()
		Int tier = PickCourierTier()
		If tier >= 0
			StartBounty(tier)
		EndIf
		nextLetterTime = now + CHT_LetterIntervalDays.GetValue()
	EndIf
	If pendingAvengers > 0
		RegisterForSingleUpdateGameTime(1.0)
	Else
		RegisterForSingleUpdateGameTime(6.0)
	EndIf
EndEvent

Int Function PickCourierTier()
	Int level = Game.GetPlayer().GetLevel()
	Int[] candidates = new Int[3]
	Int n = 0
	If OpenFlags[TIER_NOTICE].GetValueInt() == 0
		candidates[n] = TIER_NOTICE
		n += 1
	EndIf
	If OpenFlags[TIER_WANTED].GetValueInt() == 0 && level >= CHT_WantedMinLevel.GetValueInt()
		candidates[n] = TIER_WANTED
		n += 1
	EndIf
	; Dread warrants are rarer by courier: one chance in three.
	If OpenFlags[TIER_DREAD].GetValueInt() == 0 && level >= CHT_DreadMinLevel.GetValueInt() && Utility.RandomInt(0, 2) == 0
		candidates[n] = TIER_DREAD
		n += 1
	EndIf
	If n == 0
		Return -1
	EndIf
	Return candidates[Utility.RandomInt(0, n - 1)]
EndFunction

; ---------------------------------------------------------------------------
; Starting bounties
; ---------------------------------------------------------------------------

Int Function TierStart(Int aiTier)
	If aiTier == TIER_NOTICE
		Return 0
	ElseIf aiTier == TIER_WANTED
		Return 8
	EndIf
	Return 16
EndFunction

Int Function TierSize(Int aiTier)
	If aiTier == TIER_DREAD
		Return 6
	EndIf
	Return 8
EndFunction

Int Function TierOf(Int aiIndex)
	If aiIndex < 8
		Return TIER_NOTICE
	ElseIf aiIndex < 16
		Return TIER_WANTED
	EndIf
	Return TIER_DREAD
EndFunction

Bool Function StartBounty(Int aiTier)
	If OpenFlags[aiTier].GetValueInt() != 0 || CHT_OpenCount.GetValueInt() >= MAX_OPEN
		Return False
	EndIf
	Int first = TierStart(aiTier)
	Int count = TierSize(aiTier)
	If CountAvailable(first, count) == 0
		; Every outlaw of this tier is dead: new faces take up the old names.
		Int r = 0
		While r < count
			retired[first + r] = False
			r += 1
		EndWhile
	EndIf
	; Escaped outlaws come back first, half of the time.
	If Utility.RandomInt(0, 1) == 0
		Int escaped = FindEscaped(first, count)
		If escaped >= 0 && TryStart(escaped)
			Return True
		EndIf
	EndIf
	Int offset = Utility.RandomInt(0, count - 1)
	Int attempts = 0
	Int i = 0
	While i < count && attempts < 4
		Int idx = first + (offset + i) % count
		If !retired[idx] && !Bounties[idx].IsRunning()
			attempts += 1
			If TryStart(idx)
				Return True
			EndIf
		EndIf
		i += 1
	EndWhile
	Return False
EndFunction

Int Function CountAvailable(Int aiFirst, Int aiCount)
	Int n = 0
	Int i = 0
	While i < aiCount
		If !retired[aiFirst + i]
			n += 1
		EndIf
		i += 1
	EndWhile
	Return n
EndFunction

Int Function FindEscaped(Int aiFirst, Int aiCount)
	Int i = 0
	While i < aiCount
		Int idx = aiFirst + i
		If notoriety[idx] > 0 && !retired[idx] && !Bounties[idx].IsRunning()
			Return idx
		EndIf
		i += 1
	EndWhile
	Return -1
EndFunction

Bool Function TryStart(Int aiIndex)
	Quest q = Bounties[aiIndex]
	If q.IsRunning()
		Return False
	EndIf
	Int tries = 0
	While q.IsStopping() && tries < 50
		Utility.Wait(0.1)
		tries += 1
	EndWhile
	q.Reset()
	If !q.Start()
		Return False
	EndIf
	OpenFlags[TierOf(aiIndex)].SetValueInt(1)
	RecountOpen()
	CHT_MsgBountyCourier.Show()
	(q as CHT_BountyScript).Begin(notoriety[aiIndex])
	Return True
EndFunction

; ---------------------------------------------------------------------------
; Results (called by CHT_BountyScript)
; ---------------------------------------------------------------------------

Function BountyClaimed(Int aiIndex, Int aiTier, Location akLocation)
	Actor player = Game.GetPlayer()
	Int hold = HoldIndex(akLocation)
	Float standingMult = 1.0
	If hold >= 0
		standingMult = 1.0 + Standing[hold].GetValue() / 200.0
	EndIf
	Int pay = Math.Floor(BasePay(aiTier) * (1.0 + 0.25 * notoriety[aiIndex]) * standingMult * CHT_PayMult.GetValue())
	If pay > 0
		player.AddItem(Gold001, pay, True)
	EndIf
	String text = "Bounty claimed: " + pay + " gold."
	If notoriety[aiIndex] > 0
		text += "\n(+" + (25 * notoriety[aiIndex]) + "% for an outlaw who had escaped before.)"
	EndIf
	If aiTier == TIER_DREAD
		player.AddItem(CHT_TrophySkull, 1, True)
		text += "\nTrophy: Dread Trophy Skull."
	ElseIf aiTier == TIER_WANTED && Utility.RandomInt(0, 2) == 0
		player.AddItem(CHT_TrophySignet, 1, True)
		text += "\nTrophy: Outlaw's Signet."
	EndIf
	notoriety[aiIndex] = 0
	retired[aiIndex] = True
	CHT_BountiesClaimed.Mod(1)
	If hold >= 0
		Int before = Standing[hold].GetValueInt()
		SetStanding(hold, before + 5 * TierWeight(aiTier))
		text += "\nStanding with " + HoldName(hold) + ": " + before + " -> " + Standing[hold].GetValueInt()
	EndIf
	OpenFlags[aiTier].SetValueInt(0)
	RecountOpen()
	RecountEscaped()
	Debug.MessageBox(text)
	If hold >= 0
		CheckJarlGift(hold)
	EndIf
EndFunction

Function BountyFailed(Int aiIndex, Int aiTier, Location akLocation, Bool abAbandoned)
	If notoriety[aiIndex] < MAX_NOTORIETY
		notoriety[aiIndex] = notoriety[aiIndex] + 1
	EndIf
	Int hold = HoldIndex(akLocation)
	String text
	If abAbandoned
		text = "You tear up the bounty letter. The outlaw slips away."
	Else
		text = "A bounty lapsed. The outlaw slipped away."
	EndIf
	text += "\nTheir notoriety is now " + notoriety[aiIndex] + ". Next time they'll have more blades around them, and a bigger price on their head."
	If hold >= 0
		Int before = Standing[hold].GetValueInt()
		SetStanding(hold, before - 5 * TierWeight(aiTier))
		text += "\nStanding with " + HoldName(hold) + ": " + before + " -> " + Standing[hold].GetValueInt()
	EndIf
	If aiTier == TIER_DREAD
		pendingAvengers += 2 + notoriety[aiIndex] / 2
		If pendingAvengers > MAX_AVENGERS
			pendingAvengers = MAX_AVENGERS
		EndIf
		text += "\n\nThe outlaw's friends know who held the warrant. Watch the roads."
		RegisterForSingleUpdateGameTime(1.0)
	EndIf
	OpenFlags[aiTier].SetValueInt(0)
	RecountOpen()
	RecountEscaped()
	Debug.MessageBox(text)
EndFunction

Float Function BasePay(Int aiTier)
	Int level = Game.GetPlayer().GetLevel()
	If aiTier == TIER_NOTICE
		Return 150.0 + 10.0 * level
	ElseIf aiTier == TIER_WANTED
		Return 350.0 + 15.0 * level
	EndIf
	Return 700.0 + 25.0 * level
EndFunction

; Notice 1, Wanted 2, Dread 3 (standing +5/+10/+15 on success, the same off on failure).
Int Function TierWeight(Int aiTier)
	Return aiTier + 1
EndFunction

; ---------------------------------------------------------------------------
; Avengers (after a lapsed Dread warrant)
; ---------------------------------------------------------------------------

Function TrySendAvengers()
	Actor player = Game.GetPlayer()
	If player.IsInCombat() || player.IsInInterior() || !CanDeliver()
		Return
	EndIf
	Location here = player.GetCurrentLocation()
	If here && IsSafeLocation(here)
		Return
	EndIf
	Int n = pendingAvengers
	pendingAvengers = 0
	Debug.Notification("Blood-sworn avengers have tracked you down!")
	Int i = 0
	While i < n
		Actor a = player.PlaceAtMe(CHT_LCharDreadAvenger) as Actor
		If a
			a.StartCombat(player)
		EndIf
		i += 1
	EndWhile
EndFunction

Bool Function IsSafeLocation(Location akLocation)
	Int i = 0
	While i < SafeLocationTypes.Length
		If akLocation.HasKeyword(SafeLocationTypes[i])
			Return True
		EndIf
		i += 1
	EndWhile
	Return False
EndFunction

; ---------------------------------------------------------------------------
; Holds
; ---------------------------------------------------------------------------

Int Function HoldIndex(Location akLocation)
	If !akLocation
		Return -1
	EndIf
	Int i = 0
	While i < Holds.Length
		If Holds[i] == akLocation || Holds[i].IsChild(akLocation)
			Return i
		EndIf
		i += 1
	EndWhile
	Return -1
EndFunction

Function SetStanding(Int aiHold, Int aiValue)
	If aiValue < 0
		aiValue = 0
	ElseIf aiValue > 100
		aiValue = 100
	EndIf
	Standing[aiHold].SetValueInt(aiValue)
EndFunction

Function CheckJarlGift(Int aiHold)
	If jarlGiftGiven.Length != HOLD_COUNT
		jarlGiftGiven = new Bool[9]
	EndIf
	If !jarlGiftGiven[aiHold] && Standing[aiHold].GetValueInt() >= JARL_GIFT_STANDING
		jarlGiftGiven[aiHold] = True
		Game.GetPlayer().AddItem(Gold001, JARL_GIFT_GOLD, True)
		Debug.MessageBox("A courier brings a sealed purse from the Jarl of " + HoldName(aiHold) + ": " + JARL_GIFT_GOLD + " gold, \"for keeping our roads clean.\"\n\nBounties in " + HoldName(aiHold) + " now pay " + (Standing[aiHold].GetValueInt() / 2) + "% more, rising with your standing.")
	EndIf
EndFunction

String Function HoldName(Int aiHold)
	If aiHold == 0
		Return "Haafingar"
	ElseIf aiHold == 1
		Return "the Reach"
	ElseIf aiHold == 2
		Return "Hjaalmarch"
	ElseIf aiHold == 3
		Return "Whiterun Hold"
	ElseIf aiHold == 4
		Return "Falkreath Hold"
	ElseIf aiHold == 5
		Return "the Pale"
	ElseIf aiHold == 6
		Return "Winterhold"
	ElseIf aiHold == 7
		Return "Eastmarch"
	EndIf
	Return "the Rift"
EndFunction

; ---------------------------------------------------------------------------
; Ledger menus
; ---------------------------------------------------------------------------

Function OpenLedger()
	If CHT_Registered.GetValueInt() == 0
		Return
	EndIf
	SyncOpen()
	Bool keepOpen = True
	While keepOpen
		Int choice = CHT_MsgLedgerMenu.Show(CHT_BountiesClaimed.GetValue(), CHT_EscapedOutlaws.GetValue(), CHT_OpenCount.GetValue())
		If choice == 0
			keepOpen = !RequestMenu()
		ElseIf choice == 1
			AbandonMenu()
		ElseIf choice == 2
			Debug.MessageBox(StandingText())
			keepOpen = False
		Else
			keepOpen = False
		EndIf
	EndWhile
EndFunction

; Returns True if a bounty was started (closes the ledger).
Bool Function RequestMenu()
	Int choice = CHT_MsgRequestMenu.Show()
	If choice < 0 || choice > 2
		Return False
	EndIf
	Int level = Game.GetPlayer().GetLevel()
	If choice == TIER_WANTED && level < CHT_WantedMinLevel.GetValueInt()
		Debug.Notification("The courts won't hand Wanted posters to a hunter below level " + CHT_WantedMinLevel.GetValueInt() + ".")
		Return False
	ElseIf choice == TIER_DREAD && level < CHT_DreadMinLevel.GetValueInt()
		Debug.Notification("The courts won't hand Dread warrants to a hunter below level " + CHT_DreadMinLevel.GetValueInt() + ".")
		Return False
	EndIf
	If StartBounty(choice)
		Return True
	EndIf
	CHT_MsgNoBounty.Show()
	Return False
EndFunction

Function AbandonMenu()
	Int choice = CHT_MsgAbandonMenu.Show()
	If choice < 0 || choice > 2
		Return
	EndIf
	CHT_BountyScript active = ActiveBounty(choice)
	If active
		active.Abandon()
	Else
		SyncOpen()
	EndIf
EndFunction

CHT_BountyScript Function ActiveBounty(Int aiTier)
	Int first = TierStart(aiTier)
	Int i = 0
	While i < TierSize(aiTier)
		If Bounties[first + i].IsRunning()
			Return Bounties[first + i] as CHT_BountyScript
		EndIf
		i += 1
	EndWhile
	Return None
EndFunction

Function SyncOpen()
	Int t = 0
	While t < 3
		If ActiveBounty(t)
			OpenFlags[t].SetValueInt(1)
		Else
			OpenFlags[t].SetValueInt(0)
		EndIf
		t += 1
	EndWhile
	RecountOpen()
EndFunction

Function RecountOpen()
	CHT_OpenCount.SetValueInt(OpenFlags[0].GetValueInt() + OpenFlags[1].GetValueInt() + OpenFlags[2].GetValueInt())
EndFunction

Function RecountEscaped()
	Int n = 0
	Int i = 0
	While i < OUTLAW_COUNT
		If notoriety[i] > 0 && !retired[i]
			n += 1
		EndIf
		i += 1
	EndWhile
	CHT_EscapedOutlaws.SetValueInt(n)
EndFunction

String Function StandingText()
	String text = "STANDING WITH THE HOLDS\n"
	Int i = 0
	While i < HOLD_COUNT
		text += "\n" + HoldName(i) + ": " + Standing[i].GetValueInt()
		i += 1
	EndWhile
	text += "\n\nBounties pay up to 50% more where your standing is high. At " + JARL_GIFT_STANDING + ", the jarl sends a gift."
	Return text
EndFunction
