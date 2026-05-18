package com.invoiceflow.features.notifications

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * AMI-88: bridges the FCM token to our backend. Today the backend has no
 * /devices endpoint yet, so we just log the token — that's enough to
 * verify the FCM pipeline (token refresh + RemoteMessage delivery) using
 * the Firebase Console's "test message" feature.
 *
 * When the backend ships the endpoint, swap [registerWithBackend] for
 * the real ApiService call. The contract we already pre-agreed with
 * the server team:
 *
 *     POST /api/v1/devices
 *     { "platform": "android", "token": "<fcm_token>" }
 *
 * Idempotent on (user_id, token).
 */
@Singleton
class PushTokenRegistrar @Inject constructor() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Called by [AmiMessagingService.onNewToken] on FCM token refresh. */
    fun onTokenRefreshed(token: String) {
        Log.i(TAG, "FCM token refreshed: ${token.take(16)}...")
        scope.launch { registerWithBackend(token) }
    }

    /** Called on successful login so the new session inherits the token. */
    fun pullAndRegister() {
        scope.launch {
            runCatching { FirebaseMessaging.getInstance().token.await() }
                .onSuccess { token ->
                    Log.i(TAG, "FCM token at login: ${token.take(16)}...")
                    registerWithBackend(token)
                }
                .onFailure { e -> Log.w(TAG, "FCM token fetch failed", e) }
        }
    }

    /** No-op until the backend ships /api/v1/devices. */
    private suspend fun registerWithBackend(@Suppress("UNUSED_PARAMETER") token: String) {
        // POST /api/v1/devices { platform: "android", token: token }
        // Pending backend endpoint.
    }

    companion object {
        private const val TAG = "PushTokenRegistrar"
    }
}
