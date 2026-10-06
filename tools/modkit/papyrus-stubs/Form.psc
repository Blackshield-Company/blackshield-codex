Scriptname Form Hidden
{Clean-room declaration stub (validation only). Build against the game's own sources for releases if you prefer: see tools/modkit/README.md.}
Int Function GetFormID() native
Bool Function PlayerKnows() native
Function RegisterForSingleUpdate(Float afInterval) native
Function RegisterForUpdate(Float afInterval) native
Function UnregisterForUpdate() native
Function RegisterForSingleUpdateGameTime(Float afInterval) native
Function UnregisterForUpdateGameTime() native
Function RegisterForSleep() native
Function UnregisterForSleep() native
Event OnInit()
EndEvent
Event OnUpdate()
EndEvent
Event OnUpdateGameTime()
EndEvent
Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
EndEvent
Event OnSleepStop(Bool abInterrupted)
EndEvent
Bool Function HasKeyword(Keyword akKeyword) native
