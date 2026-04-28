package com.neurospace.neurospace

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

/**
 * NeuroSpace Accessibility Service
 * ================================
 * Captures all visible text content from any screen.
 * Writes the collected text to SharedPreferences so the
 * Flutter overlay can read it for summarization/TTS.
 *
 * The user must enable this service once in:
 *   Settings → Accessibility → NeuroSpace
 */
class NeuroAccessibilityService : AccessibilityService() {

    companion object {
        /** Key used in SharedPreferences (uses Flutter's prefix so shared_preferences can read it). */
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SCREEN_TEXT = "flutter.neuro_screen_text"
        private const val KEY_SERVICE_ACTIVE = "flutter.neuro_accessibility_active"
        private const val KEY_SOURCE_PACKAGE = "flutter.neuro_source_package"

        /** Packages to completely skip — never read text from these */
        private val BLOCKED_PACKAGES = setOf(
            "com.neurospace.neurospace",      // Our own overlay
            "com.android.systemui",           // Status bar, notifications, quick settings
            "android",                        // System framework windows
            "com.android.launcher",           // Home screen launcher
            "com.android.launcher3",          // AOSP launcher
            "com.google.android.apps.nexuslauncher", // Pixel launcher
            "com.samsung.android.launcher",   // Samsung launcher
        )

        /** Window types that should be skipped */
        private val BLOCKED_WINDOW_TYPES = setOf(
            AccessibilityWindowInfo.TYPE_SYSTEM,           // System-level windows (status bar)
            AccessibilityWindowInfo.TYPE_INPUT_METHOD,      // Keyboard windows
            AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY, // Accessibility overlays
        )
    }

    private lateinit var prefs: SharedPreferences

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_SERVICE_ACTIVE, true).apply()

        // Configure the service to listen for window and content changes
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 500 // ms debounce
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // Only process meaningful events
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                val textBuilder = StringBuilder()
                var sourcePackage = ""

                // Get all windows on the screen
                val activeWindows = windows ?: return
                var foundAppText = false

                for (window in activeWindows) {
                    // Skip system-level window types (status bar, keyboard, etc.)
                    if (window.type in BLOCKED_WINDOW_TYPES) {
                        continue
                    }

                    val rootNode = window.root ?: continue
                    val pkg = rootNode.packageName?.toString() ?: ""

                    // Skip blocked packages (overlay, systemUI, launchers)
                    if (pkg in BLOCKED_PACKAGES) {
                        rootNode.recycle()
                        continue
                    }

                    // Only read from APPLICATION type windows (real apps)
                    if (window.type == AccessibilityWindowInfo.TYPE_APPLICATION) {
                        extractText(rootNode, textBuilder)
                        if (sourcePackage.isEmpty() && pkg.isNotEmpty()) {
                            sourcePackage = pkg
                        }
                        foundAppText = true
                    }

                    rootNode.recycle()
                }

                val screenText = textBuilder.toString().trim()
                if (foundAppText && screenText.isNotEmpty()) {
                    // Normalize reading order (remove duplicate lines and excessive breaks)
                    val normalizedText = screenText.lines()
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }
                        .distinct()
                        .joinToString("\n")

                    prefs.edit()
                        .putString(KEY_SCREEN_TEXT, normalizedText)
                        .putString(KEY_SOURCE_PACKAGE, sourcePackage)
                        .apply()
                }
            }
        }
    }

    /**
     * Recursively walk the accessibility node tree and extract all text content.
     */
    private fun extractText(node: AccessibilityNodeInfo, builder: StringBuilder) {
        // Get text from this node
        val nodeText = node.text?.toString()?.trim()
        if (!nodeText.isNullOrEmpty()) {
            builder.append(nodeText).append("\n")
        }

        // Also check content description (for images with alt text, icons, etc.)
        val contentDesc = node.contentDescription?.toString()?.trim()
        if (!contentDesc.isNullOrEmpty() && contentDesc != nodeText) {
            builder.append(contentDesc).append("\n")
        }

        // Recurse into children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            extractText(child, builder)
            child.recycle()
        }
    }

    override fun onInterrupt() {
        // Called when the service is interrupted
    }

    override fun onDestroy() {
        super.onDestroy()
        prefs.edit().putBoolean(KEY_SERVICE_ACTIVE, false).apply()
    }
}
