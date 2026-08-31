package com.memorize.me

import android.accounts.Account
import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val googlePickerChannel = "memorize_me/google_picker"
    private val googlePickerRequestCode = 9134
    private val driveFileScope = "https://www.googleapis.com/auth/drive.file"
    private val spreadsheetMimeType = "application/vnd.google-apps.spreadsheet"
    private var pendingPickerResult: MethodChannel.Result? = null
    private val authorizationClient by lazy { Identity.getAuthorizationClient(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            googlePickerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickSpreadsheet" -> {
                    val accountEmail = call.argument<String>("accountEmail").orEmpty()
                    openNativePicker(accountEmail, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openNativePicker(
        accountEmail: String,
        result: MethodChannel.Result,
    ) {
        pendingPickerResult?.success(null)
        pendingPickerResult = result

        val requestBuilder = AuthorizationRequest.builder()
            .setRequestedScopes(listOf(Scope(driveFileScope)))
            .setOptOutIncludingGrantedScopes(true)
            .setPrompt(AuthorizationRequest.Prompt.CONSENT)
            .addResourceParameter(
                AuthorizationRequest.ResourceParameter.PICKER_OAUTH_TRIGGER,
                "true",
            )
            .addResourceParameter(
                AuthorizationRequest.ResourceParameter.PICKER_MIMETYPES,
                spreadsheetMimeType,
            )

        if (accountEmail.isNotBlank()) {
            requestBuilder.setAccount(Account(accountEmail, "com.google"))
        } else {
            requestBuilder.setPrompt(
                AuthorizationRequest.Prompt.CONSENT or
                    AuthorizationRequest.Prompt.SELECT_ACCOUNT,
            )
        }

        authorizationClient.authorize(requestBuilder.build())
            .addOnSuccessListener { authorizationResult ->
                val pendingIntent = authorizationResult.pendingIntent
                if (authorizationResult.hasResolution() && pendingIntent != null) {
                    try {
                        @Suppress("DEPRECATION")
                        startIntentSenderForResult(
                            pendingIntent.intentSender,
                            googlePickerRequestCode,
                            null,
                            0,
                            0,
                            0,
                        )
                    } catch (error: Exception) {
                        finishPickerWithError(
                            "picker_launch_failed",
                            "Google Drive file picker could not be opened.",
                            error.message,
                        )
                    }
                } else {
                    finishPicker(authorizationResult)
                }
            }
            .addOnFailureListener { error ->
                finishPickerWithError(
                    "picker_authorization_failed",
                    "Google Drive permission could not be requested.",
                    error.message,
                )
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != googlePickerRequestCode) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            finishPickerAsCancelled()
            return
        }

        try {
            finishPicker(authorizationClient.getAuthorizationResultFromIntent(data))
        } catch (error: ApiException) {
            if (error.statusCode == CommonStatusCodes.CANCELED) {
                finishPickerAsCancelled()
            } else {
                finishPickerWithError(
                    "picker_result_failed",
                    "The selected Google Drive file could not be authorized.",
                    error.message,
                )
            }
        }
    }

    private fun finishPicker(authorizationResult: AuthorizationResult) {
        val fileIds = authorizationResult.tokenResponseParams
            ?.getString("picked_file_ids")
            ?.split(',')
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            .orEmpty()

        if (fileIds.isEmpty()) {
            finishPickerAsCancelled()
            return
        }

        val accessToken = authorizationResult.accessToken
        if (accessToken.isNullOrBlank()) {
            finishPickerWithError(
                "picker_token_missing",
                "Google Drive did not return an access token for the selected file.",
                null,
            )
            return
        }

        pendingPickerResult?.success(
            mapOf(
                "id" to fileIds.first(),
                "name" to "Google Sheets",
                "accessToken" to accessToken,
            ),
        )
        clearPickerPending()
    }

    private fun finishPickerAsCancelled() {
        pendingPickerResult?.success(null)
        clearPickerPending()
    }

    private fun finishPickerWithError(code: String, message: String, details: String?) {
        pendingPickerResult?.error(code, message, details)
        clearPickerPending()
    }

    private fun clearPickerPending() {
        pendingPickerResult = null
    }
}
