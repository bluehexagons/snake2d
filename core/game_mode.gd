class_name GameMode
extends RefCounted

## Stable game-mode identities shared by the model, menus, and persistence.

enum Value {
	CLASSIC,
	PITFALL,
	OBSTACLES,
}

const ALL: Array[Value] = [Value.CLASSIC, Value.PITFALL, Value.OBSTACLES]

static func key(mode: Value) -> String:
	match mode:
		Value.PITFALL:
			return "pitfall"
		Value.OBSTACLES:
			return "obstacles"
		_:
			return "classic"

static func display_name(mode: Value) -> String:
	match mode:
		Value.PITFALL:
			return "Pitfall"
		Value.OBSTACLES:
			return "Obstacles"
		_:
			return "Classic"

static func from_key(value: String) -> Value:
	match value.to_lower():
		"pitfall":
			return Value.PITFALL
		"obstacles":
			return Value.OBSTACLES
		_:
			return Value.CLASSIC
