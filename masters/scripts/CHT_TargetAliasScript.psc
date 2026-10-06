Scriptname CHT_TargetAliasScript extends ReferenceAlias
{Contract Hunter - attached to each bounty's Target alias. Reports the
outlaw's death and the moment the player gets close (3D loaded).}

Event OnDeath(Actor akKiller)
	(GetOwningQuest() as CHT_BountyScript).TargetDied()
EndEvent

Event OnLoad()
	(GetOwningQuest() as CHT_BountyScript).TargetLoaded()
EndEvent
