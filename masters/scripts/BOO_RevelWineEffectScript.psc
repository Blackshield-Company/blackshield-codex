Scriptname BOO_RevelWineEffectScript extends ActiveMagicEffect
{Daedric Ledger: Bounties of Oblivion - Sanguine's Revel Wine. Reports each
drink to the Ledger so Sanguine's task can count it.}

BOO_LedgerScript Property Ledger Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akTarget == Game.GetPlayer()
		Ledger.OnRevelDrink()
	EndIf
EndEvent
