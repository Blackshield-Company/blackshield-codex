Scriptname BOO_LedgerBookScript extends ObjectReference
{Daedric Ledger: Bounties of Oblivion - the Ledger book. Reading it offers the
pact the first time, and opens the Ledger menu afterwards.}

BOO_LedgerScript Property Ledger Auto

Event OnRead()
	; Utility.Wait does not advance while menus are open, so the menu appears
	; right after the player closes the book and inventory.
	Utility.Wait(0.1)
	Ledger.OnLedgerRead()
EndEvent
