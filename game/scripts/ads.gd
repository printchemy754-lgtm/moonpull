extends Node
## Ads facade. On Android it talks to the GodotAds plugin (AdMob).
## On desktop / in the editor ads are simulated so the game is fully playable.

signal rewarded_finished(earned: bool)
signal interstitial_closed

## true  = Google's TEST ads (safe while you develop and play your own game).
## false = YOUR real ads that earn money. Switch only for the Google Play release:
## clicking your own real ads can get the AdMob account banned.
const USE_TEST_ADS := true

# Your AdMob ad units (app "MoonPull", app ID ca-app-pub-7224699187685418~1990333465)
const REAL_BANNER_ID := "ca-app-pub-7224699187685418/8520704914"
const REAL_INTERSTITIAL_ID := "ca-app-pub-7224699187685418/5399717554"
const REAL_REWARDED_ID := "ca-app-pub-7224699187685418/3785710995"

# Google's official test units
const TEST_BANNER_ID := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

var BANNER_ID: String = TEST_BANNER_ID if USE_TEST_ADS else REAL_BANNER_ID
var INTERSTITIAL_ID: String = TEST_INTERSTITIAL_ID if USE_TEST_ADS else REAL_INTERSTITIAL_ID
var REWARDED_ID: String = TEST_REWARDED_ID if USE_TEST_ADS else REAL_REWARDED_ID

## Interstitial pacing: at most one every N finished rounds,
## never before this level, and never more often than the gap below.
## Gentle on purpose (the Crossy Road lesson: players who aren't annoyed stay,
## and players who stay watch far more optional rewarded ads).
const INTERSTITIAL_EVERY := 4
const INTERSTITIAL_FROM_LEVEL := 6
const INTERSTITIAL_MIN_GAP_MS := 75000

var _plugin: Object = null
var _in_ad := false
var _mute_tick := 0.0
var _rounds := 0
var _last_full_screen_ms := -INTERSTITIAL_MIN_GAP_MS


func _ready() -> void:
	if Engine.has_singleton("GodotAds"):
		_plugin = Engine.get_singleton("GodotAds")
		_plugin.connect("rewarded_finished", _on_plugin_rewarded, CONNECT_DEFERRED)
		_plugin.connect("interstitial_closed", _on_plugin_interstitial, CONNECT_DEFERRED)
		_plugin.connect("ad_error", _on_plugin_error, CONNECT_DEFERRED)
		_plugin.initialize(BANNER_ID, INTERSTITIAL_ID, REWARDED_ID)
	elif OS.has_feature("web"):
		print("[Ads] browser build — CrazyGames SDK ads when available, else simulated.")
	else:
		print("[Ads] GodotAds plugin not found — simulating ads (desktop/editor).")


func is_real() -> bool:
	return _plugin != null


## GDPR: true when the player is in a region where they must be able to
## change their ad consent (shows a PRIVACY button in Settings).
func privacy_required() -> bool:
	if _plugin:
		return _plugin.isPrivacyOptionsRequired()
	return false


func show_privacy_options() -> void:
	if _plugin:
		_plugin.showPrivacyOptions()


const STORE_URL := "https://play.google.com/store/apps/details?id=com.streamlet.moonpull"


## Opens the Android share sheet (or copies the text in the browser/desktop).
## Returns true when the system share sheet was used.
## Sharing is hidden in the browser (portals don't allow links to app stores).
func can_share() -> bool:
	return not OS.has_feature("web")


func share_text(text: String) -> bool:
	if _plugin and _plugin.has_method("shareText"):
		_plugin.shareText(text)
		return true
	DisplayServer.clipboard_set(text)
	return false


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
	if CrazySDK.active():
		_mute_for_ad(true)
		CrazySDK.ad("rewarded", func(ok: bool):
			_mute_for_ad(false)
			_last_full_screen_ms = Time.get_ticks_msec()
			rewarded_finished.emit(ok))
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
	elif CrazySDK.active():
		_mute_for_ad(true)
		CrazySDK.ad("midgame", func(_ok: bool):
			_mute_for_ad(false)
			interstitial_closed.emit())
	else:
		print("[Ads] (simulated) interstitial")
		call_deferred("emit_signal", "interstitial_closed")


## Game sound must be silent while a web ad plays.
func _mute_for_ad(on: bool) -> void:
	_in_ad = on
	AudioServer.set_bus_mute(0, on or CrazySDK.muted())


## Follows the CrazyGames "mute" setting in the browser.
func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_mute_tick -= delta
	if _mute_tick <= 0.0:
		_mute_tick = 0.5
		AudioServer.set_bus_mute(0, _in_ad or CrazySDK.muted())


func _on_plugin_rewarded(earned: bool) -> void:
	_last_full_screen_ms = Time.get_ticks_msec()
	rewarded_finished.emit(earned)


func _on_plugin_interstitial() -> void:
	interstitial_closed.emit()


func _on_plugin_error(message: String) -> void:
	print("[Ads] ", message)
