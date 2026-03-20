package com.aurorasoftware.music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class AuroraMusicWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.aurorasoftware.music.WIDGET_PLAY_PAUSE"
        const val ACTION_NEXT = "com.aurorasoftware.music.WIDGET_NEXT"
        const val ACTION_PREVIOUS = "com.aurorasoftware.music.WIDGET_PREVIOUS"
        const val ACTION_OPEN_APP = "com.aurorasoftware.music.WIDGET_OPEN"
        const val ACTION_UPDATE = "com.aurorasoftware.music.WIDGET_UPDATE"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PLAY_PAUSE -> openApp(context)
            ACTION_NEXT -> openApp(context)
            ACTION_PREVIOUS -> openApp(context)
            ACTION_OPEN_APP -> openApp(context)
            ACTION_UPDATE -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val widgetComponent = ComponentName(context, AuroraMusicWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
                for (appWidgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.aurora_music_widget)

        // Get data from SharedPreferences
        val songTitle = widgetData.getString("widget_song_title", null) ?: "Not Playing"
        val artistName = widgetData.getString("widget_artist_name", null) ?: "Tap to open Aurora Music"
        val isPlaying = widgetData.getBoolean("widget_is_playing", false)

        // Set text content
        views.setTextViewText(R.id.widget_song_title, songTitle)
        views.setTextViewText(R.id.widget_artist_name, artistName)

        // Set play/pause icon
        views.setImageViewResource(
            R.id.widget_btn_play_pause,
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )

        // Click handlers
        val openIntent = createPendingIntent(context, ACTION_OPEN_APP, 0)
        views.setOnClickPendingIntent(R.id.widget_root, openIntent)

        views.setOnClickPendingIntent(R.id.widget_btn_prev, createPendingIntent(context, ACTION_PREVIOUS, 1))
        views.setOnClickPendingIntent(R.id.widget_btn_play_pause, createPendingIntent(context, ACTION_PLAY_PAUSE, 2))
        views.setOnClickPendingIntent(R.id.widget_btn_next, createPendingIntent(context, ACTION_NEXT, 3))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun createPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, AuroraMusicWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun openApp(context: Context) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
        }
    }
}
