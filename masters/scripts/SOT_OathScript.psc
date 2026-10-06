Scriptname SOT_OathScript extends Quest
{Steel Oath - controller. Grants the "Swear an Oath" power after Helgen,
runs the oath menus, tracks how long each oath has been kept, grows its
blessing, and applies the oathbreaker penalty and cooldowns.

Timing is event-driven: one real-time poll while waiting to grant the
power, a 3-second single update after the shield leaves the player's arm
(Oath of the Shield), and a single game-time update scheduled for the next
thing that changes (a blessing tier, a cooldown or the penalty ending).}

GlobalVariable Property SOT_PowerGranted Auto
GlobalVariable[] Property ActiveFlags Auto
GlobalVariable[] Property AvailableFlags Auto
GlobalVariable Property SOT_ActiveCount Auto
GlobalVariable Property SOT_CanSwear Auto
GlobalVariable Property SOT_MaxOaths Auto
GlobalVariable Property SOT_OathsBroken Auto
GlobalVariable Property SOT_LongestOathDays Auto
GlobalVariable Property SOT_Tier2Days Auto
GlobalVariable Property SOT_Tier3Days Auto
GlobalVariable Property SOT_CooldownHours Auto
GlobalVariable Property SOT_PenaltyHours Auto

Spell[] Property Tier1 Auto
Spell[] Property Tier2 Auto
Spell[] Property Tier3 Auto
Spell Property SOT_AbOathbreaker Auto
Spell Property SOT_PowerOath Auto

Quest Property MQ101 Auto
Race Property WerewolfBeastRace Auto
Keyword Property ArmorLight Auto
Keyword Property ArmorShield Auto
Keyword Property WeapTypeBow Auto

Message Property SOT_MsgIntro Auto
Message Property SOT_MsgMainMenu Auto
Message Property SOT_MsgSwearMenu Auto
Message Property SOT_MsgRenounceMenu Auto
Message[] Property ConfirmMessages Auto

Int Property OATH_STEEL = 0 AutoReadOnly
Int Property OATH_SHIELD = 1 AutoReadOnly
Int Property OATH_IRON = 2 AutoReadOnly
Int Property OATH_ENDURANCE = 3 AutoReadOnly
Int Property OATH_CLOSE = 4 AutoReadOnly
Int Property OATH_COUNT = 5 AutoReadOnly
Float Property SHIELD_GRACE_SECONDS = 3.0 AutoReadOnly

Bool[] active
Int[] tier
Float[] swornAt
Float[] cooldownUntil
Float breakerUntil = 0.0
Int activeCount = 0
Bool shieldCheckPending = False

; ---------------------------------------------------------------------------
; Startup: grant the power once the player is past Helgen
; ---------------------------------------------------------------------------

Event OnInit()
	InitArrays()
	RegisterForSingleUpdate(10.0)
EndEvent

Function InitArrays()
	If active.Length != OATH_COUNT
		active = new Bool[5]
		tier = new Int[5]
		swornAt = new Float[5]
		cooldownUntil = new Float[5]
	EndIf
EndFunction

Event OnUpdate()
	If SOT_PowerGranted.GetValueInt() == 0
		If CanGrant()
			GrantPower()
		Else
			RegisterForSingleUpdate(30.0)
		EndIf
		Return
	EndIf
	If shieldCheckPending
		shieldCheckPending = False
		CheckShield()
	EndIf
EndEvent

Bool Function CanGrant()
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

Function GrantPower()
	SOT_PowerGranted.SetValueInt(1)
	Game.GetPlayer().AddSpell(SOT_PowerOath, False)
	SOT_MsgIntro.Show()
EndFunction

; ---------------------------------------------------------------------------
; Menus
; ---------------------------------------------------------------------------

Function OpenMenu()
	InitArrays()
	RefreshFlags()
	Bool keepOpen = True
	While keepOpen
		Int choice = SOT_MsgMainMenu.Show(SOT_ActiveCount.GetValue(), SOT_MaxOaths.GetValue(), SOT_OathsBroken.GetValue(), SOT_LongestOathDays.GetValue())
		If choice == 0
			keepOpen = !SwearMenu()
		ElseIf choice == 1
			keepOpen = !RenounceMenu()
		ElseIf choice == 2
			Debug.MessageBox(StatusText())
			keepOpen = False
		Else
			keepOpen = False
		EndIf
	EndWhile
EndFunction

; Returns True when the menu should close.
Bool Function SwearMenu()
	Int choice = SOT_MsgSwearMenu.Show()
	If choice < 0 || choice >= OATH_COUNT
		Return False
	EndIf
	If ConfirmMessages[choice].Show(SOT_Tier2Days.GetValue(), SOT_Tier3Days.GetValue()) != 0
		Return False
	EndIf
	Swear(choice)
	Return True
EndFunction

; Returns True when the menu should close.
Bool Function RenounceMenu()
	Int choice = SOT_MsgRenounceMenu.Show(SOT_CooldownHours.GetValue())
	If choice < 0 || choice >= OATH_COUNT
		Return False
	EndIf
	Renounce(choice)
	Return True
EndFunction

String Function StatusText()
	Float now = Utility.GetCurrentGameTime()
	String text = "YOUR OATHS\n"
	Bool any = False
	Int i = 0
	While i < OATH_COUNT
		If active[i]
			any = True
			text += "\n" + OathName(i) + ": " + TierName(tier[i]) + ", kept " + DurationText((now - swornAt[i]) * 24.0)
			If tier[i] < 2
				text += ". Next blessing in " + DurationText((swornAt[i] + DaysForTier(tier[i] + 1) - now) * 24.0)
			EndIf
			text += "."
		ElseIf cooldownUntil[i] > now
			any = True
			text += "\n" + OathName(i) + ": can be sworn again in " + DurationText((cooldownUntil[i] - now) * 24.0) + "."
		EndIf
		i += 1
	EndWhile
	If breakerUntil > now
		any = True
		text += "\n\nOathbreaker: " + DurationText((breakerUntil - now) * 24.0) + " left."
	EndIf
	If !any
		text += "\nYou hold no oaths."
	EndIf
	Return text
EndFunction

String Function DurationText(Float afHours)
	If afHours < 0.0
		afHours = 0.0
	EndIf
	Int total = Math.Ceiling(afHours)
	Int days = total / 24
	Int hours = total - days * 24
	If days > 0
		Return days + "d " + hours + "h"
	EndIf
	Return hours + "h"
EndFunction

; ---------------------------------------------------------------------------
; Swearing, breaking, renouncing
; ---------------------------------------------------------------------------

Function Swear(Int i)
	Actor player = Game.GetPlayer()
	If active[i]
		Return
	EndIf
	If activeCount >= SOT_MaxOaths.GetValueInt()
		Debug.MessageBox("You already hold as many oaths as you can keep.")
		Return
	EndIf
	If i == OATH_SHIELD && !player.GetEquippedShield()
		Debug.MessageBox("You need a shield on your arm to swear the Oath of the Shield.")
		Return
	ElseIf i == OATH_IRON && player.WornHasKeyword(ArmorLight)
		Debug.MessageBox("Take off your light armor (light shields included) before you swear the Oath of Iron.")
		Return
	ElseIf i == OATH_CLOSE && HoldsBow(player)
		Debug.MessageBox("Put away your bow before you swear the Oath of Close Quarters.")
		Return
	EndIf
	active[i] = True
	tier[i] = 0
	swornAt[i] = Utility.GetCurrentGameTime()
	player.AddSpell(Tier1[i], False)
	RefreshFlags()
	ScheduleTick()
	Debug.Notification("You swear the " + OathName(i) + ".")
EndFunction

Function BreakOath(Int i, String asReason)
	If !IsActive(i)
		Return
	EndIf
	EndOath(i)
	Float now = Utility.GetCurrentGameTime()
	cooldownUntil[i] = now + SOT_CooldownHours.GetValue() / 24.0
	Float penaltyEnd = now + SOT_PenaltyHours.GetValue() / 24.0
	If penaltyEnd > breakerUntil
		breakerUntil = penaltyEnd
	EndIf
	Actor player = Game.GetPlayer()
	If !player.HasSpell(SOT_AbOathbreaker)
		player.AddSpell(SOT_AbOathbreaker, False)
	EndIf
	SOT_OathsBroken.Mod(1)
	RefreshFlags()
	ScheduleTick()
	Debug.Notification("Oath broken: " + asReason)
	Debug.Notification("You are an oathbreaker. The " + OathName(i) + " is lost.")
EndFunction

Function Renounce(Int i)
	If !IsActive(i)
		Return
	EndIf
	EndOath(i)
	cooldownUntil[i] = Utility.GetCurrentGameTime() + SOT_CooldownHours.GetValue() / 24.0
	RefreshFlags()
	ScheduleTick()
	Debug.Notification("You renounce the " + OathName(i) + ".")
EndFunction

; Removes the oath and its blessing, and records how long it was kept.
Function EndOath(Int i)
	Actor player = Game.GetPlayer()
	player.RemoveSpell(Tier1[i])
	player.RemoveSpell(Tier2[i])
	player.RemoveSpell(Tier3[i])
	UpdateLongest(Utility.GetCurrentGameTime() - swornAt[i])
	active[i] = False
	tier[i] = 0
EndFunction

Function UpdateLongest(Float afDays)
	Int days = Math.Floor(afDays)
	If days > SOT_LongestOathDays.GetValueInt()
		SOT_LongestOathDays.SetValueInt(days)
	EndIf
EndFunction

; ---------------------------------------------------------------------------
; Game-time schedule: blessing tiers, cooldowns, penalty
; ---------------------------------------------------------------------------

Event OnUpdateGameTime()
	Float now = Utility.GetCurrentGameTime()
	Actor player = Game.GetPlayer()
	Int i = 0
	While i < OATH_COUNT
		If active[i]
			Float kept = now - swornAt[i]
			Int want = 0
			If kept >= SOT_Tier3Days.GetValue()
				want = 2
			ElseIf kept >= SOT_Tier2Days.GetValue()
				want = 1
			EndIf
			If want > tier[i]
				player.RemoveSpell(TierSpell(tier[i], i))
				player.AddSpell(TierSpell(want, i), False)
				tier[i] = want
				Debug.Notification("Your " + OathName(i) + " holds. The blessing grows: " + TierName(want) + ".")
			EndIf
			UpdateLongest(kept)
		EndIf
		i += 1
	EndWhile
	If breakerUntil > 0.0 && now >= breakerUntil
		breakerUntil = 0.0
		player.RemoveSpell(SOT_AbOathbreaker)
		Debug.Notification("The oathbreaker's shame fades.")
	EndIf
	RefreshFlags()
	ScheduleTick()
EndEvent

; Registers one game-time update for the next moment something changes.
Function ScheduleTick()
	Float now = Utility.GetCurrentGameTime()
	Float nextAt = 0.0
	Int i = 0
	While i < OATH_COUNT
		Float t = 0.0
		If active[i]
			If tier[i] < 2
				t = swornAt[i] + DaysForTier(tier[i] + 1)
			EndIf
		ElseIf cooldownUntil[i] > now
			t = cooldownUntil[i]
		EndIf
		If t > 0.0 && (nextAt == 0.0 || t < nextAt)
			nextAt = t
		EndIf
		i += 1
	EndWhile
	If breakerUntil > 0.0 && (nextAt == 0.0 || breakerUntil < nextAt)
		nextAt = breakerUntil
	EndIf
	If nextAt > 0.0
		Float hours = (nextAt - now) * 24.0
		If hours < 0.05
			hours = 0.05
		EndIf
		RegisterForSingleUpdateGameTime(hours)
	EndIf
EndFunction

Function RefreshFlags()
	Float now = Utility.GetCurrentGameTime()
	Int count = 0
	Bool anyAvailable = False
	Int i = 0
	While i < OATH_COUNT
		If active[i]
			count += 1
			ActiveFlags[i].SetValueInt(1)
			AvailableFlags[i].SetValueInt(0)
		Else
			ActiveFlags[i].SetValueInt(0)
			If cooldownUntil[i] <= now
				AvailableFlags[i].SetValueInt(1)
				anyAvailable = True
			Else
				AvailableFlags[i].SetValueInt(0)
			EndIf
		EndIf
		i += 1
	EndWhile
	activeCount = count
	SOT_ActiveCount.SetValueInt(count)
	If anyAvailable && count < SOT_MaxOaths.GetValueInt()
		SOT_CanSwear.SetValueInt(1)
	Else
		SOT_CanSwear.SetValueInt(0)
	EndIf
EndFunction

; ---------------------------------------------------------------------------
; Detection (called by SOT_PlayerAliasScript)
; ---------------------------------------------------------------------------

Function OnPlayerSpellCast(Form akSpell)
	If activeCount == 0 || !IsActive(OATH_STEEL)
		Return
	EndIf
	If akSpell as Scroll
		BreakOath(OATH_STEEL, "you read a scroll.")
		Return
	EndIf
	Spell cast = akSpell as Spell
	If cast
		; Only spells cast from the hands count. Powers and shouts use the
		; voice slot, staves cast enchantments, and potions are not spells.
		Actor player = Game.GetPlayer()
		If cast == player.GetEquippedSpell(0) || cast == player.GetEquippedSpell(1)
			BreakOath(OATH_STEEL, "you cast a spell.")
		EndIf
	EndIf
EndFunction

Function OnPlayerEquipped(Form akBaseObject)
	If activeCount == 0 || !akBaseObject
		Return
	EndIf
	If IsActive(OATH_STEEL) && (akBaseObject as Scroll)
		BreakOath(OATH_STEEL, "you readied a scroll.")
	EndIf
	If IsActive(OATH_IRON) && (akBaseObject as Armor) && akBaseObject.HasKeyword(ArmorLight)
		BreakOath(OATH_IRON, "you put on light armor.")
	EndIf
	If IsActive(OATH_ENDURANCE) && (akBaseObject as Potion) && Game.GetPlayer().IsInCombat()
		BreakOath(OATH_ENDURANCE, "you took a potion, food or poison in combat.")
	EndIf
	If IsActive(OATH_CLOSE) && (akBaseObject as Weapon) && akBaseObject.HasKeyword(WeapTypeBow)
		BreakOath(OATH_CLOSE, "you took up a bow.")
	EndIf
EndFunction

Function OnPlayerUnequipped(Form akBaseObject)
	If activeCount == 0 || !akBaseObject
		Return
	EndIf
	If IsActive(OATH_SHIELD) && (akBaseObject as Armor) && akBaseObject.HasKeyword(ArmorShield)
		; Give the player a moment to swap shields before judging.
		shieldCheckPending = True
		RegisterForSingleUpdate(SHIELD_GRACE_SECONDS)
	EndIf
EndFunction

Function CheckShield()
	If !IsActive(OATH_SHIELD)
		Return
	EndIf
	Actor player = Game.GetPlayer()
	If player.GetRace() == WerewolfBeastRace
		Return
	EndIf
	If !player.GetEquippedShield()
		BreakOath(OATH_SHIELD, "your shield left your arm.")
	EndIf
EndFunction

; ---------------------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------------------

Bool Function IsActive(Int i)
	Return active.Length == OATH_COUNT && active[i]
EndFunction

Bool Function HoldsBow(Actor akActor)
	Weapon w = akActor.GetEquippedWeapon(False)
	Return w && w.HasKeyword(WeapTypeBow)
EndFunction

Spell Function TierSpell(Int aiTier, Int i)
	If aiTier == 0
		Return Tier1[i]
	ElseIf aiTier == 1
		Return Tier2[i]
	EndIf
	Return Tier3[i]
EndFunction

Float Function DaysForTier(Int aiTier)
	If aiTier == 1
		Return SOT_Tier2Days.GetValue()
	EndIf
	Return SOT_Tier3Days.GetValue()
EndFunction

String Function TierName(Int aiTier)
	If aiTier == 0
		Return "Sworn"
	ElseIf aiTier == 1
		Return "Steadfast"
	EndIf
	Return "Unbroken"
EndFunction

String Function OathName(Int i)
	If i == OATH_STEEL
		Return "Oath of Steel"
	ElseIf i == OATH_SHIELD
		Return "Oath of the Shield"
	ElseIf i == OATH_IRON
		Return "Oath of Iron"
	ElseIf i == OATH_ENDURANCE
		Return "Oath of Endurance"
	EndIf
	Return "Oath of Close Quarters"
EndFunction
