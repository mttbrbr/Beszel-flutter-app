package dev.beszel.beszel_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews

/** All machines, each as name + three stacked bars. */
class FleetWidgetProvider : BzProvider() {
    override fun render(ctx: Context, manager: AppWidgetManager, widgetId: Int) {
        val all = WidgetData.machines(ctx)
        val v = RemoteViews(ctx.packageName, R.layout.widget_canvas)
        v.setImageViewBitmap(R.id.root, WidgetCanvas.render(ctx, manager, widgetId) { WidgetCanvas.fleetBarsWidget(it, all) })
        v.setOnClickPendingIntent(R.id.root, WidgetData.launchApp(ctx))
        manager.updateAppWidget(widgetId, v)
    }
}
