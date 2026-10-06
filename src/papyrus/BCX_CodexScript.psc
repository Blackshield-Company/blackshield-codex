Scriptname BCX_CodexScript extends Quest
{Blackshield Codex - ties the five first-wave mods together. It only reads their
globals and calls two of their public functions (BSC_CompanyScript.AddRenown and
CHT_HunterScript.BasePay); it never changes their records. A light poll (every
BCX_PollSeconds of real time, not in menus) notices when a Blackshield contract or
a Contract Hunter bounty is finished. Anything missing or not in use is skipped.}

; --- Own settings and stats ---------------------------------------------------
GlobalVariable Property BCX_Enabled Auto
GlobalVariable Property BCX_PollSeconds Auto
GlobalVariable Property BCX_RenownPerOath Auto
GlobalVariable Property BCX_BlessingFavor Auto
GlobalVariable Property BCX_BoonFavor Auto
GlobalVariable Property BCX_BlessingPayPct Auto
GlobalVariable Property BCX_BoonPayPct Auto
GlobalVariable Property BCX_RenownAwarded Auto
GlobalVariable Property BCX_GoldAwarded Auto
Message Property BCX_MsgOathRenown Auto
Message Property BCX_MsgPatronage Auto
MiscObject Property Gold001 Auto

; --- Blackshield Company (read; AddRenown is called) --------------------------
Quest Property BSC_CompanyQuest Auto
GlobalVariable Property BSC_ContractActive Auto
GlobalVariable Property BSC_ContractsDone Auto

; --- Steel Oath (read only) ---------------------------------------------------
GlobalVariable[] Property OathActive Auto
{SOT_ActiveSteel, SOT_ActiveShield, SOT_ActiveIron, SOT_ActiveEndurance, SOT_ActiveClose}

; --- Contract Hunter (read; BasePay is called) --------------------------------
Quest Property CHT_HunterQuest Auto
GlobalVariable Property CHT_BountiesClaimed Auto
GlobalVariable Property CHT_PayMult Auto
GlobalVariable[] Property BountyOpen Auto
{CHT_OpenNotice, CHT_OpenWanted, CHT_OpenDread (Contract Hunter's tier order 0, 1, 2)}

; --- Bounties of Oblivion (read only) -----------------------------------------
GlobalVariable[] Property PrinceFavor Auto
{BOO_FavorDagon ... BOO_FavorVaermina, 0 to 100 each}

Bool started
Int lastContractsDone
Int lastContractActive
Bool contractTracked
Int oathMaskAtStart
Int lastClaimed
Int openMask

Event OnInit()
	If started
		Return
	EndIf
	started = True
	Snapshot()
	Debug.Trace("BCX_ init: contracts=" + lastContractsDone + " claimed=" + lastClaimed)
	ScheduleNext()
EndEvent

; Called by BCX_PlayerAliasScript on every save load.
Function GameLoaded()
	If !started
		Return
	EndIf
	Debug.Trace("BCX_ loaded: company=" + (BSC_CompanyQuest as BSC_CompanyScript != None) + " hunter=" + (CHT_HunterQuest as CHT_HunterScript != None) + " oaths=" + OathActive.Length + " favor=" + PrinceFavor.Length + " bounty tiers=" + BountyOpen.Length)
	ScheduleNext()
EndFunction

Event OnUpdate()
	If BCX_Enabled != None && BCX_Enabled.GetValueInt() == 0
		Snapshot() ; nothing is awarded for what happened while switched off
	Else
		PollCompany()
		PollHunter()
	EndIf
	ScheduleNext()
EndEvent

Function ScheduleNext()
	Float seconds = 5.0
	If BCX_PollSeconds != None && BCX_PollSeconds.GetValue() >= 1.0
		seconds = BCX_PollSeconds.GetValue()
	EndIf
	RegisterForSingleUpdate(seconds)
EndFunction

Function Snapshot()
	If BSC_ContractsDone != None && BSC_ContractActive != None
		lastContractsDone = BSC_ContractsDone.GetValueInt()
		lastContractActive = BSC_ContractActive.GetValueInt()
	EndIf
	contractTracked = False ; a contract already running has no known starting oaths
	If CHT_BountiesClaimed != None
		lastClaimed = CHT_BountiesClaimed.GetValueInt()
	EndIf
	openMask = OpenBountyMask()
EndFunction

; ---------------------------------------------------------------------------
; Steel Oath x Blackshield Company: oaths kept through a contract add renown
; ---------------------------------------------------------------------------

Function PollCompany()
	If BSC_ContractsDone == None || BSC_ContractActive == None
		Return
	EndIf
	Int done = BSC_ContractsDone.GetValueInt()
	If done < lastContractsDone
		lastContractsDone = done
	ElseIf done > lastContractsDone
		Int mask = ActiveOathMask()
		If contractTracked
			mask = CommonBits(mask, oathMaskAtStart)
		EndIf
		lastContractsDone = done
		contractTracked = False
		Int kept = CountBits(mask)
		Debug.Trace("BCX_ contract completed: oaths kept=" + kept)
		If kept > 0
			AwardRenown(kept)
		EndIf
	EndIf
	Int active = BSC_ContractActive.GetValueInt()
	If active != 0 && lastContractActive == 0
		contractTracked = True
		oathMaskAtStart = ActiveOathMask()
		Debug.Trace("BCX_ contract taken: oath mask=" + oathMaskAtStart)
	ElseIf active == 0
		contractTracked = False
	EndIf
	lastContractActive = active
EndFunction

Function AwardRenown(Int aiKept)
	BSC_CompanyScript company = BSC_CompanyQuest as BSC_CompanyScript
	If company == None
		Debug.Trace("BCX_ Blackshield Company quest not available, renown skipped")
		Return
	EndIf
	Int amount = aiKept * BCX_RenownPerOath.GetValueInt()
	If amount <= 0
		Return
	EndIf
	Utility.Wait(2.0) ; let the company finish its own payout first
	company.AddRenown(amount)
	BCX_RenownAwarded.Mod(amount)
	BCX_MsgOathRenown.Show(aiKept, amount)
	Debug.Trace("BCX_ renown +" + amount)
EndFunction

; Bit i set = oath i active (SOT_Active* == 1).
Int Function ActiveOathMask()
	Int mask = 0
	Int bit = 1
	Int i = 0
	While i < OathActive.Length
		If OathActive[i] != None && OathActive[i].GetValueInt() != 0
			mask += bit
		EndIf
		bit *= 2
		i += 1
	EndWhile
	Return mask
EndFunction

Int Function CommonBits(Int a, Int b)
	Int result = 0
	Int bit = 1
	While a > 0 && b > 0
		If a % 2 == 1 && b % 2 == 1
			result += bit
		EndIf
		a /= 2
		b /= 2
		bit *= 2
	EndWhile
	Return result
EndFunction

Int Function CountBits(Int a)
	Int n = 0
	While a > 0
		n += a % 2
		a /= 2
	EndWhile
	Return n
EndFunction

; ---------------------------------------------------------------------------
; Bounties of Oblivion x Contract Hunter: Daedric favor sweetens bounties
; ---------------------------------------------------------------------------

Function PollHunter()
	If CHT_BountiesClaimed == None
		Return
	EndIf
	Int claimed = CHT_BountiesClaimed.GetValueInt()
	If claimed < lastClaimed
		lastClaimed = claimed
	ElseIf claimed > lastClaimed
		Utility.Wait(1.0) ; Contract Hunter clears the tier's open flag just after counting the claim
		Int tier = ClosedTier(openMask, OpenBountyMask())
		Int extra = claimed - lastClaimed - 1
		lastClaimed = claimed
		AwardPatronage(tier)
		While extra > 0 ; more than one claim between polls (unlikely): count the rest as Notices
			AwardPatronage(0)
			extra -= 1
		EndWhile
	EndIf
	openMask = OpenBountyMask()
EndFunction

Function AwardPatronage(Int aiTier)
	Int favor = HighestFavor()
	Int pct = 0
	If favor >= BCX_BoonFavor.GetValueInt()
		pct = BCX_BoonPayPct.GetValueInt()
	ElseIf favor >= BCX_BlessingFavor.GetValueInt()
		pct = BCX_BlessingPayPct.GetValueInt()
	EndIf
	Debug.Trace("BCX_ bounty claimed: tier=" + aiTier + " highest favor=" + favor + " bonus pct=" + pct)
	If pct <= 0
		Return
	EndIf
	CHT_HunterScript hunter = CHT_HunterQuest as CHT_HunterScript
	If hunter == None
		Debug.Trace("BCX_ Contract Hunter quest not available, patronage skipped")
		Return
	EndIf
	Float mult = 1.0
	If CHT_PayMult != None
		mult = CHT_PayMult.GetValue()
	EndIf
	Int gold = Math.Floor(hunter.BasePay(aiTier) * mult * pct / 100.0)
	If gold > 0
		Game.GetPlayer().AddItem(Gold001, gold, True)
		BCX_GoldAwarded.Mod(gold)
		BCX_MsgPatronage.Show(gold, favor)
		Debug.Trace("BCX_ patronage +" + gold + " gold")
	EndIf
EndFunction

Int Function HighestFavor()
	Int best = 0
	Int i = 0
	While i < PrinceFavor.Length
		If PrinceFavor[i] != None && PrinceFavor[i].GetValueInt() > best
			best = PrinceFavor[i].GetValueInt()
		EndIf
		i += 1
	EndWhile
	Return best
EndFunction

Int Function OpenBountyMask()
	Int mask = 0
	Int bit = 1
	Int i = 0
	While i < BountyOpen.Length
		If BountyOpen[i] != None && BountyOpen[i].GetValueInt() != 0
			mask += bit
		EndIf
		bit *= 2
		i += 1
	EndWhile
	Return mask
EndFunction

; Highest tier that was open before and is closed now; Notice (0) if none is found.
Int Function ClosedTier(Int aiBefore, Int aiNow)
	Int tier = 2
	Int bit = 4
	While tier >= 0
		If (aiBefore / bit) % 2 == 1 && (aiNow / bit) % 2 == 0
			Return tier
		EndIf
		tier -= 1
		bit /= 2
	EndWhile
	Return 0
EndFunction
