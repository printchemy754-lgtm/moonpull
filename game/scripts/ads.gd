extends Node
## Ads facade. On Android it talks to the GodotAds plugin (AdMob).
## On desktop / in the editor ads are simulated so the game is fully playable.

signal rewarded_finished(earned: bool)
signal interstitial_closed

# Google's official TEST ad unit IDs — safe for development.
# Replace with your own AdMob unit IDs before publishing (see README).
const BANNER_ID := "ca-app-pub-3940256099942544/6300978111"
const INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

## Interstitial pacing: at most one every N finished rounds,
## never before this level, and never more often than the gap below.
const INTERSTITIAL_EVERY := 3
const INTERSTITIAL_FROM_LEVEL := 3
const INTERSTITIAL_MIN_GAP_MS := 45000

var _plugin: Object = null
var _rounds := 0
var _last_full_screen_ms := -INTERSTITIAL_MIN_GAP_MS


func _ready() -> void:
	if Engine.has_singleton("GodotAds"):
		_plugin = Engine.get_singleton("GodotAds")
		_plugin.connect("rewarded_finished", _on_plugin_rewarded, CONNECT_DEFERRED)
		_plugin.connect("interstitial_closed", _on_plugin_interstitial, CONNECT_DEFERRED)
		_plugin.connect("ad_error", _on_plugin_error, CONNECT_DEFERRED)
		_plugin.initialize(BANNER_ID, INTERSTITIAL_ID, REWARDED_ID)
	else:
		print("[Ads] GodotAds plugin not found — simulating ads (desktop/editor).")


func is_real() -> bool:
	return _plugin != null


func show_banner() -> void:
	if _plugin:
		_plugin.showBanner()


func hide_banner() -> void:
	if _plugin:
		_plugin.hideBanner()


func is_rewarded_ready() -> bool:
	if _plugin:
		return _plugin.isRewardedReady()
	return true


func show_rewarded() -> void:
	if _plugin:
		_plugin.showRewarded()
		return
	print("[Ads] (simulated) rewarded ad watched")
	await get_tree().create_timer(0.4).timeout
	_last_full_screen_ms = Time.get_ticks_msec()
	rewarded_finished.emit(true)


## Call once per finished round (win or retry). Returns true when an
## interstitial should be shown now; then call show_interstitial()
## and await interstitial_closed.
func round_ended_should_show(level: int) -> bool:
	_rounds += 1
	if level < INTERSTITIAL_FROM_LEVEL or _rounds < INTERSTITIAL_EVERY:
		return false
	if Time.get_ticks_msec() - _last_full_screen_ms < INTERSTITIAL_MIN_GAP_MS:
		return false
	if _plugin and not _plugin.isInterstitialReady():
		return false
	_rounds = 0
	_last_full_screen_ms = Time.get_ticks_msec()
	return true


func show_interstitial() -> void:
	if _plugin:
		_plugin.showInterstitial()
	else:
		print("[Ads] (simulated) interstitial")
		call_deferred("emit_signal", "interstitial_closed")


func _on_plugin_rewarded(earned: bool) -> void:
	_last_full_screen_ms = Time.get_ticks_msec()
	rewarded_finished.emit(earned)


func _on_plugin_interstitial() -> void:
	interstitial_closed.emit()


func _on_plugin_error(message: String) -> void:
	print("[Ads] ", message)
