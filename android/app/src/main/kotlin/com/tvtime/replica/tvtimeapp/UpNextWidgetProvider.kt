package com.tvtime.replica.tvtimeapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.io.File
import java.net.URL
import java.util.concurrent.Executors

class UpNextWidgetProvider : HomeWidgetProvider() {
    private val executor = Executors.newSingleThreadExecutor()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val jsonString = widgetData.getString("up_next_items", "[]") ?: "[]"
            var showId: Int? = null
            var showName: String? = null
            var header: String? = null
            var episodeTitle: String? = null
            var episodeDetails: String? = null
            var posterPath: String? = null
            var episodeKey: String? = null

            try {
                val jsonArray = JSONArray(jsonString)
                if (jsonArray.length() > 0) {
                    val firstItem = jsonArray.getJSONObject(0)
                    showId = firstItem.optInt("showId")
                    showName = firstItem.optString("showName")
                    header = firstItem.optString("header")
                    episodeTitle = firstItem.optString("episodeTitle")
                    episodeDetails = firstItem.optString("episodeDetails")
                    posterPath = firstItem.optString("localPosterPath")
                    if (posterPath.isNullOrEmpty()) {
                        posterPath = firstItem.optString("posterPath")
                    }
                    episodeKey = firstItem.optString("episodeKey")
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // Legacy fallback if jsonArray was empty
            if (showName == null) {
                showName = widgetData.getString("up_next_show_name", "No shows to watch")
                episodeTitle = widgetData.getString("up_next_episode", "Check the app for updates")
                posterPath = widgetData.getString("up_next_poster_path", null)
            }

            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                setTextViewText(R.id.widget_header, header ?: "WATCH NEXT")
                setTextViewText(R.id.widget_show_name, showName ?: "No shows to watch")
                setTextViewText(R.id.widget_episode, episodeTitle ?: "Check the app for updates")
                setTextViewText(R.id.widget_details, episodeDetails ?: "")

                // Mark as Watched button setup
                if (showId != null && !episodeKey.isNullOrEmpty()) {
                    setViewVisibility(R.id.widget_mark_watched, View.VISIBLE)
                    val markUri = Uri.parse("tvtimeapp://mark_watched?showId=$showId&episodeKey=$episodeKey")
                    val markPendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        markUri
                    )
                    setOnClickPendingIntent(R.id.widget_mark_watched, markPendingIntent)
                } else {
                    setViewVisibility(R.id.widget_mark_watched, View.GONE)
                }

                // Root click intent to open app/show details
                val rootUri = if (showId != null) {
                    Uri.parse("tvtimeapp://show/$showId")
                } else {
                    Uri.parse("tvtimeapp://")
                }
                val launchPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    rootUri
                )
                setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Async Poster Loading
            if (!posterPath.isNullOrEmpty()) {
                val currentPosterPath = posterPath
                executor.execute {
                    val bitmap = loadBitmap(context, currentPosterPath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_poster, bitmap)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                }
            } else {
                views.setImageViewResource(R.id.widget_poster, android.R.color.transparent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }

    private fun loadBitmap(context: Context, path: String): Bitmap? {
        return try {
            if (path.startsWith("http://") || path.startsWith("https://")) {
                val connection = URL(path).openConnection()
                connection.connectTimeout = 4000
                connection.readTimeout = 4000
                val input = connection.getInputStream()
                BitmapFactory.decodeStream(input)
            } else {
                val file = File(path)
                if (file.exists()) {
                    BitmapFactory.decodeFile(file.absolutePath)
                } else null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
