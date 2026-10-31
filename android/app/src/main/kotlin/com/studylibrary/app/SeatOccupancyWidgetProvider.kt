package com.studylibrary.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class SeatOccupancyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val occupied = prefs.getLong("flutter.widget_occupied_seats", -1L)
        val total = prefs.getLong("flutter.widget_total_seats", -1L)
        val libraryName = prefs.getString("flutter.widget_library_name", "Cozy Corner Library") ?: "Cozy Corner Library"

        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId, libraryName, occupied, total)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            libraryName: String,
            occupied: Long,
            total: Long
        ) {
            val views = RemoteViews(context.packageName, R.layout.seat_widget_layout)

            views.setTextViewText(R.id.widget_title, libraryName)

            if (occupied >= 0 && total >= 0) {
                views.setTextViewText(R.id.widget_occupancy_number, "$occupied / $total")
                val vacant = (total - occupied).coerceAtLeast(0)
                views.setTextViewText(R.id.widget_vacant_number, "$vacant")
            } else {
                views.setTextViewText(R.id.widget_occupancy_number, "-- / --")
                views.setTextViewText(R.id.widget_vacant_number, "--")
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context, libraryName: String, occupied: Long, total: Long) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SeatOccupancyWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (widgetId in allWidgetIds) {
                updateWidget(context, appWidgetManager, widgetId, libraryName, occupied, total)
            }
        }
    }
}
