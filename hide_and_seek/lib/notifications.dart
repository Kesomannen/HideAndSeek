import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifications {
  static bool _initialized = false;
  static FlutterLocalNotificationsPlugin? _plugin;
  
  static _initialize() {
    if (_initialized) {
      return;
    }
    
    _initialized = true;
    
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _plugin = flutterLocalNotificationsPlugin;
  }

  static show(String title, String body, {Importance importance = Importance.high}) async {
    _initialize();

    NotificationDetails notification = NotificationDetails(android: AndroidNotificationDetails(
      'hide_and_seek', 
      'Hide and Seek',
      importance: importance,
    ));

    await _plugin!.show(0, title, body, notification);
  }
}