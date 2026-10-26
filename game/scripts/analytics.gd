extends Node
## Firebase Analytics facade (Android). Retention, sessions and installs are
## tracked by Firebase automatically; these are the game-specific events.
## On web/desktop events are only printed.

var _plugin: Object = null


func _ready() -> void:
	if Engine.has_singleton("GodotAds"):
		var p: Object = Engine.get_singleton("GodotAds")
		if p.has_method("logEvent"):
			_plugin = p


func event(name: String, params := {}) -> void:
	if _plugin:
		_plugin.logEvent(name, params)
	elif OS.is_debug_build():
		print("[Analytics] ", name, " ", params)


func user_property(name: String, value: String) -> void:
	if _plugin:
		_plugin.setUserProperty(name, value)
