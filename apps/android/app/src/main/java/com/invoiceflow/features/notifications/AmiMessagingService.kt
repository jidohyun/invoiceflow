package com.invoiceflow.features.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.invoiceflow.MainActivity
import com.invoiceflow.R
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * AMI-88: receive push notifications for payment-received, overdue, and
 * reminder-sent events.
 *
 * The token half ("which device am I?") is owned by [PushTokenRegistrar],
 * which gets invoked on token refresh AND on successful login. The
 * notification half ("show a notification when a message arrives") lives
 * here.
 *
 * Until the backend ships a push endpoint we only log the token. That
 * still validates the FCM pipeline end-to-end and lets the app receive
 * test messages from the Firebase Console.
 */
@AndroidEntryPoint
class AmiMessagingService : FirebaseMessagingService() {

    @Inject lateinit var tokenRegistrar: PushTokenRegistrar

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        tokenRegistrar.onTokenRefreshed(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val title = message.notification?.title
            ?: message.data["title"]
            ?: "AutoMyInvoice"
        val body = message.notification?.body
            ?: message.data["body"]
            ?: return

        ensureChannel()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
            message.data["invoice_id"]?.let { putExtra("invoice_id", it) }
        }
        val pending = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        getSystemService<NotificationManager>()
            ?.notify(message.messageId.hashCode(), notification)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService<NotificationManager>() ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "기본 알림",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "결제 / 연체 / 리마인더 발송 안내" }
        )
    }

    companion object {
        const val CHANNEL_ID = "ami_default"
    }
}
