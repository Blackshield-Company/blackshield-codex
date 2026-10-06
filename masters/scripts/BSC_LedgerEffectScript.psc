Scriptname BSC_LedgerEffectScript extends ActiveMagicEffect
{Blackshield Company - "Company Ledger" lesser power. Opens the ledger menu.}

BSC_CompanyScript Property Company Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akCaster == Game.GetPlayer()
		Company.OpenLedger()
	EndIf
EndEvent
