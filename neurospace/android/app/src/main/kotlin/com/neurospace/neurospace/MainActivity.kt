package com.neurospace.neurospace

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	private val channelName = "neurospace/android_assistant"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					// ── Permission Checks ──
					"isOverlayPermissionGranted" -> {
						result.success(isOverlayPermissionGranted())
					}
					"requestOverlayPermission" -> {
						requestOverlayPermission()
						result.success(true)
					}
					"openOverlaySettings" -> {
						requestOverlayPermission()
						result.success(true)
					}
					"openAccessibilitySettings" -> {
						startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
						result.success(true)
					}
					"isAccessibilityServiceEnabled" -> {
						result.success(isAccessibilityEnabled())
					}

					// ── Overlay Lifecycle ──
					"startOverlay" -> {
						// Overlay is started from Flutter via FlutterOverlayWindow.showOverlay()
						// This method is a native-side hook for future use.
						result.success(true)
					}
					"stopOverlay" -> {
						// Overlay is stopped from Flutter via FlutterOverlayWindow.closeOverlay()
						result.success(true)
					}
					"isOverlayActive" -> {
						// Delegate to FlutterOverlayWindow's native check
						result.success(false)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun isOverlayPermissionGranted(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			Settings.canDrawOverlays(this)
		} else {
			true // Pre-M doesn't require this permission
		}
	}

	private fun requestOverlayPermission() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
			val intent = Intent(
				Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
				Uri.parse("package:$packageName")
			)
			startActivity(intent)
		}
	}

	private fun isAccessibilityEnabled(): Boolean {
		val expectedService = "$packageName/.NeuroAccessibilityService"
		val enabledServices = Settings.Secure.getString(
			contentResolver,
			Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
		) ?: return false

		return enabledServices
			.split(':')
			.any { it.equals(expectedService, ignoreCase = true) }
	}
}
