import 'dart:io';

import 'ios_environment_bindings.g.dart';

/// Whether this iOS build is running on a Mac ("Designed for iPad").
///
/// Calls Foundation directly (FFIgen bindings), so it is synchronous and
/// needs no platform channel. Always false off iOS.
bool readIsIOSAppOnMac() {
  if (!Platform.isIOS) return false;
  return NSProcessInfo.getProcessInfo().isiOSAppOnMac;
}

/// The UIKit interface idiom (`mac`, `pad`, `phone`, `unspecified`), or null
/// off iOS.
///
/// UIDevice is main-thread only: call this from the root isolate, which runs
/// on the platform thread.
String? readIOSUserInterfaceIdiom() {
  if (!Platform.isIOS) return null;
  return switch (UIDevice.getCurrentDevice().userInterfaceIdiom) {
    .UIUserInterfaceIdiomMac => 'mac',
    .UIUserInterfaceIdiomPad => 'pad',
    .UIUserInterfaceIdiomPhone => 'phone',
    _ => 'unspecified',
  };
}
