package dev.beszel.beszel_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/** Status dots for several machines (two columns, up to 8), problems first. */
class FleetStatusWidgetProvider : BzProvider() {
    override fun render(ctx: Context, manager: AppWidgetManager, widgetId: Int) {
        val v = RemoteViews(ctx.packageName, R.layout.widget_fleet_status)
        val all = WidgetData.machines(ctx)
        val sorted = all.sortedWith(compareBy({ it.status == "up" }, { it.name.lowercase() }))
        val up = all.count { it.isUp }
        v.setTextViewText(R.id.summary, if (all.isEmpty()) "Apri l'app" else "$up/${all.size} online")
        v.setTextColor(R.id.summary, if (all.isNotEmpty() && up < all.size) WidgetData.RED else WidgetData.MUTED)

        val cells = intArrayOf(R.id.cell0, R.id.cell1, R.id.cell2, R.id.cell3, R.id.cell4, R.id.cell5, R.id.cell6, R.id.cell7)
        val dots = intArrayOf(R.id.dot0, R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6, R.id.dot7)
        val names = intArrayOf(R.id.name0, R.id.name1, R.id.name2, R.id.name3, R.id.name4, R.id.name5, R.id.name6, R.id.name7)
        for (i in cells.indices) {
            val m = sorted.getOrNull(i)
            if (m == null) {
                v.setViewVisibility(cells[i], View.INVISIBLE)
                continue
            }
            v.setViewVisibility(cells[i], View.VISIBLE)
            v.setTextColor(dots[i], WidgetData.statusColor(m))
            v.setTextViewText(names[i], m.name)
        }
        v.setOnClickPendingIntent(R.id.root, WidgetData.launchApp(ctx))
        manager.updateAppWidget(widgetId, v)
    }
}
