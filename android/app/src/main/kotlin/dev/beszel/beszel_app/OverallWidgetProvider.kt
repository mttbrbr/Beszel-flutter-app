package dev.beszel.beszel_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews

/** One-glance "is everything fine?" tile. */
class OverallWidgetProvider : BzProvider() {
    override fun render(ctx: Context, manager: AppWidgetManager, widgetId: Int) {
        val all = WidgetData.machines(ctx)
        val alerts = WidgetData.alerts(ctx)
        val v = RemoteViews(ctx.packageName, R.layout.widget_canvas)
        v.setImageViewBitmap(R.id.root, WidgetCanvas.render(ctx, manager, widgetId) { WidgetCanvas.overallWidget(it, all, alerts) })
        v.setOnClickPendingIntent(R.id.root, WidgetData.launchApp(ctx))
        manager.updateAppWidget(widgetId, v)
    }
}
