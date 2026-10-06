Scriptname BSC_LedgerBookScript extends ObjectReference
{Blackshield Company - the company ledger book. Reading it opens the ledger menu.}

BSC_CompanyScript Property Company Auto

Event OnRead()
	Utility.Wait(0.1)
	Company.OpenLedger()
EndEvent
