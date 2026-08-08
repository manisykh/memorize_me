package com.memorize.me

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val googlePickerChannel = "memorize_me/google_picker"
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingPickerState: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handlePickerCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handlePickerCallback(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            googlePickerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickSpreadsheet" -> {
                    val pickerUrl = call.argument<String>("pickerUrl").orEmpty()
                    if (pickerUrl.isBlank()) {
                        result.error(
                            "picker_config_missing",
                            "Google Picker URL is missing.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    openPickerInBrowser(pickerUrl, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openPickerInBrowser(
        pickerUrl: String,
        result: MethodChannel.Result,
    ) {
        pendingPickerResult?.success(null)

        val state = UUID.randomUUID().toString()
        pendingPickerState = state
        pendingPickerResult = result

        val uri = Uri.parse(pickerUrl).buildUpon()
            .appendQueryParameter("redirect_uri", "memorizeme://picker")
            .appendQueryParameter("state", state)
            .build()

        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (error: Exception) {
            clearPickerPending()
            result.error(
                "picker_browser_unavailable",
                "Could not open a browser for Google Picker.",
                error.message,
            )
        }
    }

    private fun handlePickerCallback(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "memorizeme" || uri.host != "picker") return

        val result = pendingPickerResult ?: return
        val expectedState = pendingPickerState
        val receivedState = uri.getQueryParameter("state")
        if (expectedState == null || expectedState != receivedState) {
            result.error("picker_state_mismatch", "Invalid Google Picker callback.", null)
            clearPickerPending()
            return
        }

        val error = uri.getQueryParameter("error")
        if (!error.isNullOrBlank()) {
            result.error("picker_failed", error, null)
            clearPickerPending()
            return
        }

        val spreadsheetId = uri.getQueryParameter("spreadsheetId")
        if (spreadsheetId.isNullOrBlank()) {
            result.success(null)
            clearPickerPending()
            return
        }

        result.success(
            mapOf(
                "id" to spreadsheetId,
                "name" to (uri.getQueryParameter("name") ?: "Google Sheets"),
            ),
        )
        clearPickerPending()
    }

    private fun clearPickerPending() {
        pendingPickerResult = null
        pendingPickerState = null
    }
}
