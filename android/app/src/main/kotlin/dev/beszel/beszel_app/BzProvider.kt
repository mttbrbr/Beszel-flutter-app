package dev.beszel.beszel_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/** Shared plumbing: every widget re-renders from the data saved by the Flutter app. */
abstract class BzProvider : AppWidgetProvider() {
    abstract fun render(ctx: Context, manager: AppWidgetManager, widgetId: Int)

    override fun onUpdate(ctx: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(ctx, manager, id)
    }

    // Resizing can switch between compact and roomy layouts.
    override fun onAppWidgetOptionsChanged(ctx: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle?) {
        render(ctx, manager, id)
    }

    override fun onDeleted(ctx: Context, ids: IntArray) {
        val e = WidgetData.prefs(ctx).edit()
        for (id in ids) {
            e.remove("machine_$id")
            e.remove("metric_$id")
        }
        e.apply()
    }
}
