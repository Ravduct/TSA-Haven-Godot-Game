extends Node

signal flagChanged(flagName: String, value: bool)

var flags: Dictionary = {}

func setFlag(flagName: String, value: bool = true) -> void:
	if flags.get(flagName, false) == value:
		return
	flags[flagName] = value
	flagChanged.emit(flagName, value)

func getFlag(flagName: String) -> bool:
	return flags.get(flagName, false)

func clearFlags() -> void:
	flags.clear()
