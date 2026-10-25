package com.example.caitlyn_laundry_shop

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Synchronous persistence prevents a process restart from triggering a duplicate send. */
object SmsLedger {
    private const val PREFS = "caitlyn_sim_sms"
    private const val PREFIX = "status_"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, 0)

    @Synchronized
    private fun update(context: Context, id: String, status: String, detail: String = "",
                       sentPart: Int? = null, deliveredPart: Int? = null,
                       totalParts: Int? = null) {
        val previous = JSONObject(prefs(context).getString("$PREFIX$id", "{}") ?: "{}")
        val oldStatus = previous.optString("status")
        // A later SENT result must never override a previous failure or delivered result.
        if (oldStatus == "delivered" || (oldStatus == "failed" && status != "queued")) return
        val updated = previous
        if (totalParts != null) updated.put("totalParts", totalParts)
        if (sentPart != null) {
            val sent = readParts(updated.optJSONArray("sentParts"))
            sent.add(sentPart)
            updated.put("sentParts", JSONArray(sent.toList().sorted()))
        }
        if (deliveredPart != null) {
            val delivered = readParts(updated.optJSONArray("deliveredParts"))
            delivered.add(deliveredPart)
            updated.put("deliveredParts", JSONArray(delivered.toList().sorted()))
        }
        updated.put("id", id)
        updated.put("status", status)
        updated.put("detail", detail)
        updated.put("whenMs", System.currentTimeMillis())
        check(prefs(context).edit().putString("$PREFIX$id", updated.toString()).commit()) {
            "Could not persist SMS status."
        }
    }

    private fun readParts(parts: JSONArray?): MutableSet<Int> {
        val out = mutableSetOf<Int>()
        if (parts != null) for (i in 0 until parts.length()) out.add(parts.optInt(i))
        return out
    }

    fun status(context: Context, id: String): String? {
        val raw = prefs(context).getString("$PREFIX$id", null) ?: return null
        return JSONObject(raw).optString("status")
    }

    fun schedule(context: Context, id: String) = update(context, id, "scheduled",
        "Scheduled on claim date; Android may delay background work")

    fun cancel(context: Context, id: String) = update(context, id, "cancelled", "Future reminder cancelled")

    fun queued(context: Context, id: String, parts: Int) {
        update(context, id, "queued", "Waiting for SMS modem result", totalParts = parts)
    }

    fun failed(context: Context, id: String, message: String) =
        update(context, id, "failed", message)

    @Synchronized
    fun sentPart(context: Context, id: String, part: Int, total: Int, code: Int) {
        if (code != android.app.Activity.RESULT_OK) {
            update(context, id, "failed",
                "Radio rejected segment ${part + 1}/$total (Android result $code). " +
                    "Some segments may already have been sent.")
            return
        }
        val old = JSONObject(prefs(context).getString("$PREFIX$id", "{}") ?: "{}")
        val current = readParts(old.optJSONArray("sentParts"))
        current.add(part)
        val allSent = current.size >= total
        val allDelivered = readParts(old.optJSONArray("deliveredParts")).size >= total
        update(context, id, when {
            allDelivered -> "delivered"
            allSent -> "sent"
            else -> "queued"
        }, when {
            allDelivered -> "All segments: carrier reported delivery"
            allSent -> "All segments accepted by mobile network; delivery not guaranteed"
            else -> "Sending segment ${current.size}/$total"
        }, sentPart = part, totalParts = total)
    }

    @Synchronized
    fun deliveredPart(context: Context, id: String, part: Int, total: Int, code: Int) {
        if (code != android.app.Activity.RESULT_OK) {
            // Failure to receive a delivery report does not reverse a network SENT success.
            val old = status(context, id)
            if (old != "failed" && old != "delivered") {
                update(context, id, old ?: "sent", "Delivery not confirmed by carrier (result $code)")
            }
            return
        }
        val previous = JSONObject(prefs(context).getString("$PREFIX$id", "{}") ?: "{}")
        val delivered = readParts(previous.optJSONArray("deliveredParts"))
        delivered.add(part)
        val all = delivered.size >= total
        update(context, id, if (all) "delivered" else (status(context, id) ?: "sent"),
            if (all) "Carrier reported delivery of all segments" else "Some segments delivered",
            deliveredPart = part, totalParts = total)
    }

    fun list(context: Context): List<Map<String, Any>> =
        prefs(context).all.entries
            .filter { it.key.startsWith(PREFIX) && it.value is String }
            .mapNotNull { entry ->
                try {
                    val item = JSONObject(entry.value as String)
                    mapOf(
                        "id" to item.optString("id"),
                        "status" to item.optString("status"),
                        "detail" to item.optString("detail"),
                        "whenMs" to item.optLong("whenMs", 0)
                    )
                } catch (_: Exception) { null }
            }
            .sortedBy { (it["whenMs"] as? Long) ?: 0L }
}
