Scriptname BCX_PlayerAliasScript extends ReferenceAlias
{Blackshield Codex - restarts the poll and logs which mods are linked on every save load.}

Event OnPlayerLoadGame()
	(GetOwningQuest() as BCX_CodexScript).GameLoaded()
EndEvent
