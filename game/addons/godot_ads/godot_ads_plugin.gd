@tool
extends EditorPlugin
## Packs the GodotAds Android library (built by CI into bin/) and the
## Google Mobile Ads + UMP (consent) dependencies into Android exports.

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const AAR := "godot_ads/bin/GodotAds-release.aar"  # relative to res://addons/
	const DEPENDENCIES := [
		"com.google.android.gms:play-services-ads:23.6.0",
		"com.google.android.ump:user-messaging-platform:3.1.0",
		"com.google.firebase:firebase-analytics:22.1.2",
	]

	func _get_name() -> String:
		return "GodotAds"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not FileAccess.file_exists("res://addons/" + AAR):
			push_warning("GodotAds: %s is missing — build it with the CI workflow (ads disabled)." % AAR)
			return PackedStringArray()
		return PackedStringArray([AAR])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(DEPENDENCIES)

	## AdMob and Firebase Analytics both declare this property with different
	## files, which breaks the manifest merge. Added to the GAME's manifest
	## (where AdMob's resource exists) so AdMob's value wins.
	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return """
		<property
			android:name="android.adservices.AD_SERVICES_CONFIG"
			android:resource="@xml/gma_ad_services_config"
			tools:replace="android:resource" />
"""
