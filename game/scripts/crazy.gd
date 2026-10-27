class_name CrazySDK
extends RefCounted
## CrazyGames SDK v3 (browser build only). The SDK itself and a tiny JS glue
## object `window.MPCG` are injected by the Web export preset (html/head_include).
## Everything here is a no-op on Android / iOS / desktop.

static var _cb_keep: Array = []   # JS callbacks must stay referenced


static func _js() -> Object:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.get_interface("MPCG")


## SDK finished initialising (ok or failed).
static func settled() -> bool:
	var m := _js()
	if m == null:
		return true
	return bool(m.ready) or bool(m.failed)


## Running on CrazyGames (or their local test environment) with a working SDK.
static func active() -> bool:
	var m := _js()
	if m == null or not bool(m.ready):
		return false
	var env := String(m.env)
	return env == "crazygames" or env == "local"


static func muted() -> bool:
	var m := _js()
	return m != null and bool(m.muted)


static func gameplay(on: bool) -> void:
	if active():
		JavaScriptBridge.eval("window.MPCG.gameplay(%s)" % ("true" if on else "false"), true)


static func happy() -> void:
	if active():
		JavaScriptBridge.eval("window.MPCG.happy()", true)


static func loading_done() -> void:
	if active():
		JavaScriptBridge.eval("window.MPCG.loadingDone()", true)


## type: "rewarded" or "midgame". done(ok: bool) is called when the ad ends.
static func ad(type: String, done: Callable) -> void:
	var m := _js()
	var cb := JavaScriptBridge.create_callback(func(args: Array):
		done.call(args.size() > 0 and bool(args[0])))
	_cb_keep.append(cb)
	if _cb_keep.size() > 8:
		_cb_keep.pop_front()
	m.ad(type, cb)


## Data Module (cloud save for logged-in players, local otherwise).
static func load_text(key: String) -> String:
	if not active():
		return ""
	var v = JavaScriptBridge.eval("window.MPCG.getItem(%s)" % JSON.stringify(key), true)
	return "" if v == null else String(v)


static func save_text(key: String, text: String) -> void:
	if active():
		JavaScriptBridge.eval("window.MPCG.setItem(%s, %s)" % [JSON.stringify(key), JSON.stringify(text)], true)
