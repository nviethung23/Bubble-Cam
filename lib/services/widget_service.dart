import 'package:home_widget/home_widget.dart';

class WidgetService {
  static Future<void> updateWidget({
    required String imageUrl,
    required String userName,
  }) async {
    try {
      // Save data to SharedPreferences (accessible from native code)
      await HomeWidget.saveWidgetData<String>('widget_image_url', imageUrl);
      await HomeWidget.saveWidgetData<String>('widget_user_name', userName);
      
      // Update widget
      await HomeWidget.updateWidget(
        name: 'BubbleWidgetProvider',
        androidName: 'BubbleWidgetProvider',
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_image_url', '');
      await HomeWidget.saveWidgetData<String>('widget_user_name', 'BubbleCam');
      await HomeWidget.updateWidget(
        name: 'BubbleWidgetProvider',
        androidName: 'BubbleWidgetProvider',
      );
    } catch (e) {
      print('Error clearing widget: $e');
    }
  }
}
