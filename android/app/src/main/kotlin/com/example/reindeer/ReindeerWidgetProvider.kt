package com.example.reindeer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

// Home-screen widget showing the next doses. The app writes the text (see
// WidgetSync in Dart); this class draws it. "Taken" taps are stored and applied
// by the app the next time it opens.
class ReindeerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TAKE) {
            val key = intent.getStringExtra(EXTRA_KEY)
            if (!key.isNullOrEmpty()) {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val pending = prefs.getString(PENDING, "") ?: ""
                val text = prefs.getString(KEY, "") ?: ""
                // Drop the ticked row so the widget answers straight away.
                val kept = text.split("\n").filter { line ->
                    val parts = line.split("\t")
                    !(parts.size >= 3 && parts[1] == key)
                }
                prefs.edit()
                    .putString(PENDING, if (pending.isEmpty()) key else "$pending\n$key")
                    .putString(KEY, kept.joinToString("\n"))
                    .apply()
                refresh(context)
            }
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        private const val PREFS = "reindeer_widget"
        private const val KEY = "text"
        private const val PENDING = "pending"
        private const val ACTION_TAKE = "com.example.reindeer.WIDGET_TAKE"
        private const val EXTRA_KEY = "doseKey"

        fun save(context: Context, text: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, text).apply()
            refresh(context)
        }

        // Returns the dose keys ticked on the widget and clears them.
        fun takePending(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val pending = prefs.getString(PENDING, "") ?: ""
            if (pending.isNotEmpty()) prefs.edit().remove(PENDING).apply()
            return pending
        }

        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ReindeerWidgetProvider::class.java))
            for (id in ids) manager.updateAppWidget(id, build(context))
        }

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.reindeer_widget)
            val text = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null)
            val lines = (text ?: "").split("\n").filter { it.isNotEmpty() }
            views.setTextViewText(
                R.id.widget_header,
                if (lines.isEmpty()) "Reindeer: open the app" else lines[0]
            )
            val doseLines = lines.drop(1).filter { !it.startsWith("F\t") }
            val footer = lines.firstOrNull { it.startsWith("F\t") }?.substring(2) ?: ""

            val lineIds = intArrayOf(R.id.widget_line1, R.id.widget_line2, R.id.widget_line3, R.id.widget_line4)
            val rowIds = intArrayOf(R.id.widget_row1, R.id.widget_row2, R.id.widget_row3, R.id.widget_row4)
            val tickIds = intArrayOf(R.id.widget_tick1, R.id.widget_tick2, R.id.widget_tick3, R.id.widget_tick4)
            for (i in rowIds.indices) {
                val parts = doseLines.getOrNull(i)?.split("\t", limit = 3)
                if (parts == null || parts.size < 3) {
                    views.setViewVisibility(lineIds[i], View.GONE)
                    continue
                }
                views.setViewVisibility(lineIds[i], View.VISIBLE)
                views.setTextViewText(rowIds[i], parts[2])
                views.setTextColor(
                    rowIds[i],
                    if (parts[0] == "L") Color.parseColor("#FFB3261E") else Color.parseColor("#FF222222")
                )
                val take = Intent(context, ReindeerWidgetProvider::class.java).apply {
                    action = ACTION_TAKE
                    data = Uri.parse("reindeer://widget/take/$i")
                    putExtra(EXTRA_KEY, parts[1])
                }
                views.setOnClickPendingIntent(
                    tickIds[i],
                    PendingIntent.getBroadcast(
                        context, i, take,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )
            }
            views.setTextViewText(R.id.widget_footer, footer)
            views.setViewVisibility(R.id.widget_footer, if (footer.isEmpty()) View.GONE else View.VISIBLE)

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent()
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context, 100, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            return views
        }
    }
}
