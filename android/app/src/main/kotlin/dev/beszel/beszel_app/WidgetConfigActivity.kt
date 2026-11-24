package dev.beszel.beszel_app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView

/**
 * Configuration screen of the per-machine widgets: picks which machine to show.
 */
class WidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider?.className
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID || provider == null) {
            finish()
            return
        }

        title = "Scegli la macchina"
        val machines = WidgetData.machines(this).sortedBy { it.name.lowercase() }
        if (machines.isEmpty()) {
            setContentView(TextView(this).apply {
                text = "Nessuna macchina disponibile.\nApri l'app Beszel, accedi e riprova."
                setPadding(48, 48, 48, 48)
            })
            return
        }
        val labels = machines.map { it.name }
        val values = machines.map { it.id }
        val prefKey = "machine_$widgetId"

        val list = ListView(this)
        list.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, labels)
        list.setOnItemClickListener { _, _, pos, _ ->
            WidgetData.prefs(this).edit().putString(prefKey, values[pos]).apply()
            // Re-render this widget through its own provider.
            sendBroadcast(
                Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .setClassName(packageName, provider)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId)),
            )
            setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
            finish()
        }
        setContentView(list)
    }
}
