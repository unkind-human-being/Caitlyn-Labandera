package com.example.caitlyn_laundry_shop

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat

/** Direct SIM dispatch. No SMS composer, internet access, READ_SMS or READ_PHONE_STATE. */
object SmsTransmitter {
    private val PH_MOBILE = Regex("^\\+639[0-9]{9}$")

    fun validNumber(number: String) = PH_MOBILE.matches(number)

    
    fun isSmsCapable(context: Context): Boolean {
        val packageManager = context.packageManager

        return if (Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.TIRAMISU
        ) {
            packageManager.hasSystemFeature(
                PackageManager.FEATURE_TELEPHONY_MESSAGING
            )
        } else {
            packageManager.hasSystemFeature(
                PackageManager.FEATURE_TELEPHONY
            )
        }
    }


    @Suppress("DEPRECATION")
    private fun smsManager(context: Context): SmsManager {
        val subscriptionId = SubscriptionManager.getDefaultSmsSubscriptionId()
        check(subscriptionId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            "Select a default SMS SIM in Android Settings (especially on dual-SIM phones)."
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
                .createForSubscriptionId(subscriptionId)
        } else {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        }
    }

    @Suppress("DEPRECATION")
    fun send(context: Context, id: String, phone: String, message: String) {
        check(isSmsCapable(context)) { "This Android phone has no SMS radio." }
        check(ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED) { "SEND_SMS permission not granted." }
        check(validNumber(phone)) { "Enter a valid Philippine mobile number (+639XXXXXXXXX)." }
        check(message.isNotBlank() && message.length <= 300) { "SMS text must contain 1–300 characters." }
        val old = SmsLedger.status(context, id)
        check(old !in setOf("queued", "sent", "delivered")) {
            "Already attempted/sent. Duplicate dispatch blocked."
        }
        val manager = smsManager(context)
        val segments = manager.divideMessage(message)
        check(segments.isNotEmpty()) { "SMS message is empty." }
        SmsLedger.queued(context, id, segments.size)
        try {
            fun pending(action: String, part: Int): PendingIntent {
                val intent = Intent(context, SmsStatusReceiver::class.java).apply {
                    this.action = action
                    putExtra("id", id)
                    putExtra("part", part)
                    putExtra("total", segments.size)
                }
                val requestCode = ("$action|$id|$part".hashCode() and Int.MAX_VALUE)
                return PendingIntent.getBroadcast(
                    context, requestCode, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            }
            if (segments.size == 1) {
                manager.sendTextMessage(phone, null, segments[0],
                    pending(SmsStatusReceiver.ACTION_SENT, 0),
                    pending(SmsStatusReceiver.ACTION_DELIVERED, 0))
            } else {
                val sent = ArrayList<PendingIntent>()
                val delivered = ArrayList<PendingIntent>()
                for (i in segments.indices) {
                    sent.add(pending(SmsStatusReceiver.ACTION_SENT, i))
                    delivered.add(pending(SmsStatusReceiver.ACTION_DELIVERED, i))
                }
                manager.sendMultipartTextMessage(phone, null, segments, sent, delivered)
            }
        } catch (error: Exception) {
            SmsLedger.failed(context, id, "Android SMS request failed: ${error.message}")
            throw error
        }
    }
}
