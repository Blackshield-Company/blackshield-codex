Scriptname Quest extends Form Hidden
Function CompleteAllObjectives() native
Function CompleteQuest() native
Function FailAllObjectives() native
Int Function GetStage() native
Bool Function GetStageDone(Int aiStage) native
Bool Function IsCompleted() native
Bool Function IsObjectiveCompleted(Int aiObjective) native
Bool Function IsObjectiveDisplayed(Int aiObjective) native
Bool Function IsRunning() native
Bool Function IsStarting() native
Bool Function IsStopping() native
Bool Function IsStopped() native
Function Reset() native
Function SetActive(Bool abActive = True) native
Bool Function SetCurrentStageID(Int aiStageID) native
Function SetObjectiveCompleted(Int aiObjective, Bool abCompleted = True) native
Function SetObjectiveDisplayed(Int aiObjective, Bool abDisplayed = True, Bool abForce = False) native
Function SetObjectiveFailed(Int aiObjective, Bool abFailed = True) native
Bool Function Start() native
Function Stop() native
Bool Function UpdateCurrentInstanceGlobal(GlobalVariable aUpdateGlobal) native
Bool Function SetStage(Int aiStage)
	Return SetCurrentStageID(aiStage)
EndFunction
