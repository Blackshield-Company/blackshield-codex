Scriptname CHT_LedgerEffectScript extends ActiveMagicEffect
{Contract Hunter - "Hunter's Ledger" lesser power.}

CHT_HunterScript Property Hunter Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akCaster == Game.GetPlayer()
		Hunter.OpenLedger()
	EndIf
EndEvent
