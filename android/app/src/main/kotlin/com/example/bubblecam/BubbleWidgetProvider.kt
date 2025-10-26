package com.example.bubblecam

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class BubbleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Lấy data từ SharedPreferences (được set từ Flutter)
            val widgetData = HomeWidgetPlugin.getData(context)
            val imageUrl = widgetData.getString("widget_image_url", null)
            val userName = widgetData.getString("widget_user_name", "BubbleCam")

            // Tạo RemoteViews
            val views = RemoteViews(context.packageName, R.layout.bubble_widget_layout)
            
            // Set text
            views.setTextViewText(R.id.widget_title, userName)
            
            // Load image (nếu có URL)
            if (imageUrl != null) {
                // Sử dụng Glide hoặc load trực tiếp
                views.setTextViewText(R.id.widget_status, "New photo!")
            } else {
                views.setTextViewText(R.id.widget_status, "No photos yet")
            }

            // Update widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
