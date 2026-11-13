// Runs ccpocket on several devices side by side in one macOS window:
//
//   cd apps/mobile_preview && flutter run -d macos
//
// The services of apps/mobile are created once and shared by every device
// (see bootstrapCcpocket); each device runs its own CcpocketApp.
import 'dart:async';

import 'package:ccpocket/main.dart';
import 'package:flutter/widgets.dart' show Orientation;
import 'package:flutter/services.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_marionette/multi_device_preview_marionette.dart';

/// Devices of the store screenshots.
const storeDevices = [
  PreviewDevice(preset: DevicePresets.iPhone17Pro),
  PreviewDevice(preset: MultiDevicePresets.iPhoneDuo),
  PreviewDevice(
    preset: DevicePresets.iPadPro13M5,
    orientation: Orientation.landscape,
  ),
];

void main() {
  runZonedGuarded(
    () async {
      // The devices go to the controller: runMultiDevicePreview ignores its
      // devices argument when a controller is given.
      final controller = MultiDevicePreviewController(devices: storeDevices);
      MarionetteBinding.ensureInitialized(
        multiDevicePreviewMarionetteConfiguration,
      );
      registerMultiDevicePreviewMarionetteExtensions(controller);
      registerCcpocketDebugExtensions();
      final bootstrap = await bootstrapCcpocket();
      runMultiDevicePreview(
        controller: controller,
        wrapper: bootstrap.wrap,
        appBuilder: (context, slot) =>
            CcpocketApp(fcmService: bootstrap.fcmService),
      );
    },
    (error, stack) {
      // Plugins without a macOS implementation (or not configured for the
      // preview bundle) fail in the background; the layout does not need them.
      if (error is MissingPluginException) return;
      Zone.current.parent!.handleUncaughtError(error, stack);
    },
  );
}
