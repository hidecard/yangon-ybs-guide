package net.arkaryan.ybs_guide

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.istornz.live_activities.LiveActivityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

class CustomLiveActivityManager(context: Context) : LiveActivityManager(context) {
    private val context: Context = context.applicationContext

    private val pendingIntent = PendingIntent.getActivity(
        context, 200, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private val remoteViews = RemoteViews(
        context.packageName, R.layout.live_activity
    )

    override suspend fun buildNotification(
        notification: android.app.Notification.Builder,
        event: String,
        data: Map<String, Any>
    ): android.app.Notification {
        val routeName = (data["routeName"] as? String) ?: (data["name"] as? String) ?: "YBS"
        val stopName = data["stopName"] as? String ?: ""
        val distanceKm = (data["distanceKm"] as? Double) ?: 0.0
        val etaMinutes = (data["etaMinutes"] as? Int) ?: 0

        remoteViews.setTextViewText(R.id.route_name, routeName)
        remoteViews.setTextViewText(R.id.stop_name, stopName)
        remoteViews.setTextViewText(R.id.distance, "%.1f km".format(distanceKm))
        if (etaMinutes > 0) {
            remoteViews.setTextViewText(R.id.eta, "~$etaMinutes min")
            remoteViews.setViewVisibility(R.id.eta, android.view.View.VISIBLE)
        } else {
            remoteViews.setViewVisibility(R.id.eta, android.view.View.GONE)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ybs_live_activity",
                "Live Tracking",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        return notification
            .setSmallIcon(android.R.mipmap.sym_def_app_icon)
            .setOngoing(true)
            .setContentTitle(routeName)
            .setContentIntent(pendingIntent)
            .setStyle(android.app.Notification.DecoratedCustomViewStyle())
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setPriority(android.app.Notification.PRIORITY_HIGH)
            .setCategory(android.app.Notification.CATEGORY_TRANSPORT)
            .setVisibility(android.app.Notification.VISIBILITY_PUBLIC)
            .build()
    }
}
