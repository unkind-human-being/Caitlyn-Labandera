package com.example.caitlyn_laundry_shop

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Receives radio SEND and optional DELIVERY report events, even if Flutter is closed. */
class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        val part = intent.getIntExtra("part", 0)
        val total = intent.getIntExtra("total", 1)
        when (intent.action) {
            ACTION_SENT -> SmsLedger.sentPart(context, id, part, total, resultCode)
            ACTION_DELIVERED -> SmsLedger.deliveredPart(context, id, part, total, resultCode)
        }
    }

    companion object {
        const val ACTION_SENT = "caitlyn_laundry.SIM_SMS_SENT"
        const val ACTION_DELIVERED = "caitlyn_laundry.SIM_SMS_DELIVERED"
    }
}
