package com.mwstudio.popverse

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONArray
import java.io.File
import java.net.URL

class UpNextWidgetProvider : HomeWidgetProvider() {
    // Use a stable coroutine scope tied to Dispatchers.IO for poster loading.
    // Unlike a bare Executor, a coroutine job can be cancelled and is not
    // vulnerable to GC if the process is recycled between widget updates.
    private val scope = CoroutineScope(Dispatchers.IO + Job())

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val pendingResult = goAsync()
        scope.launch {
            try {
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
                            showId = firstItem.optInt("showId", 0)
                            showName = firstItem.optString("showName", null)
                            header = firstItem.optString("header", null)
                            episodeTitle = firstItem.optString("episodeTitle", null)
                            episodeDetails = firstItem.optString("episodeDetails", null)
                            posterPath = firstItem.optString("localPosterPath", null)
                            if (posterPath.isNullOrEmpty()) {
                                posterPath = firstItem.optString("posterPath", null)
                            }
                            episodeKey = firstItem.optString("episodeKey", null)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    // Fallback to legacy preferences if showName is blank/missing or showId is missing/zero
                    if (showName.isNullOrBlank() || showName == "null" || showId == null || showId <= 0) {
                        showName = widgetData.getString("up_next_show_name", "No shows to watch")
                        episodeTitle = widgetData.getString("up_next_episode", "Check the app for updates")
                        posterPath = widgetData.getString("up_next_poster_path", null)
                        showId = null
                    }

                    val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                        setTextViewText(R.id.widget_header, header ?: "WATCH NEXT")
                        setTextViewText(R.id.widget_show_name, showName ?: "No shows to watch")
                        setTextViewText(R.id.widget_episode, episodeTitle ?: "Check the app for updates")
                        setTextViewText(R.id.widget_details, episodeDetails ?: "")

                        // Mark as Watched button setup
                        if (showId != null && showId > 0 && !episodeKey.isNullOrEmpty()) {
                            setViewVisibility(R.id.widget_mark_watched, View.VISIBLE)
                            val markUri = Uri.Builder()
                                .scheme("tvtimeapp")
                                .authority("mark_watched")
                                .appendQueryParameter("showId", showId.toString())
                                .appendQueryParameter("episodeKey", episodeKey)
                                .build()
                            val markPendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                markUri
                            )
                            setOnClickPendingIntent(R.id.widget_mark_watched, markPendingIntent)
                        } else {
                            setViewVisibility(R.id.widget_mark_watched, View.GONE)
                        }

                        // Root click intent to open app/show details
                        val rootUri = if (showId != null && showId > 0) {
                            Uri.parse("tvtimeapp://show/$showId")
                        } else {
                            Uri.parse("tvtimeapp://")
                        }
                        val launchPendingIntent = launchPendingIntent(context, rootUri)
                        setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)
                    }

                    appWidgetManager.updateAppWidget(appWidgetId, views)

                    // Async poster loading via coroutine
                    if (!posterPath.isNullOrEmpty()) {
                        val bitmap = loadBitmap(context, posterPath)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_poster, bitmap)
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                        }
                    } else {
                        views.setImageViewResource(R.id.widget_poster, android.R.color.transparent)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                }
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun loadBitmap(context: Context, path: String): Bitmap? {
        return try {
            if (path.startsWith("http://") || path.startsWith("https://")) {
                val connection = URL(path).openConnection()
                connection.connectTimeout = 4000
                connection.readTimeout = 4000
                connection.getInputStream().use { input ->
                    BitmapFactory.decodeStream(input)
                }
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

    /**
     * Same intent as HomeWidgetLaunchIntent.getActivity, but aimed at the
     * enabled launcher entry: MainActivity is disabled while an alternate
     * app icon is chosen, so it can't be started by class name.
     */
    private fun launchPendingIntent(context: Context, uri: Uri): PendingIntent {
        val intent = Intent(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION, uri)
            .setComponent(AppIconSwitcher.launchComponent(context))
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        if (Build.VERSION.SDK_INT < 34) {
            return PendingIntent.getActivity(context, 0, intent, flags)
        }
        // Creator-side opt-in (API 34+): we create this PendingIntent and the
        // launcher sends it, so the sender-side setting would not apply.
        val options = ActivityOptions.makeBasic()
            .setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            )
        return PendingIntent.getActivity(context, 0, intent, flags, options.toBundle())
    }
}
