package com.example.caitlyn_laundry_shop

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/** Background one-shot reminder. Persistent across process death / reboot by WorkManager. */
class SmsReminderWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val context = applicationContext
        val prefs = context.getSharedPreferences("caitlyn_sim_sms", 0)
        if (!prefs.getBoolean("automation_enabled", false)) return Result.success()
        val id = inputData.getString("id") ?: return Result.failure()
        val phone = inputData.getString("phone") ?: return Result.failure()
        val message = inputData.getString("message") ?: return Result.failure()
        val whenMs = inputData.getLong("whenMs", 0)
        if (whenMs <= 0L) return Result.failure()
        // Protect against early execution and records cancelled in the meantime.
        if (whenMs > System.currentTimeMillis() + 60_000) return Result.retry()
        if (SmsLedger.status(context, id) != "scheduled") return Result.success()
        // A phone that comes back online days later must not send a stale reminder.
        if (System.currentTimeMillis() - whenMs > TimeUnit.HOURS.toMillis(24)) {
            SmsLedger.failed(context, id, "Reminder expired: phone was unavailable too long")
            return Result.success()
        }
        try {
            // This records 'queued' synchronously BEFORE the modem call.
            // If a process crashes, it will not blindly send twice.
            SmsTransmitter.send(context, id, phone, message)
        } catch (error: Exception) {
            SmsLedger.failed(context, id, "Background send failed: ${error.message}")
            // Manual staff follow-up is safer than an automatic retry that may duplicate texts.
        }
        return Result.success()
    }
}
