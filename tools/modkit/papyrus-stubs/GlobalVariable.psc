Scriptname GlobalVariable extends Form Hidden
Float Function GetValue() native
Function SetValue(Float afNewValue) native
Int Function GetValueInt()
	Return GetValue() as Int
EndFunction
Function SetValueInt(Int aiNewValue)
	SetValue(aiNewValue as Float)
EndFunction
Float Function Mod(Float afHowMuch)
	SetValue(GetValue() + afHowMuch)
	Return GetValue()
EndFunction
