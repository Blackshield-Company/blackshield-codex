Scriptname BOO_LedgerEffectScript extends ActiveMagicEffect
{Daedric Ledger: Bounties of Oblivion - "Consult the Daedric Ledger" lesser power.}

BOO_LedgerScript Property Ledger Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akCaster == Game.GetPlayer()
		Ledger.OpenLedger()
	EndIf
EndEvent
