// No-op implementation used when compiling for web. Browser push
// notifications are handled by the service worker FlutterFire set up
// automatically — there's nothing for flutter_local_notifications to do
// here, and its mobile-specific API doesn't compile for web anyway.

Future<void> initNotifications() async {}

void showLocalNotification({required int id, String? title, String? body}) {}