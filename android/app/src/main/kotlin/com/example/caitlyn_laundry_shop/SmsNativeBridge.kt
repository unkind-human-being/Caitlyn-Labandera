package com.example.caitlyn_laundry_shop

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.util.UUID
import java.util.concurrent.TimeUnit

/** Native channel only performs SMS operations requested and enabled by the shop admin. */
class SmsNativeBridge(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "caitlyn_laundry/sim_sms")
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun register() = channel.setMethodCallHandler(this)

    private fun permissionGranted(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun handlePermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_SMS_PERMISSION) return
        pendingPermissionResult?.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        )
        pendingPermissionResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isSmsCapable" -> result.success(SmsTransmitter.isSmsCapable(activity))
                "hasPermission" -> result.success(permissionGranted())
                "requestPermission" -> {
                    if (!SmsTransmitter.isSmsCapable(activity)) {
                        result.error("NO_SMS_HARDWARE", "No SMS-capable radio in this device.", null)
                    } else if (permissionGranted()) {
                        result.success(true)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (pendingPermissionResult != null) {
                            result.error("BUSY", "Another permission request is open.", null)
                        } else {
                            pendingPermissionResult = result
                            activity.requestPermissions(
                                arrayOf(Manifest.permission.SEND_SMS), REQUEST_SMS_PERMISSION
                            )
                        }
                    } else {
                        result.success(permissionGranted())
                    }
                }
                "sendTest" -> {
                    check(permissionGranted()) { "Grant SMS permission first." }
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val id = "test_${UUID.randomUUID()}"
                    SmsTransmitter.send(activity, id, phone, message)
                    result.success(id)
                }
                "sendOrderNow" -> {
                    check(permissionGranted()) { "Grant SMS permission first." }
                    val id = call.argument<String>("id") ?: ""
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    check(id.isNotBlank() && !id.startsWith("test_")) { "Invalid order ID." }
                    SmsTransmitter.send(activity, id, phone, message)
                    // Prevent future automatic reminders for the same order.
                    WorkManager.getInstance(activity).cancelUniqueWork("caitlyn_reminder_$id")
                    result.success(null)
                }
                "getStatuses" -> result.success(SmsLedger.list(activity))
                "syncScheduled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val jobs = call.argument<List<Map<String, Any>>>("jobs") ?: emptyList()
                    result.success(syncScheduled(enabled, jobs))
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("SIM_SMS_ERROR", error.message ?: error.javaClass.simpleName, null)
        }
    }

    private fun syncScheduled(enabled: Boolean, jobs: List<Map<String, Any>>): Int {
        if (enabled) {
            check(permissionGranted()) { "SMS permission required before enabling reminders." }
            check(SmsTransmitter.isSmsCapable(activity)) { "Phone cannot send SIM SMS." }
        }
        val prefs = activity.getSharedPreferences(PREFS, 0)
        val manager = WorkManager.getInstance(activity)
        // Workers check this switch again immediately before attempting a send.
        check(prefs.edit().putBoolean("automation_enabled", enabled).commit()) {
            "Could not persist SMS automation switch."
        }
        val previous = prefs.getStringSet("scheduled_ids", emptySet())?.toSet() ?: emptySet()
        val next = mutableSetOf<String>()
        val now = System.currentTimeMillis()
        var count = 0
        if (enabled) {
            for (job in jobs) {
                val id = job["id"] as? String ?: continue
                val number = job["phone"] as? String ?: continue
                val message = job["message"] as? String ?: continue
                val whenMs = (job["whenMs"] as? Number)?.toLong() ?: continue
                // Enabling later in the day will never cause immediate bulk sends.
                if (id.isBlank() || whenMs <= now + 60_000L) continue
                if (!SmsTransmitter.validNumber(number) || message.isBlank()) continue
                val old = SmsLedger.status(activity, id)
                if (old in setOf("queued", "sent", "delivered", "failed")) continue
                val request = OneTimeWorkRequestBuilder<SmsReminderWorker>()
                    .setInputData(workDataOf(
                        "id" to id, "phone" to number,
                        "message" to message, "whenMs" to whenMs
                    ))
                    .setInitialDelay(whenMs - now, TimeUnit.MILLISECONDS)
                    .addTag("caitlyn_laundry_sms")
                    .build()
                manager.enqueueUniqueWork("caitlyn_reminder_$id", ExistingWorkPolicy.REPLACE, request)
                SmsLedger.schedule(activity, id)
                next.add(id)
                count++
            }
        }
        for (id in previous - next) {
            manager.cancelUniqueWork("caitlyn_reminder_$id")
            if (SmsLedger.status(activity, id) == "scheduled") {
                SmsLedger.cancel(activity, id)
            }
        }
        check(prefs.edit().putStringSet("scheduled_ids", next).commit()) {
            "Could not persist pending reminder IDs."
        }
        return count
    }

    companion object {
        private const val REQUEST_SMS_PERMISSION = 7043
        private const val PREFS = "caitlyn_sim_sms"
    }
}
