import 'package:android_intent_plus/android_intent.dart';

Future<void> openSystemGallery() async {
  // 1) Try default gallery picker (works across OEMs)
  try {
    final pickIntent = AndroidIntent(
      action: 'android.intent.action.PICK',
      type: 'image/*',
    );
    await pickIntent.launch();
    return;
  } catch (_) {
    // fall through
  }

  // 2) Fallback: try Google Photos if present
  try {
    final photosIntent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.google.android.apps.photos',
      componentName: 'com.google.android.apps.photos.home.HomeActivity',
    );
    await photosIntent.launch();
    return;
  } catch (_) {
    // fall through
  }

  // 3) Last resort: open any image viewer (may show "no app" if none installed)
  final viewIntent = AndroidIntent(
    action: 'android.intent.action.VIEW',
    type: 'image/*',
  );
  await viewIntent.launch();
}
