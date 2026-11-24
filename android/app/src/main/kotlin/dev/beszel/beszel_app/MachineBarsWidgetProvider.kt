package dev.beszel.beszel_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews

/** One machine: name with status dot and CPU / RAM / disk as stacked bars. */
class MachineBarsWidgetProvider : BzProvider() {
    override fun render(ctx: Context, manager: AppWidgetManager, widgetId: Int) {
        val m = WidgetData.selected(ctx, widgetId)
        val v = RemoteViews(ctx.packageName, R.layout.widget_canvas)
        v.setImageViewBitmap(R.id.root, WidgetCanvas.render(ctx, manager, widgetId) { WidgetCanvas.barsWidget(it, m) })
        v.setOnClickPendingIntent(R.id.root, if (m == null) WidgetData.configIntent(ctx, widgetId) else WidgetData.launchApp(ctx))
        manager.updateAppWidget(widgetId, v)
    }
}
