import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Enables/disables the wakelock, swallowing platform errors (e.g. Linux
/// desktops without a D-Bus portal session).
Future<void> setWakelock(bool enabled) async {
  try {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  } catch (e) {
    debugPrint('Wakelock unavailable: $e');
  }
}
