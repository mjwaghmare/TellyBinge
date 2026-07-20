package com.tvtime.replica.tvtimeapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class UpNextWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val showName = widgetData.getString("up_next_show_name", "No shows to watch")
                val episode = widgetData.getString("up_next_episode", "Check the app for updates")
                val posterPath = widgetData.getString("up_next_poster_path", null)
                val uriStr = widgetData.getString("up_next_uri", null)
                
                setTextViewText(R.id.widget_show_name, showName)
                setTextViewText(R.id.widget_episode, episode)

                // Load Poster Image
                if (posterPath != null) {
                    val file = File(posterPath)
                    if (file.exists()) {
                        val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                        setImageViewBitmap(R.id.widget_poster, bitmap)
                    } else {
                        setImageViewResource(R.id.widget_poster, android.R.color.transparent)
                    }
                }

                // Setup Deep Link Click Intent
                if (uriStr != null) {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                        setPackage(context.packageName)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        appWidgetId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

