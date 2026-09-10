// Picks the correct implementation for the compile target:
// - Any platform with dart:io (Android, iOS, desktop) gets the real
//   flutter_local_notifications-backed version.
// - Web (which has no dart:io) falls back to the no-op stub, since its
//   local-notification API is fundamentally different and unnecessary here.
export 'notification_helper_stub.dart' if (dart.library.io) 'notification_helper_io.dart';