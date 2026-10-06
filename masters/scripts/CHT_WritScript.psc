Scriptname CHT_WritScript extends ObjectReference
{Contract Hunter - the Hunter's Writ. Reading it offers registration, and
opens the ledger afterwards.}

CHT_HunterScript Property Hunter Auto

Event OnRead()
	; Utility.Wait does not advance while menus are open, so the offer appears
	; right after the player closes the letter and inventory.
	Utility.Wait(0.1)
	Hunter.OnWritRead()
EndEvent
