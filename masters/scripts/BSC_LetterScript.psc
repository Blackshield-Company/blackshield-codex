Scriptname BSC_LetterScript extends ObjectReference
{Blackshield Company - recruitment letter. Reading it offers the contract.}

BSC_CompanyScript Property Company Auto

Event OnRead()
	; Utility.Wait does not advance while menus are open, so the offer appears
	; right after the player closes the letter and inventory.
	Utility.Wait(0.1)
	Company.OnLetterRead()
EndEvent
