package dev.beszel.beszel_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import org.json.JSONArray

/** One device as saved by the Flutter side (see lib/widget_sync.dart). */
data class Machine(
    val id: String,
    val name: String,
    val status: String,
    val cpu: Double?,
    val mem: Double?,
    val disk: Double?,
    val temp: Double?,
) {
    val isUp get() = status == "up"
}

object WidgetData {
    // home_widget stores everything in this preferences file.
    const val PREFS = "HomeWidgetPreferences"

    const val GREEN = 0xFF34D399.toInt()
    const val RED = 0xFFF87171.toInt()
    const val MUTED = 0xFF8B909A.toInt()
    const val BLUE = 0xFF60A5FA.toInt()
    const val ORANGE = 0xFFFB923C.toInt()
    const val TRACK = 0xFF272A2F.toInt()

    fun prefs(ctx: Context): SharedPreferences = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun machines(ctx: Context): List<Machine> {
        val raw = prefs(ctx).getString("systems_json", null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                fun num(k: String) = if (o.isNull(k)) null else o.optDouble(k)
                Machine(o.getString("id"), o.optString("name"), o.optString("status"), num("cpu"), num("mem"), num("disk"), num("temp"))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun statusColor(m: Machine) = when (m.status) {
        "up" -> GREEN
        "down" -> RED
        else -> MUTED
    }

    fun launchApp(ctx: Context): PendingIntent {
        val intent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        return PendingIntent.getActivity(ctx, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun pct(v: Double?) = if (v == null) "–" else "${v.toInt()}%"

    /** Three concentric rings: outer = CPU, middle = RAM, inner = disk. */
    fun rings(values: List<Double?>, colors: List<Int>): Bitmap {
        val size = 300
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val stroke = 24f
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; color = TRACK }
        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND }
        values.forEachIndexed { i, v ->
            val inset = stroke / 2 + i * (stroke + 12)
            val rect = RectF(inset, inset, size - inset, size - inset)
            c.drawArc(rect, 0f, 360f, false, track)
            if (v != null && v > 0) {
                arc.color = colors[i]
                c.drawArc(rect, -90f, (v.coerceIn(0.0, 100.0) * 3.6).toFloat(), false, arc)
            }
        }
        return bmp
    }

    fun selected(ctx: Context, widgetId: Int): Machine? {
        val id = prefs(ctx).getString("machine_$widgetId", null) ?: return null
        return machines(ctx).firstOrNull { it.id == id }
    }

    fun alerts(ctx: Context): Int = (prefs(ctx).all["alerts"] as? Number)?.toInt() ?: 0

    fun stateLabel(m: Machine) = when (m.status) {
        "up" -> "Online"
        "down" -> "Offline"
        "paused" -> "In pausa"
        else -> "In attesa"
    }

    /** Opens the picker so the user can (re)choose machine/metric for this widget. */
    fun configIntent(ctx: Context, widgetId: Int): PendingIntent {
        val i = Intent(ctx, WidgetConfigActivity::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .setData(android.net.Uri.parse("beszel://widget/$widgetId"))
        return PendingIntent.getActivity(ctx, widgetId, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}
