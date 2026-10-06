Scriptname SOT_PowerEffectScript extends ActiveMagicEffect
{Steel Oath - "Swear an Oath" lesser power.}

SOT_OathScript Property Oaths Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akCaster == Game.GetPlayer()
		Oaths.OpenMenu()
	EndIf
EndEvent
