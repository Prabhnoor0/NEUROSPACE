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
 * Captures meaningful text content from any screen, filtering out
 * advertisements, system UI, navigation chrome, and short fragments.
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

        /** View IDs that typically contain ads */
        private val AD_VIEW_ID_PATTERNS = listOf(
            "ad_", "ads_", "adview", "ad_container", "ad_frame",
            "banner_ad", "admob", "google_ads", "adUnit",
            "native_ad", "interstitial", "reward_ad",
            "sponsored", "promo_banner", "ad_layout",
        )

        /** Class names of common ad SDK views */
        private val AD_CLASS_PATTERNS = listOf(
            "com.google.android.gms.ads",
            "com.facebook.ads",
            "com.applovin",
            "com.unity3d.ads",
            "com.mopub",
            "com.inmobi",
            "com.ironsource",
            "AdView", "NativeAdView", "BannerAd",
        )

        /** Common ad / promo text patterns to detect and skip */
        private val AD_TEXT_PATTERNS = listOf(
            Regex("^(Ad|AD|Sponsored|Advertisement)$", RegexOption.IGNORE_CASE),
            Regex("^Install Now$", RegexOption.IGNORE_CASE),
            Regex("^(Download|Get it on|Shop Now|Buy Now|Order Now|Sign Up|Subscribe)$", RegexOption.IGNORE_CASE),
            Regex("^Login for better experience", RegexOption.IGNORE_CASE),
            Regex("^Login Now$", RegexOption.IGNORE_CASE),
            Regex("^(Skip Ad|Close Ad|Why this ad)$", RegexOption.IGNORE_CASE),
            Regex("^\\d+\\s*×\\s*\\d+$"),  // Ad dimension labels like "320x50"
        )

        /** Navigation / chrome text to skip */
        private val CHROME_TEXT_EXACT = setOf(
            "Home", "Search", "Menu", "More", "Share", "Back",
            "Forward", "Refresh", "Stop", "Settings", "Close",
            "Cancel", "OK", "Done", "Yes", "No", "Got it",
            "Allow", "Deny", "Accept", "Decline", "Skip",
            "Next", "Previous", "Prev",
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
                        extractText(rootNode, textBuilder, depth = 0)
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
     * Check if a node is an ad container based on its view ID or class name.
     */
    private fun isAdNode(node: AccessibilityNodeInfo): Boolean {
        // Check view ID
        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        for (pattern in AD_VIEW_ID_PATTERNS) {
            if (viewId.contains(pattern)) return true
        }

        // Check class name
        val className = node.className?.toString() ?: ""
        for (pattern in AD_CLASS_PATTERNS) {
            if (className.contains(pattern, ignoreCase = true)) return true
        }

        return false
    }

    /**
     * Check if text looks like an advertisement or promo.
     */
    private fun isAdText(text: String): Boolean {
        for (pattern in AD_TEXT_PATTERNS) {
            if (pattern.containsMatchIn(text)) return true
        }
        return false
    }

    /**
     * Check if text is navigation chrome (single-word buttons etc.)
     */
    private fun isChromeText(text: String): Boolean {
        return text in CHROME_TEXT_EXACT
    }

    /**
     * Recursively walk the accessibility node tree and extract meaningful text content.
     * Skips ad containers, navigation buttons, and short non-informative fragments.
     */
    private fun extractText(node: AccessibilityNodeInfo, builder: StringBuilder, depth: Int) {
        // Skip ad containers entirely (don't recurse into children)
        if (isAdNode(node)) return

        // Skip clickable leaf nodes that look like buttons (navigation chrome)
        // but keep clickable items in lists (like article titles)
        val isButton = node.className?.toString()?.contains("Button") == true
        val isImageView = node.className?.toString()?.contains("ImageView") == true

        // Get text from this node
        val nodeText = node.text?.toString()?.trim()
        if (!nodeText.isNullOrEmpty()) {
            // Skip very short text (single chars, icons, labels)
            val isLongEnough = nodeText.length > 3

            // Skip ad-like text
            val isAd = isAdText(nodeText)

            // Skip navigation chrome (but only single-word matches)
            val isChrome = isChromeText(nodeText) && isButton

            // Skip content description duplicates on ImageViews
            val isDecorative = isImageView && nodeText.length < 20

            if (isLongEnough && !isAd && !isChrome && !isDecorative) {
                builder.append(nodeText).append("\n")
            }
        }

        // Also check content description (for images with alt text)
        // But only if it's substantial (skip icon descriptions)
        val contentDesc = node.contentDescription?.toString()?.trim()
        if (!contentDesc.isNullOrEmpty() && contentDesc != nodeText
            && contentDesc.length > 10
            && !isAdText(contentDesc)
            && !isImageView) {
            builder.append(contentDesc).append("\n")
        }

        // Recurse into children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            extractText(child, builder, depth + 1)
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
